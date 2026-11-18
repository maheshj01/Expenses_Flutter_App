import 'package:flutter_test/flutter_test.dart';
import 'package:three_bucks/data/local/default_categories.dart';
import 'package:three_bucks/domain/entities/category.dart';
import 'package:three_bucks/domain/entities/ledger_entry.dart';
import 'package:three_bucks/domain/import/cell_values.dart';
import 'package:three_bucks/domain/import/column_mapping.dart';
import 'package:three_bucks/domain/import/import_plan.dart';
import 'package:three_bucks/domain/import/raw_sheet.dart';

/// A month tab laid out like a common expenses template: a title row,
/// headers on row 2, Excel serial dates, and a total row at the bottom.
RawSheet monthTab(String name, List<List<Object?>> rows) => RawSheet(name, [
  ['MONTHLY EXPENSES', null, null, 'Summary'],
  ['Date', 'PO#', 'Amount', 'Category', 'Description'],
  ...rows,
  ['Total', null, 999, null, null],
]);

// 2026-01-01 is Excel day 46023.
const jan1 = 46023;

void main() {
  group('CellValues', () {
    test('reads dates in many forms', () {
      expect(CellValues.date(jan1), DateTime(2026));
      expect(CellValues.date('2026-01-03'), DateTime(2026, 1, 3));
      expect(CellValues.date('1/3/2026'), DateTime(2026, 1, 3));
      expect(CellValues.date('1/3/2026', dayFirst: true), DateTime(2026, 3, 1));
      expect(CellValues.date('25/12/26'), DateTime(2026, 12, 25));
      expect(CellValues.date('Jan 3, 2026'), DateTime(2026, 1, 3));
      expect(CellValues.date('3 January 2026'), DateTime(2026, 1, 3));
      expect(CellValues.date(DateTime(2026, 5, 6, 13)), DateTime(2026, 5, 6));
      expect(CellValues.date('Total'), isNull);
      expect(CellValues.date(12), isNull, reason: 'too small to be a date');
      expect(CellValues.date('2/30/2026'), isNull);
    });

    test('reads amounts in many forms', () {
      expect(CellValues.cents(17), 1700);
      expect(CellValues.cents(0.72), 72);
      expect(CellValues.cents(r'$1,166.50'), 116650);
      expect(CellValues.cents('(12.00)'), -1200);
      expect(CellValues.cents('-500'), -50000);
      expect(CellValues.cents('1.234,56'), 123456);
      expect(CellValues.cents('₹ 42'), 4200);
      expect(CellValues.cents('n/a'), isNull);
    });
  });

  test('parses CSV with quotes, commas and semicolons', () {
    expect(parseCsv('﻿Date,Note,Amount\n2026-01-02,"Pizza, large",12.5\r\n'), [
      ['Date', 'Note', 'Amount'],
      ['2026-01-02', 'Pizza, large', '12.5'],
    ]);
    expect(parseCsv('Date;Amount\n2026-01-02;"say ""hi"""\n'), [
      ['Date', 'Amount'],
      ['2026-01-02', 'say "hi"'],
    ]);
  });

  group('sheet detection', () {
    test('finds headers below a title row', () {
      final mapping = ColumnMapping.detect(monthTab('jan', const []))!;
      expect(mapping.headerRow, 1);
      expect(mapping.columns, {
        ImportField.date: 0,
        ImportField.amount: 2,
        ImportField.category: 3,
        ImportField.note: 4,
      });
    });

    test('skips sheets without date and amount, and side tabs without categories', () {
      final choices = SheetChoice.detect([
        const RawSheet('tips', [
          ['TEMPLATE TIPS'],
        ]),
        monthTab('jan', const []),
        const RawSheet('Ledger', [
          ['Date', 'Amount', null, 'Description'],
        ]),
      ]);
      expect([for (final c in choices) c.mapping != null], [false, true, true]);
      expect([for (final c in choices) c.included], [false, true, false]);
    });
  });

  group('ImportPlanner', () {
    ImportPlan plan(
      List<RawSheet> sheets, {
      List<LedgerEntry> existing = const [],
      Map<String, Category> overrides = const {},
      bool includeDuplicates = false,
    }) => ImportPlanner.build(
      sheets: SheetChoice.detect(sheets),
      categories: defaultCategories,
      existing: existing,
      overrides: overrides,
      includeDuplicates: includeDuplicates,
    );

    final jan = monthTab('jan', [
      [jan1, null, 1166, 'Housing', null],
      [jan1 + 2, null, 17, 'food', 'Fruits'],
      [jan1 + 2, null, 17, 'Food ', 'Fruits'],
      [jan1 + 3, null, -500, 'Housing', 'Rent back'],
      [jan1 + 4, null, 2400, 'Investments', 'VOO'],
      [jan1 + 5, null, 30, 'Stocks', 'NVDA'],
      [jan1 + 6, null, 9, 'Common', 'Soap'],
      [jan1 + 7, null, 12, null, 'Snacks'],
      ['soon', null, 5, 'Food', 'Bad date'],
      [jan1 + 8, null, 'abc', 'Food', 'Bad amount'],
      [null, null, null, null, null],
    ]);

    test('reads rows, matches categories and reports problems', () {
      final p = plan([jan]);
      expect(p.entries.length, 8);
      expect(p.problems.map((x) => x.rowNumber), [11, 12]);
      expect(p.problems.first.reason, 'Unreadable date “soon”');

      final byLabel = {for (final g in p.groups) g.label: g};
      expect(byLabel['Food']!.target.id, 'food', reason: 'case and spaces ignored');
      expect(byLabel['Food']!.count, 2);
      expect(byLabel['Investments']!.target.id, 'investment', reason: 'plural matches');
      expect(byLabel['Stocks']!.isNew, isTrue);
      expect(byLabel['Stocks']!.target.kind, CategoryKind.investing);
      expect(byLabel['Common']!.target.kind, CategoryKind.spending);
      expect(byLabel['No category']!.target.id, 'misc');
      expect(p.newCategories.map((c) => c.name), unorderedEquals(['Stocks', 'Common']));

      final rentBack = p.entries.firstWhere((e) => e.note == 'Rent back');
      expect(rentBack.amountCents, -50000);
      expect(rentBack.isMoneyBack, isTrue);
    });

    test('keeps identical rows but never doubles them on a second import', () {
      final first = plan([jan]);
      final fruits = first.entries.where((e) => e.note == 'Fruits').toList();
      expect(fruits.length, 2);
      expect(fruits[0].id, isNot(fruits[1].id));
      expect(plan([jan]).entries.map((e) => e.id), first.entries.map((e) => e.id));

      final again = plan([jan], existing: first.entries);
      expect(again.entries, isEmpty);
      expect(again.duplicates, 8);
    });

    test('skips rows matching entries you logged yourself, unless asked', () {
      final mine = LedgerEntry(
        id: 'typed',
        amountCents: 116600,
        categoryId: 'housing',
        date: DateTime(2026),
      );
      expect(plan([jan], existing: [mine]).entries.length, 7);
      expect(plan([jan], existing: [mine]).duplicates, 1);
      expect(plan([jan], existing: [mine], includeDuplicates: true).entries.length, 8);
    });

    test('knows common names for the starter categories', () {
      final p = plan([
        const RawSheet('Sheet1', [
          ['Date', 'Amount', 'Category'],
          ['2026-03-01', 46, 'Groceries'],
          ['2026-03-02', 1100, 'Rent'],
          ['2026-03-03', 40, 'Utilities'],
          ['2026-03-04', 30, 'Gas'],
        ]),
      ]);
      expect(p.entries.map((e) => e.categoryId), ['food', 'housing', 'electricity', 'car']);
      expect(p.newCategories, isEmpty);
    });

    test('lets you send a category somewhere else', () {
      final housing = defaultCategories.firstWhere((c) => c.id == 'housing');
      final p = plan([jan], overrides: {'common': housing});
      expect(p.entries.firstWhere((e) => e.note == 'Soap').categoryId, 'housing');
      expect(p.newCategories.map((c) => c.name), ['Stocks']);
    });

    test('reads split columns', () {
      final p = plan([
        const RawSheet('Entries', [
          ['Date', 'Amount', 'Category', 'Description', 'Split ways', 'Split with'],
          ['2026-03-01', 90, 'Food', 'Pizza', 3, 'Sam, Ana'],
          ['2026-03-02', 40, 'Food', 'Lunch', null, 'Lee'],
        ]),
      ]);
      expect(p.entries[0].splitWays, 3);
      expect(p.entries[0].guestNames, ['Sam', 'Ana']);
      expect(p.entries[1].splitWays, 2, reason: 'a name means at least 2 ways');
    });

    test('months summarise your share', () {
      final p = plan([jan]);
      expect(p.months.single.count, 8);
      expect(p.firstDate, DateTime(2026));
      expect(p.lastDate, DateTime(2026, 1, 8));
    });
  });
}
