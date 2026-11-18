/// A backend-neutral snapshot of one record, used to move data between the
/// local database and any remote store.
///
/// Field names inside [data] are part of the sync format and must stay
/// stable across app versions and backends.
class SyncRecord {
  const SyncRecord({
    required this.id,
    required this.data,
    required this.updatedAt,
    this.deleted = false,
  });

  final String id;
  final Map<String, Object?> data;

  /// Milliseconds since epoch of the last local edit. Used for
  /// last-write-wins conflict resolution.
  final int updatedAt;

  /// Tombstone: the record was deleted and the deletion must propagate.
  final bool deleted;

  @override
  String toString() => 'SyncRecord($id, $updatedAt${deleted ? ', deleted' : ''})';
}
