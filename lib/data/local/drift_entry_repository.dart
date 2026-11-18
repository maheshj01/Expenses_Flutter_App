import 'package:drift/drift.dart';

import '../../core/clock.dart';
import '../../core/day.dart';
import '../../domain/entities/ledger_entry.dart';
import '../../domain/repositories/entry_repository.dart';
import '../sync/local_sync_source.dart';
import '../sync/sync_record.dart';
import 'app_database.dart';

class DriftEntryRepository implements EntryRepository, LocalSyncSource {
  DriftEntryRepository(this._db, this._changes, {this._clock = systemClock});

  final AppDatabase _db;
  final LocalChanges _changes;
  final Clock _clock;

  $EntriesTable get _t => _db.entries;

  int get _now => _clock().millisecondsSinceEpoch;

  @override
  Stream<List<LedgerEntry>> watchBetween(DateTime from, DateTime to) {
    final query = _db.select(_t)
      ..where((t) => t.deleted.equals(false))
      ..where((t) => t.day.isBetweenValues(DayKey.fromDate(from), DayKey.fromDate(to)))
      ..orderBy([(t) => OrderingTerm.desc(t.day), (t) => OrderingTerm.desc(t.createdAt)]);
    return query.watch().map((rows) => rows.map(_toEntity).toList());
  }

  @override
  Stream<List<int>> watchYears() {
    return _db
        .customSelect(
          'SELECT DISTINCT day / 10000 AS year FROM entries WHERE deleted = 0 ORDER BY year DESC',
          readsFrom: {_t},
        )
        .watch()
        .map((rows) => rows.map((r) => r.read<int>('year')).toList());
  }

  @override
  Future<List<LedgerEntry>> recent({int limit = 500}) async {
    final query = _db.select(_t)
      ..where((t) => t.deleted.equals(false))
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
      ..limit(limit);
    return (await query.get()).map(_toEntity).toList();
  }

  @override
  Future<LedgerEntry?> byId(String id) async {
    final row = await (_db.select(
      _t,
    )..where((t) => t.id.equals(id) & t.deleted.equals(false))).getSingleOrNull();
    return row == null ? null : _toEntity(row);
  }

  @override
  Future<List<LedgerEntry>> sharedEntries() async {
    final query = _db.select(_t)..where((t) => t.deleted.equals(false) & t.billId.isNotNull());
    return (await query.get()).map(_toEntity).toList();
  }

  @override
  Future<void> save(LedgerEntry entry) async {
    final now = _now;
    await _db
        .into(_t)
        .insertOnConflictUpdate(
          EntriesCompanion.insert(
            id: entry.id,
            amountCents: entry.amountCents,
            categoryId: entry.categoryId,
            day: DayKey.fromDate(entry.date),
            note: Value(entry.note.trim()),
            splitWays: Value(entry.splitWays),
            billId: Value(entry.billId),
            createdAt: entry.createdAt?.millisecondsSinceEpoch ?? now,
            updatedAt: now,
            deleted: const Value(false),
            dirty: const Value(true),
          ),
        );
    _changes.notify();
  }

  @override
  Future<void> delete(String id) async {
    await (_db.update(_t)..where((t) => t.id.equals(id))).write(
      EntriesCompanion(
        deleted: const Value(true),
        updatedAt: Value(_now),
        dirty: const Value(true),
      ),
    );
    _changes.notify();
  }

  // ---- sync ----

  @override
  String get collection => 'entries';

  @override
  Future<List<SyncRecord>> pendingChanges() async {
    final rows = await (_db.select(_t)..where((t) => t.dirty.equals(true))).get();
    return rows
        .map(
          (r) => SyncRecord(
            id: r.id,
            updatedAt: r.updatedAt,
            deleted: r.deleted,
            data: {
              'amountCents': r.amountCents,
              'categoryId': r.categoryId,
              'day': r.day,
              'note': r.note,
              'splitWays': r.splitWays,
              'billId': r.billId,
              'createdAt': r.createdAt,
            },
          ),
        )
        .toList();
  }

  @override
  Future<void> markAllDirty() async {
    await _db.update(_t).write(const EntriesCompanion(dirty: Value(true)));
  }

  @override
  Future<void> markSynced(List<SyncRecord> records) {
    return _db.batch((b) {
      for (final r in records) {
        b.update(
          _t,
          const EntriesCompanion(dirty: Value(false)),
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
              EntriesCompanion.insert(
                id: r.id,
                amountCents: (d['amountCents'] as num?)?.toInt() ?? local?.amountCents ?? 0,
                categoryId: d['categoryId'] as String? ?? local?.categoryId ?? 'misc',
                day: (d['day'] as num?)?.toInt() ?? local?.day ?? DayKey.fromDate(_clock()),
                note: Value(d['note'] as String? ?? ''),
                splitWays: Value((d['splitWays'] as num?)?.toInt() ?? 1),
                billId: Value(d['billId'] as String?),
                createdAt: (d['createdAt'] as num?)?.toInt() ?? r.updatedAt,
                updatedAt: r.updatedAt,
                deleted: Value(r.deleted),
                dirty: const Value(false),
              ),
            );
      }
    });
  }

  static LedgerEntry _toEntity(EntryRow r) => LedgerEntry(
    id: r.id,
    amountCents: r.amountCents,
    categoryId: r.categoryId,
    date: DayKey.toDate(r.day),
    note: r.note,
    splitWays: r.splitWays,
    billId: r.billId,
    createdAt: DateTime.fromMillisecondsSinceEpoch(r.createdAt),
  );
}
