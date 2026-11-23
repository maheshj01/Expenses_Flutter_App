import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/clock.dart';
import '../../core/day.dart';
import '../../core/ids.dart';
import '../../domain/entities/ledger_entry.dart';
import '../../domain/history/edit.dart';
import '../../domain/repositories/entry_repository.dart';
import '../sync/local_sync_source.dart';
import '../sync/sync_record.dart';
import 'app_database.dart';
import 'drift_entry_edit_sync.dart';

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
  Future<int> count() async {
    final n = _t.id.count();
    final query = _db.selectOnly(_t)
      ..addColumns([n])
      ..where(_t.deleted.equals(false));
    return (await query.getSingle()).read(n) ?? 0;
  }

  @override
  Stream<Set<String>> watchSharedBillIds() {
    final query = _db.selectOnly(_t)
      ..addColumns([_t.billId])
      ..where(_t.deleted.equals(false) & _t.billId.isNotNull());
    return query.watch().map((rows) => {for (final r in rows) r.read(_t.billId)!});
  }

  EntriesCompanion _companion(LedgerEntry entry, int now) => EntriesCompanion.insert(
    id: entry.id,
    amountCents: entry.amountCents,
    categoryId: entry.categoryId,
    day: DayKey.fromDate(entry.date),
    note: Value(entry.note.trim()),
    splitWays: Value(entry.splitWays),
    guestNames: Value(_encodeNames(entry.guestNames)),
    billId: Value(entry.billId),
    createdAt: entry.createdAt?.millisecondsSinceEpoch ?? now,
    updatedAt: now,
    deleted: const Value(false),
    dirty: const Value(true),
  );

  @override
  Future<void> save(LedgerEntry entry) async {
    final now = _now;
    await _db.transaction(() async {
      final before = await (_db.select(
        _t,
      )..where((t) => t.id.equals(entry.id) & t.deleted.equals(false))).getSingleOrNull();
      await _db.into(_t).insertOnConflictUpdate(_companion(entry, now));
      // Shares of bills keep their history on the bill.
      if (before == null || before.billId != null || entry.billId != null) return;
      final changes = entryChanges(_toEntity(before), entry);
      if (changes.isEmpty) return;
      await _db
          .into(_db.entryEdits)
          .insert(
            EntryEditsCompanion.insert(
              id: newId(),
              entryId: entry.id,
              at: now,
              changes: jsonEncode(Edit.changesToJson(changes)),
              updatedAt: now,
            ),
          );
    });
    _changes.notify();
  }

  @override
  Stream<List<Edit>> watchEdits(String entryId) {
    final query = _db.select(_db.entryEdits)
      ..where((t) => t.entryId.equals(entryId) & t.deleted.equals(false))
      ..orderBy([(t) => OrderingTerm.desc(t.at)]);
    return query.watch().map((rows) => rows.map(DriftEntryEditSync.toEdit).toList());
  }

  @override
  Future<void> saveAll(List<LedgerEntry> entries) async {
    if (entries.isEmpty) return;
    final now = _now;
    await _db.batch((b) {
      for (final e in entries) {
        b.insert(_t, _companion(e, now), onConflict: DoUpdate((_) => _companion(e, now)));
      }
    });
    _changes.notify();
  }

  @override
  Future<void> delete(String id) => deleteAll([id]);

  @override
  Future<void> deleteAll(List<String> ids) async {
    if (ids.isEmpty) return;
    await (_db.update(_t)..where((t) => t.id.isIn(ids))).write(
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
              'guestNames': _decodeNames(r.guestNames),
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
                guestNames: Value(
                  _encodeNames([
                    for (final n in d['guestNames'] as List? ?? const [])
                      if (n is String) n,
                  ]),
                ),
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
    guestNames: _decodeNames(r.guestNames),
    billId: r.billId,
    createdAt: DateTime.fromMillisecondsSinceEpoch(r.createdAt),
  );

  static String _encodeNames(List<String> names) {
    final clean = [
      for (final n in names)
        if (n.trim().isNotEmpty) n.trim(),
    ];
    return clean.isEmpty ? '' : jsonEncode(clean);
  }

  static List<String> _decodeNames(String raw) {
    if (raw.isEmpty) return const [];
    final decoded = jsonDecode(raw);
    return decoded is List
        ? [
            for (final n in decoded)
              if (n is String) n,
          ]
        : const [];
  }
}
