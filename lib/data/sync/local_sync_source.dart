import 'dart:async';

import 'sync_record.dart';

/// Implemented by each local table that takes part in sync.
abstract interface class LocalSyncSource {
  /// Name of the collection on the remote side, e.g. `entries`.
  String get collection;

  /// Records changed locally that the remote has not seen yet.
  Future<List<SyncRecord>> pendingChanges();

  /// Marks [records] as synced, unless they were edited again meanwhile.
  Future<void> markSynced(List<SyncRecord> records);

  /// Applies remote changes, keeping whichever side was edited last.
  Future<void> applyRemote(List<SyncRecord> records);
}

/// Fires whenever the user changes local data, so sync can be scheduled.
class LocalChanges {
  final _controller = StreamController<void>.broadcast();

  Stream<void> get stream => _controller.stream;

  void notify() => _controller.add(null);

  Future<void> dispose() => _controller.close();
}
