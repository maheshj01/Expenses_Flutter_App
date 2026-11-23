import 'dart:async';

import '../../core/clock.dart';
import 'connectivity_monitor.dart';
import 'local_sync_source.dart';
import 'remote_store.dart';
import 'sync_status.dart';

/// Moves changes between the local database and a [RemoteStore].
///
/// - Each run pulls remote changes, then pushes local ones.
/// - Runs on start, shortly after local edits (debounced) and when the
///   network returns.
/// - Conflicts are resolved per record: the most recent edit wins.
/// - Without a network, changes stay queued in the local database.
class SyncEngine {
  SyncEngine({
    required this._remote,
    required this._sources,
    required this._cursors,
    required this._connectivity,
    this._changes,
    this._debounce = const Duration(seconds: 2),
    this._retryAfter = const Duration(seconds: 30),
    this._pushBatchSize = 400,
    this._clock = systemClock,
  });

  final RemoteStore? _remote;
  final List<LocalSyncSource> _sources;
  final SyncCursorStore _cursors;
  final ConnectivityMonitor _connectivity;
  final LocalChanges? _changes;
  final Duration _debounce;
  final Duration _retryAfter;
  final int _pushBatchSize;
  final Clock _clock;

  final _statusController = StreamController<SyncStatus>.broadcast();
  final _subscriptions = <StreamSubscription<Object?>>[];
  late SyncStatus _status = SyncStatus(
    phase: _remote == null ? SyncPhase.localOnly : SyncPhase.idle,
    backendName: _remote?.displayName,
  );
  Timer? _debounceTimer;
  Timer? _retryTimer;
  Future<void>? _running;
  bool _runAgain = false;
  bool _disposed = false;

  /// Set while the account's backup is being erased, so nothing is pushed
  /// back to it.
  bool _paused = false;

  bool get isEnabled => _remote != null;

  SyncStatus get status => _status;

  Stream<SyncStatus> get statusChanges => _statusController.stream;

  /// Starts listening for local changes and network changes, then syncs.
  void start() {
    final changes = _changes;
    if (changes != null) {
      _subscriptions.add(changes.stream.listen((_) => schedule()));
    }
    if (!isEnabled) {
      unawaited(_refreshPending());
      return;
    }
    _subscriptions.add(
      _connectivity.onlineChanges.listen((online) {
        if (online) unawaited(syncNow());
      }),
    );
    unawaited(syncNow());
  }

