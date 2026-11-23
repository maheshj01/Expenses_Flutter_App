import 'dart:convert';

import 'package:drift/drift.dart';

import '../../domain/history/edit.dart';
import '../sync/local_sync_source.dart';
import '../sync/sync_record.dart';
import 'app_database.dart';

/// Backs up entry edit history (see `DriftEntryRepository.save`) as the
/// `entry_edits` collection. Edits are written once, so syncing them only
/// ever adds records.
class DriftEntryEditSync implements LocalSyncSource {
  DriftEntryEditSync(this._db);

  final AppDatabase _db;

  $EntryEditsTable get _t => _db.entryEdits;

  static Edit toEdit(EntryEditRow r) => Edit(
    id: r.id,
    subjectId: r.entryId,
    at: DateTime.fromMillisecondsSinceEpoch(r.at),
    changes: Edit.changesFromJson(jsonDecode(r.changes)),
  );

  @override
  String get collection => 'entry_edits';

  @override
  Future<List<SyncRecord>> pendingChanges() async {
    final rows = await (_db.select(_t)..where((t) => t.dirty.equals(true))).get();
    return [
      for (final r in rows)
        SyncRecord(
          id: r.id,
          updatedAt: r.updatedAt,
          deleted: r.deleted,
          data: {'entryId': r.entryId, 'at': r.at, 'changes': jsonDecode(r.changes)},
        ),
    ];
  }

  @override
  Future<void> markAllDirty() async {
    await _db.update(_t).write(const EntryEditsCompanion(dirty: Value(true)));
  }

  @override
  Future<void> markSynced(List<SyncRecord> records) {
    return _db.batch((b) {
      for (final r in records) {
        b.update(
          _t,
          const EntryEditsCompanion(dirty: Value(false)),
          where: (t) => t.id.equals(r.id) & t.updatedAt.equals(r.updatedAt),
        );
      }
    });
  }

  @override
  Future<void> applyRemote(List<SyncRecord> records) {
    return _db.transaction(() async {
      for (final r in records) {
        final local = await (_db.select(_t)..where((t) => t.id.equals(r.id))).getSingleOrNull();
        if (local != null && local.updatedAt >= r.updatedAt) continue;
        final d = r.data;
        await _db
            .into(_t)
            .insertOnConflictUpdate(
              EntryEditsCompanion.insert(
                id: r.id,
                entryId: d['entryId'] as String? ?? local?.entryId ?? '',
                at: (d['at'] as num?)?.toInt() ?? r.updatedAt,
                changes: jsonEncode(d['changes'] ?? const {}),
                updatedAt: r.updatedAt,
                deleted: Value(r.deleted),
                dirty: const Value(false),
              ),
            );
      }
    });
  }
}
