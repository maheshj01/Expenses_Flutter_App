import 'sync_record.dart';

/// The only thing a backend has to implement to sync the app's data.
///
/// The app never talks to a backend directly: all reads and writes go to
/// the local database, and the sync engine moves changes through this
/// interface. Switching from Firebase to Supabase, a REST API or anything
/// else means writing one new implementation of this class.
abstract interface class RemoteStore {
  /// Human readable name shown in settings, e.g. "Firebase".
  String get displayName;

  /// Prepares the connection. Called before each sync; should be cheap when
  /// already connected. Never signs anyone in: backup is only for people
  /// who signed in themselves.
  Future<void> connect();

  /// The signed-in account whose data this store reads and writes, or null
  /// when nobody is signed in (the engine then doesn't sync). When it
  /// changes (another account signed in), the engine starts over and merges
  /// this device's data into the new account.
  String? get accountId;

  /// Upserts [records] (including tombstones) into [collection].
  Future<void> push(String collection, List<SyncRecord> records);

  /// Returns records in [collection] changed after [cursor]. A null cursor
  /// means "from the beginning". The returned cursor is opaque to the app
  /// and is passed back on the next pull.
  Future<PullResult> pull(String collection, {String? cursor});

  /// Why a sync failed, in one short sentence for people using the app,
  /// e.g. "Can’t reach the backup server." Never the raw error.
  String describeError(Object error);
}

class PullResult {
  const PullResult({required this.records, required this.cursor, this.hasMore = false});

  final List<SyncRecord> records;
  final String? cursor;

  /// True when more changes are waiting; the engine pulls again right away.
  final bool hasMore;
}

/// Persists the pull position of each collection.
abstract interface class SyncCursorStore {
  Future<String?> readCursor(String collection);

  Future<void> writeCursor(String collection, String? cursor);
}
