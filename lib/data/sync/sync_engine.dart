import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/clock.dart';
import 'connectivity_monitor.dart';
import 'local_sync_source.dart';
import 'remote_store.dart';
import 'sync_status.dart';

/// Moves changes between the local database and a [RemoteStore].
///
/// - Each run pulls remote changes, then pushes local ones.
/// - Runs on start, shortly after local edits (debounced), when the
///   network returns, and on returning to the app if it's been a while.
/// - Conflicts are resolved per record: the most recent edit wins.
/// - Without a network, changes stay queued in the local database.
/// - Only a signed-in account syncs. Signed out, changes stay queued and
///   reach the account once someone signs in and [syncNow] runs.
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
    if (!isEnabled) {
      unawaited(_refreshPending());
      return;
    }
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, () => unawaited(syncNow()));
  }

  /// Runs a full push + pull. Concurrent calls share one run, and a call
  /// made during a run triggers one more run afterwards.
  Future<void> syncNow() {
    if (!isEnabled || _disposed) return Future.value();
    if (_running != null) {
      _runAgain = true;
      return _running!;
    }
    final run = _runLoop();
    _running = run;
    return run.whenComplete(() => _running = null);
  }

  /// [syncNow], unless the last sync succeeded within [maxAge]. For when
  /// the app comes back to the foreground: picks up changes made on other
  /// devices without a round trip on every switch.
  Future<void> syncIfStale({Duration maxAge = const Duration(minutes: 2)}) {
    final last = _status.lastSyncedAt;
    final fresh =
        _status.phase == SyncPhase.idle && last != null && _clock().difference(last) < maxAge;
    return fresh ? Future.value() : syncNow();
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

    if (remote.accountId == null) {
      _emit(_status.copyWith(phase: SyncPhase.signedOut, pendingCount: await _pendingCount()));
      return;
    }

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
      debugPrint('Sync failed: $e');
      _emit(
        _status.copyWith(
          phase: SyncPhase.error,
          message: remote.describeError(e),
          pendingCount: await _pendingCount(),
        ),
      );
      _retryTimer = Timer(_retryAfter, () => unawaited(syncNow()));
    }
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