  /// Syncs soon, coalescing bursts of edits into one round trip.
  void schedule() {
    if (_disposed) return;
    if (!isEnabled || _paused) {
      unawaited(_refreshPending());
      return;
    }
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, () => unawaited(syncNow()));
  }

  /// Runs a full push + pull. Concurrent calls share one run, and a call
  /// made during a run triggers one more run afterwards.
  Future<void> syncNow() {
    if (!isEnabled || _disposed || _paused) return Future.value();
    if (_running != null) {
      _runAgain = true;
      return _running!;
    }
    final run = _runLoop();
    _running = run;
    return run.whenComplete(() => _running = null);
  }

  Future<void> _runLoop() async {
    do {
      _runAgain = false;
      await _syncOnce();
    } while (_runAgain && !_disposed);
  }

  Future<void> _syncOnce() async {
    final remote = _remote!;
    _retryTimer?.cancel();

    if (!await _connectivity.isOnline()) {
      _emit(_status.copyWith(phase: SyncPhase.offline, pendingCount: await _pendingCount()));
      return;
    }

    _emit(_status.copyWith(phase: SyncPhase.syncing));
    try {
      await remote.connect();
      await _handleAccountSwitch(remote);
      // Pull first: a stale local edit made offline is then overwritten by a
      // newer remote edit before it gets the chance to be pushed.
      for (final source in _sources) {
        await _pull(remote, source);
      }
      for (final source in _sources) {
        await _push(remote, source);
      }
      _emit(
        _status.copyWith(
          phase: SyncPhase.idle,
          lastSyncedAt: _clock(),
          pendingCount: await _pendingCount(),
        ),
      );
    } catch (e) {
      _emit(
        _status.copyWith(
          phase: SyncPhase.error,
          message: e.toString(),
          pendingCount: await _pendingCount(),
        ),
      );
      _retryTimer = Timer(_retryAfter, () => unawaited(syncNow()));
    }
  }

  /// Erases this account's backed-up data, before deleting the account.
  ///
  /// Waits for a sync in progress, then pauses syncing until
  /// [resumeAfterErase] so nothing is pushed back meanwhile. Local data is
  /// left alone. Throws [EraseFailed] when offline or when the backend
  /// refuses; call [resumeAfterErase] with `restore: true` then.
  Future<void> eraseRemote() async {
    final remote = _remote;
    if (remote == null) return;
    _paused = true;
    _debounceTimer?.cancel();
    _retryTimer?.cancel();
    await _running;
    if (!await _connectivity.isOnline()) {
      throw const EraseFailed('You’re offline. Connect to the internet to delete your account.');
    }
    try {
      await remote.connect();
      for (final source in _sources) {
        await remote.erase(source.collection);
      }
    } catch (e) {
      throw EraseFailed('Couldn’t delete your backup: $e');
    }
  }

  /// Starts syncing again after [eraseRemote]. With [restore] (the account
  /// wasn't deleted after all), pushes everything on this device back so
  /// its backup is whole again.
  Future<void> resumeAfterErase({required bool restore}) async {
    if (restore) {
      for (final source in _sources) {
        await _cursors.writeCursor(source.collection, null);
        await source.markAllDirty();
      }
    }
    _paused = false;
    unawaited(syncNow());
  }

  /// Key under which the account last synced with is kept.
  static const accountKey = '__account__';

  /// After switching accounts, pulls everything from the new account and
  /// pushes everything on this device to it.
  Future<void> _handleAccountSwitch(RemoteStore remote) async {
    final account = remote.accountId;
    if (account == null) return;
    final previous = await _cursors.readCursor(accountKey);
    if (previous == account) return;
    if (previous != null) {
      for (final source in _sources) {
        await _cursors.writeCursor(source.collection, null);
        await source.markAllDirty();
      }
    }
    await _cursors.writeCursor(accountKey, account);
  }

  Future<void> _push(RemoteStore remote, LocalSyncSource source) async {
    final pending = await source.pendingChanges();
    for (var i = 0; i < pending.length; i += _pushBatchSize) {
      final chunk = pending.sublist(i, (i + _pushBatchSize).clamp(0, pending.length));
      await remote.push(source.collection, chunk);
      await source.markSynced(chunk);
    }
  }

  Future<void> _pull(RemoteStore remote, LocalSyncSource source) async {
    var cursor = await _cursors.readCursor(source.collection);
    PullResult result;
    do {
      result = await remote.pull(source.collection, cursor: cursor);
      if (result.records.isNotEmpty) await source.applyRemote(result.records);
      cursor = result.cursor;
      await _cursors.writeCursor(source.collection, cursor);
    } while (result.hasMore && !_disposed);
  }

  Future<int> _pendingCount() async {
    var count = 0;
    for (final s in _sources) {
      count += (await s.pendingChanges()).length;
    }
    return count;
  }

  Future<void> _refreshPending() async {
    if (_disposed) return;
    _emit(_status.copyWith(pendingCount: await _pendingCount()));
  }

  void _emit(SyncStatus status) {
    if (_disposed) return;
    _status = status;
    _statusController.add(status);
  }

  Future<void> dispose() async {
    _disposed = true;
    _debounceTimer?.cancel();
    _retryTimer?.cancel();
    for (final s in _subscriptions) {
      await s.cancel();
    }
    await _statusController.close();
  }
}

/// Erasing the backup didn't work; [message] says why.
class EraseFailed implements Exception {
  const EraseFailed(this.message);

  final String message;

  @override
  String toString() => message;
}
