import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../../domain/entities/category.dart';
import '../../domain/entities/ledger_entry.dart';

/// Everything that goes into an export.
class ExportData {
  const ExportData({required this.entries, required this.categories, required this.label});

  final List<LedgerEntry> entries;
  final List<Category> categories;

  /// What the export covers, e.g. "2026" or "All years". Used in titles.
  final String label;
}

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Builds an .xlsx workbook: an "Entries" sheet with one row per entry
/// (which Three Bucks can import again) and a "Summary" sheet per year with
/// what you spent, invested and earned per category and month.
///
/// Pure Dart, so it can run in a background isolate.
Uint8List buildExportWorkbook(ExportData data) {
  final book = Excel.createExcel();
  final defaultSheet = book.getDefaultSheet()!;
  final byId = {for (final c in data.categories) c.id: c};
  final entries = [...data.entries]
    ..sort((a, b) {
      final byDate = a.date.compareTo(b.date);
      return byDate != 0 ? byDate : (a.createdAt ?? a.date).compareTo(b.createdAt ?? b.date);
    });

  final bold = CellStyle(bold: true);
  final money = CellStyle(numberFormat: NumFormat.standard_4); // #,##0.00
  final moneyBold = CellStyle(bold: true, numberFormat: NumFormat.standard_4);
  final date = CellStyle(numberFormat: const CustomDateTimeNumFormat(formatCode: 'yyyy-mm-dd'));

  // ---- Entries ----
  final sheet = book['Entries'];
  const headers = [
    'Date',
    'Amount',
    'Your share',
    'Category',
    'Kind',
    'Description',
    'Split ways',
    'Split with',
    'Shared bill',
  ];
  for (final (c, h) in headers.indexed) {
    sheet.updateCell(_at(c, 0), TextCellValue(h), cellStyle: bold);
  }
  for (final (i, e) in entries.indexed) {
    final r = i + 1;
    final cat = byId[e.categoryId];
    sheet
      ..updateCell(
        _at(0, r),
        DateCellValue(year: e.date.year, month: e.date.month, day: e.date.day),
        cellStyle: date,
      )
      ..updateCell(_at(1, r), DoubleCellValue(e.amountCents / 100), cellStyle: money)
      ..updateCell(_at(2, r), DoubleCellValue(e.shareCents / 100), cellStyle: money)
      ..updateCell(_at(3, r), TextCellValue(cat?.name ?? 'Uncategorised'))
      ..updateCell(_at(4, r), TextCellValue(_kindLabel(cat?.kind ?? CategoryKind.spending)))
      ..updateCell(_at(5, r), TextCellValue(e.note))
      ..updateCell(_at(6, r), IntCellValue(e.splitWays))
      ..updateCell(_at(7, r), TextCellValue(e.guestNames.join(', ')))
      ..updateCell(_at(8, r), TextCellValue(e.isShared ? 'Yes' : ''));
  }
  for (final (c, w) in [12.0, 12.0, 12.0, 18.0, 11.0, 36.0, 10.0, 18.0, 11.0].indexed) {
    sheet.setColumnWidth(c, w);
  }

  // ---- One summary per year, newest first ----
  final years = {for (final e in entries) e.date.year}.toList()..sort((a, b) => b.compareTo(a));
  for (final year in years) {
    final s = book['Summary $year'];
    s.updateCell(
      _at(0, 0),
      TextCellValue('${data.label == '$year' ? '' : '$year · '}Your share by month'),
      cellStyle: bold,
    );
    var row = 2;
    for (final kind in CategoryKind.values) {
      final totals = <String, List<int>>{};
      for (final e in entries) {
        if (e.date.year != year) continue;
        final cat = byId[e.categoryId];
        if ((cat?.kind ?? CategoryKind.spending) != kind) continue;
        totals.putIfAbsent(e.categoryId, () => List.filled(12, 0))[e.date.month - 1] +=
            e.shareCents;
      }
      if (totals.isEmpty) continue;

      s.updateCell(_at(0, row), TextCellValue(_kindLabel(kind)), cellStyle: bold);
      for (final (m, name) in _months.indexed) {
        s.updateCell(_at(m + 1, row), TextCellValue(name), cellStyle: bold);
      }
      s.updateCell(_at(13, row), TextCellValue('Total'), cellStyle: bold);
      row++;

      final ids = totals.keys.toList()
        ..sort((a, b) => (byId[a]?.sortOrder ?? 999).compareTo(byId[b]?.sortOrder ?? 999));
      final sums = List.filled(12, 0);
      for (final id in ids) {
        final months = totals[id]!;
        s.updateCell(_at(0, row), TextCellValue(byId[id]?.name ?? 'Uncategorised'));
        for (var m = 0; m < 12; m++) {
          s.updateCell(_at(m + 1, row), DoubleCellValue(months[m] / 100), cellStyle: money);
          sums[m] += months[m];
        }
        s.updateCell(
          _at(13, row),
          DoubleCellValue(months.fold(0, (a, b) => a + b) / 100),
          cellStyle: moneyBold,
        );
        row++;
      }
      s.updateCell(_at(0, row), TextCellValue('${_kindLabel(kind)} total'), cellStyle: bold);
      for (var m = 0; m < 12; m++) {
        s.updateCell(_at(m + 1, row), DoubleCellValue(sums[m] / 100), cellStyle: moneyBold);
      }
      s.updateCell(
        _at(13, row),
        DoubleCellValue(sums.fold(0, (a, b) => a + b) / 100),
        cellStyle: moneyBold,
      );
      row += 2;
    }
    s.setColumnWidth(0, 20);
    for (var c = 1; c <= 13; c++) {
      s.setColumnWidth(c, 11);
    }
  }

  book.setDefaultSheet('Entries');
  book.delete(defaultSheet);
  return Uint8List.fromList(book.encode()!);
}

String _kindLabel(CategoryKind kind) => switch (kind) {
  CategoryKind.spending => 'Lived',
  CategoryKind.investing => 'Invested',
  CategoryKind.income => 'Earned',
};

CellIndex _at(int column, int row) =>
    CellIndex.indexByColumnRow(columnIndex: column, rowIndex: row);

/// File name for an export, e.g. `three-bucks-2026.xlsx`.
String exportFileName(String label) =>
    'three-bucks-${label.toLowerCase().replaceAll(RegExp('[^a-z0-9]+'), '-')}.xlsx';
