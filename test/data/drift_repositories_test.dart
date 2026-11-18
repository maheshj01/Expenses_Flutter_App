import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneytrace/data/local/app_database.dart';
import 'package:moneytrace/data/local/default_categories.dart';
import 'package:moneytrace/data/local/drift_category_repository.dart';
import 'package:moneytrace/data/local/drift_entry_repository.dart';
import 'package:moneytrace/data/sync/local_sync_source.dart';
import 'package:moneytrace/data/sync/sync_record.dart';
import 'package:moneytrace/domain/entities/category.dart';
import 'package:moneytrace/domain/entities/ledger_entry.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late LocalChanges changes;
  late DateTime now;
  late DriftCategoryRepository categories;
  late DriftEntryRepository entries;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    changes = LocalChanges();
    now = DateTime(2026, 11, 17, 9);
    categories = DriftCategoryRepository(db, changes, clock: () => now);
    entries = DriftEntryRepository(db, changes, clock: () => now);
  });

  tearDown(() async {
    await db.close();
    await changes.dispose();
  });

  LedgerEntry entry(String id, int cents, DateTime date, {String cat = 'food'}) =>
      LedgerEntry(id: id, amountCents: cents, categoryId: cat, date: date);

  group('categories', () {
    test('are seeded and not pending sync', () async {
      final all = await categories.getAll();
      expect(all.length, defaultCategories.length);
      expect(await categories.pendingChanges(), isEmpty);
    });

    test('can be added, edited and archived', () async {
      await categories.save(const Category(id: 'pets', name: ' Pets ', emoji: '🐶', color: 1));
      var pets = (await categories.getAll()).firstWhere((c) => c.id == 'pets');
      expect(pets.name, 'Pets');
      expect(pets.sortOrder, defaultCategories.length, reason: 'new categories go last');

      await categories.save(pets.copyWith(name: 'Pet care', kind: CategoryKind.spending));
      await categories.setArchived('pets', archived: true);

      final visible = await categories.watchAll().first;
      expect(visible.any((c) => c.id == 'pets'), isFalse);
      pets = (await categories.getAll()).firstWhere((c) => c.id == 'pets');
      expect(pets.name, 'Pet care');
      expect(pets.archived, isTrue);
      expect((await categories.pendingChanges()).single.id, 'pets');
    });
  });

  group('entries', () {
    test('are queried by date range and years', () async {
      await entries.save(entry('a', 1000, DateTime(2026, 11, 2)));
      await entries.save(entry('b', 2000, DateTime(2026, 10, 31)));
      await entries.save(entry('c', 3000, DateTime(2025, 3, 1)));

      final nov = await entries.watchBetween(DateTime(2026, 11), DateTime(2026, 11, 30)).first;
      expect(nov.map((e) => e.id), ['a']);
      expect(await entries.watchYears().first, [2026, 2025]);
    });

    test('delete leaves a tombstone for sync', () async {
      await entries.save(entry('a', 1000, DateTime(2026, 11, 2)));
      await entries.markSynced(await entries.pendingChanges());
      expect(await entries.pendingChanges(), isEmpty);

      await entries.delete('a');
      expect(await entries.watchBetween(DateTime(2026), DateTime(2026, 12, 31)).first, isEmpty);
      final pending = await entries.pendingChanges();
      expect(pending.single.deleted, isTrue);
    });

    test('writes notify listeners', () async {
      var count = 0;
      final sub = changes.stream.listen((_) => count++);
      await entries.save(entry('a', 1000, DateTime(2026, 11, 2)));
      await entries.delete('a');
      await Future<void>.delayed(Duration.zero);
      expect(count, 2);
      await sub.cancel();
    });
  });

  group('sync helpers', () {
    test('markSynced skips records edited after they were read', () async {
      await entries.save(entry('a', 1000, DateTime(2026, 11, 2)));
      final snapshot = await entries.pendingChanges();
      now = now.add(const Duration(seconds: 1));
      await entries.save(entry('a', 1500, DateTime(2026, 11, 2)));
      await entries.markSynced(snapshot);
      expect((await entries.pendingChanges()).single.data['amountCents'], 1500);
    });

    test('applyRemote keeps the newest edit', () async {
      await entries.save(entry('a', 1000, DateTime(2026, 11, 2))); // updatedAt = now
      final t = now.millisecondsSinceEpoch;

      SyncRecord remote(int cents, int updatedAt) => SyncRecord(
        id: 'a',
        updatedAt: updatedAt,
        data: {
          'amountCents': cents,
          'categoryId': 'food',
          'day': 20261102,
          'note': '',
          'splitWays': 1,
          'createdAt': t,
        },
      );

      await entries.applyRemote([remote(500, t - 1000)]);
      var list = await entries.watchBetween(DateTime(2026, 11), DateTime(2026, 11, 30)).first;
      expect(list.single.amountCents, 1000, reason: 'older remote edit loses');

      await entries.applyRemote([remote(700, t + 1000)]);
      list = await entries.watchBetween(DateTime(2026, 11), DateTime(2026, 11, 30)).first;
      expect(list.single.amountCents, 700, reason: 'newer remote edit wins');
      expect(await entries.pendingChanges(), isEmpty);
    });

    test('remote tombstones remove local records', () async {
      await entries.save(entry('a', 1000, DateTime(2026, 11, 2)));
      await entries.applyRemote([
        SyncRecord(
          id: 'a',
          updatedAt: now.millisecondsSinceEpoch + 1,
          deleted: true,
          data: const {},
        ),
      ]);
      expect(await entries.watchBetween(DateTime(2026), DateTime(2026, 12, 31)).first, isEmpty);
    });

    test('cursors are stored per collection', () async {
      expect(await db.readCursor('entries'), isNull);
      await db.writeCursor('entries', '42');
      expect(await db.readCursor('entries'), '42');
    });
  });
}
