import 'raw_sheet.dart';

/// What a spreadsheet column holds.
enum ImportField {
  date('Date', required: true),
  amount('Amount', required: true),
  category('Category'),
  note('Description'),
  splitWays('Split ways'),
  splitWith('Split with');

  const ImportField(this.label, {this.required = false});

  final String label;
  final bool required;

  /// Header words that point at this field, normalised (lowercase letters
  /// and digits only). Checked in order, so exact names win.
  List<String> get headerNames => switch (this) {
    date => const ['date', 'day', 'transactiondate', 'posteddate', 'postingdate', 'txndate'],
    amount => const ['amount', 'cost', 'price', 'value', 'debit', 'spent', 'total', 'expense'],
    category => const ['category', 'categories', 'group', 'expensetype', 'expensecategory'],
    note => const [
      'description',
      'note',
      'notes',
      'memo',
      'details',
      'item',
      'merchant',
      'payee',
      'narration',
      'name',
    ],
    splitWays => const ['splitways', 'ways'],
    splitWith => const ['splitwith', 'sharedwith'],
  };
}

String normaliseHeader(Object? value) =>
    value is String ? value.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '') : '';

/// Where the header row is and which column holds each field.
class ColumnMapping {
  const ColumnMapping({required this.headerRow, required this.columns});

  /// Zero-based index of the header row. Data starts on the next row.
  final int headerRow;
  final Map<ImportField, int> columns;

  bool get isUsable =>
      columns.containsKey(ImportField.date) && columns.containsKey(ImportField.amount);

  ColumnMapping withColumn(ImportField field, int? column) {
    final next = {...columns}..remove(field);
    if (column != null) {
      next.removeWhere((_, c) => c == column);
      next[field] = column;
    }
    return ColumnMapping(headerRow: headerRow, columns: next);
  }

  /// Finds the header row in the first rows of [sheet] and guesses the
  /// columns. Returns null when no row names both a date and an amount.
  static ColumnMapping? detect(RawSheet sheet) {
    final limit = sheet.rows.length < 15 ? sheet.rows.length : 15;
    for (var r = 0; r < limit; r++) {
      final headers = [for (final v in sheet.rows[r]) normaliseHeader(v)];
      final columns = <ImportField, int>{};
      for (final field in ImportField.values) {
        for (final name in field.headerNames) {
          final c = headers.indexOf(name);
          if (c >= 0 && !columns.containsValue(c)) {
            columns[field] = c;
            break;
          }
        }
      }
      final mapping = ColumnMapping(headerRow: r, columns: columns);
      if (mapping.isUsable) return mapping;
    }
    return null;
  }
}
