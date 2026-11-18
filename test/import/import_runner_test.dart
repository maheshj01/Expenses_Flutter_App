import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:three_bucks/data/local/app_database.dart';
import 'package:three_bucks/data/local/drift_category_repository.dart';
import 'package:three_bucks/data/local/drift_entry_repository.dart';
import 'package:three_bucks/data/sync/local_sync_source.dart';
import 'package:three_bucks/domain/import/import_plan.dart';
import 'package:three_bucks/domain/import/import_runner.dart';
import 'package:three_bucks/domain/import/raw_sheet.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late DriftEntryRepository entries;
  late DriftCategoryRepository categories;
  late ImportRunner runner;
  final changes = LocalChanges();

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    entries = DriftEntryRepository(db, changes);
    categories = DriftCategoryRepository(db, changes);
    runner = ImportRunner(entries, categories);
  });

  tearDown(() => db.close());

  const sheet = RawSheet('Sheet1', [
    ['Date', 'Amount', 'Category', 'Description'],
    ['2026-02-01', 1170, 'Housing', 'Rent'],
    ['2026-02-02', 49, 'Taxes', 'Filing fee'],
    ['2026-02-03', 12.5, 'Travel', 'Bus'],
  ]);

  Future<ImportPlan> plan() async => ImportPlanner.build(
    sheets: SheetChoice.detect([sheet]),
    categories: await categories.getAll(),
    existing: await entries.watchBetween(DateTime(1900), DateTime(2200)).first,
  );

  test('imports, restores archived categories, and undoes cleanly', () async {
    await categories.setArchived('travel', archived: true);

    final result = await runner.apply(await plan());
    expect(result.count, 3);
    expect(result.createdCategoryIds, ['imp_taxe']);
    expect(result.restoredCategoryIds, ['travel']);

    final all = await categories.getAll();
    expect(all.firstWhere((c) => c.id == 'travel').archived, isFalse);
    expect(all.firstWhere((c) => c.id == 'imp_taxe').name, 'Taxes');
    expect((await entries.watchBetween(DateTime(2026), DateTime(2026, 12, 31)).first).length, 3);
    expect((await entries.pendingChanges()).length, 3, reason: 'imported entries sync');

    // A second import of the same file finds nothing new.
    expect((await plan()).entries, isEmpty);

    await runner.undo(result);
    expect(await entries.watchBetween(DateTime(2026), DateTime(2026, 12, 31)).first, isEmpty);
    final after = await categories.getAll();
    expect(after.firstWhere((c) => c.id == 'travel').archived, isTrue);
    expect(after.firstWhere((c) => c.id == 'imp_taxe').archived, isTrue);
  });
}
