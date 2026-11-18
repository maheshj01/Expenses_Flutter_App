import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../sync/remote_store.dart';
import 'default_categories.dart';

part 'app_database.g.dart';

/// Columns every synced table has.
mixin SyncColumns on Table {
  /// Milliseconds since epoch of the last edit (local or remote).
  IntColumn get updatedAt => integer()();

  /// Soft delete, so deletions can be synced.
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  /// True while the change has not been pushed to the remote store.
  BoolColumn get dirty => boolean().withDefault(const Constant(true))();
}

@DataClassName('CategoryRow')
class Categories extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get emoji => text()();
  IntColumn get color => integer()();
  TextColumn get kind => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('EntryRow')
@TableIndex(name: 'entries_day', columns: {#day})
class Entries extends Table with SyncColumns {
  TextColumn get id => text()();
  IntColumn get amountCents => integer()();
  TextColumn get categoryId => text()();

  /// Calendar date as yyyymmdd, see DayKey.
  IntColumn get day => integer()();
  TextColumn get note => text().withDefault(const Constant(''))();
  IntColumn get splitWays => integer().withDefault(const Constant(1))();

  /// Names of people sharing it who aren't on the app, as a JSON list.
  TextColumn get guestNames => text().withDefault(const Constant(''))();

  /// Id of the shared bill this entry is your share of, if any.
  TextColumn get billId => text().nullable()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Where each collection's last pull from the remote store stopped.
@DataClassName('SyncCursorRow')
class SyncCursors extends Table {
  TextColumn get collection => text()();
  TextColumn get cursor => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {collection};
}

@DriftDatabase(tables: [Categories, Entries, SyncCursors])
class AppDatabase extends _$AppDatabase implements SyncCursorStore {
  AppDatabase(super.executor);

  /// Opens the on-device database file.
  factory AppDatabase.open() => AppDatabase(driftDatabase(name: 'three_bucks'));

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _seedCategories();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) await m.addColumn(entries, entries.billId);
      if (from < 3) await m.addColumn(entries, entries.guestNames);
    },
  );

  Future<void> _seedCategories() {
    return batch((b) {
      b.insertAll(categories, [
        for (final c in defaultCategories)
          CategoriesCompanion.insert(
            id: c.id,
            name: c.name,
            emoji: c.emoji,
            color: c.color,
            kind: c.kind.name,
            sortOrder: Value(c.sortOrder),
            // Seeds lose to any edit made on another device.
            updatedAt: 0,
            dirty: const Value(false),
          ),
      ]);
    });
  }

  @override
  Future<String?> readCursor(String collection) async {
    final row = await (select(
      syncCursors,
    )..where((t) => t.collection.equals(collection))).getSingleOrNull();
    return row?.cursor;
  }

  @override
  Future<void> writeCursor(String collection, String? cursor) {
    return into(syncCursors).insertOnConflictUpdate(
      SyncCursorsCompanion.insert(collection: collection, cursor: Value(cursor)),
    );
  }
}
