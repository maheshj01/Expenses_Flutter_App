import 'package:flutter_test/flutter_test.dart';
import 'package:three_bucks/data/export/xlsx_export.dart';
import 'package:three_bucks/data/import/spreadsheet_reader.dart';
import 'package:three_bucks/data/local/default_categories.dart';
import 'package:three_bucks/domain/entities/ledger_entry.dart';
import 'package:three_bucks/domain/import/import_plan.dart';

void main() {
  final entries = [
    LedgerEntry(
      id: 'a',
      amountCents: 4610,
      categoryId: 'food',
      date: DateTime(2025, 12, 30),
      note: 'Costco',
      splitWays: 2,
      guestNames: const ['Sam'],
    ),
    LedgerEntry(
      id: 'b',
      amountCents: -50000,
      categoryId: 'housing',
      date: DateTime(2026, 1, 3),
      note: 'Rent back',
    ),
    LedgerEntry(
      id: 'c',
      amountCents: 240000,
      categoryId: 'investment',
      date: DateTime(2026, 4, 3),
      note: 'VOO',
    ),
    LedgerEntry(id: 'd', amountCents: 72, categoryId: 'food', date: DateTime(2026, 4, 4)),
  ];

  test('an export imports back into the same entries', () {
    final bytes = buildExportWorkbook(
      ExportData(entries: entries, categories: defaultCategories, label: 'All years'),
    );
    final sheets = readSpreadsheet(bytes, exportFileName('All years'));
    expect(sheets.map((s) => s.name), containsAll(['Entries', 'Summary 2026', 'Summary 2025']));

    final choices = SheetChoice.detect(sheets);
    expect(
      [
        for (final c in choices)
          if (c.included) c.sheet.name,
      ],
      ['Entries'],
    );

    final plan = ImportPlanner.build(
      sheets: choices,
      categories: defaultCategories,
      existing: const [],
    );
    expect(plan.problems, isEmpty);
    expect(plan.newCategories, isEmpty);
    expect(
      [
        for (final e in plan.entries)
          (e.date, e.amountCents, e.categoryId, e.note, e.splitWays, e.guestNames.join(',')),
      ],
      [
        for (final e in entries)
          (e.date, e.amountCents, e.categoryId, e.note, e.splitWays, e.guestNames.join(',')),
      ],
    );

    // Importing it where the entries already exist adds nothing.
    final again = ImportPlanner.build(
      sheets: choices,
      categories: defaultCategories,
      existing: entries,
    );
    expect(again.entries, isEmpty);
  });

  test('the yearly summary adds up your share per category and month', () {
    final bytes = buildExportWorkbook(
      ExportData(entries: entries, categories: defaultCategories, label: '2026'),
    );
    final summary = readSpreadsheet(bytes, 'x.xlsx').firstWhere((s) => s.name == 'Summary 2026');
    List<Object?> row(String label) =>
        summary.rows.firstWhere((r) => r.isNotEmpty && r.first == label);
    expect(row('Food')[4], 0.72, reason: 'April column');
    expect(row('Housing')[1], -500, reason: 'money back lowers January');
    expect(row('Invested total').last, 2400);
  });

  test('file names are safe', () {
    expect(exportFileName('All years'), 'three-bucks-all-years.xlsx');
    expect(exportFileName('2026'), 'three-bucks-2026.xlsx');
  });
}
