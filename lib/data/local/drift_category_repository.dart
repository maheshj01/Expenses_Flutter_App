import 'package:drift/drift.dart';

import '../../core/clock.dart';
import '../../domain/entities/category.dart';
import '../../domain/repositories/category_repository.dart';
import '../sync/local_sync_source.dart';
import '../sync/sync_record.dart';
import 'app_database.dart';

class DriftCategoryRepository implements CategoryRepository, LocalSyncSource {
  DriftCategoryRepository(this._db, this._changes, {this._clock = systemClock});

  final AppDatabase _db;
  final LocalChanges _changes;
  final Clock _clock;

  $CategoriesTable get _t => _db.categories;

  int get _now => _clock().millisecondsSinceEpoch;

  SimpleSelectStatement<$CategoriesTable, CategoryRow> _query(bool includeArchived) {
    return _db.select(_t)
      ..where((t) => t.deleted.equals(false))
      ..where((t) => includeArchived ? const Constant(true) : t.archived.equals(false))
      ..orderBy([(t) => OrderingTerm.asc(t.sortOrder), (t) => OrderingTerm.asc(t.name)]);
  }

  @override
  Stream<List<Category>> watchAll({bool includeArchived = false}) =>
      _query(includeArchived).watch().map((rows) => rows.map(_toEntity).toList());

  @override
  Future<List<Category>> getAll({bool includeArchived = true}) async =>
      (await _query(includeArchived).get()).map(_toEntity).toList();

  @override
  Future<void> save(Category category) async {
    var sortOrder = category.sortOrder;
    final exists = await (_db.select(_t)..where((t) => t.id.equals(category.id))).getSingleOrNull();
    if (exists == null && sortOrder == 0) {
      final max = _t.sortOrder.max();
      final row = await (_db.selectOnly(_t)..addColumns([max])).getSingle();
      sortOrder = (row.read(max) ?? -1) + 1;
    }
    await _db
        .into(_t)
        .insertOnConflictUpdate(
          CategoriesCompanion.insert(
            id: category.id,
            name: category.name.trim(),
            emoji: category.emoji,
            color: category.color,
            kind: category.kind.name,
            sortOrder: Value(sortOrder),
            archived: Value(category.archived),
            updatedAt: _now,
            deleted: const Value(false),
            dirty: const Value(true),
          ),
        );
    _changes.notify();
  }

  @override
  Future<void> setArchived(String id, {required bool archived}) async {
    await (_db.update(_t)..where((t) => t.id.equals(id))).write(
      CategoriesCompanion(
        archived: Value(archived),
        updatedAt: Value(_now),
        dirty: const Value(true),
      ),
    );
    _changes.notify();
  }

  // ---- sync ----

  @override
  String get collection => 'categories';

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
              'name': r.name,
              'emoji': r.emoji,
              'color': r.color,
              'kind': r.kind,
              'sortOrder': r.sortOrder,
              'archived': r.archived,
            },
          ),
        )
        .toList();
  }

  @override
  Future<void> markSynced(List<SyncRecord> records) {
    return _db.batch((b) {
      for (final r in records) {
        b.update(
          _t,
          const CategoriesCompanion(dirty: Value(false)),
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
              CategoriesCompanion.insert(
                id: r.id,
                name: d['name'] as String? ?? local?.name ?? '',
                emoji: d['emoji'] as String? ?? local?.emoji ?? '•',
                color: (d['color'] as num?)?.toInt() ?? local?.color ?? 0xFFF1EEE8,
                kind: d['kind'] as String? ?? local?.kind ?? CategoryKind.spending.name,
                sortOrder: Value((d['sortOrder'] as num?)?.toInt() ?? 0),
                archived: Value(d['archived'] as bool? ?? false),
                updatedAt: r.updatedAt,
                deleted: Value(r.deleted),
                dirty: const Value(false),
              ),
            );
      }
    });
  }

  static Category _toEntity(CategoryRow r) => Category(
    id: r.id,
    name: r.name,
    emoji: r.emoji,
    color: r.color,
    kind: CategoryKind.parse(r.kind),
    sortOrder: r.sortOrder,
    archived: r.archived,
  );
}
