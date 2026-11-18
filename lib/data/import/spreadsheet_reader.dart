import 'dart:convert';
import 'dart:typed_data';

import 'package:spreadsheet_decoder/spreadsheet_decoder.dart';

import '../../domain/import/raw_sheet.dart';

/// Thrown when a file can't be read as a spreadsheet.
class SpreadsheetReadError implements Exception {
  const SpreadsheetReadError(this.message);

  final String message;

  @override
  String toString() => message;
}

/// File types the importer understands.
const importableExtensions = ['xlsx', 'csv', 'tsv', 'ods'];

/// Reads every sheet of an .xlsx or .ods file, or a .csv file, as plain
/// values. Runs fine in a background isolate.
List<RawSheet> readSpreadsheet(Uint8List bytes, String fileName) {
  final name = fileName.toLowerCase();
  if (name.endsWith('.xls')) {
    throw const SpreadsheetReadError(
      'Old .xls files aren’t supported. Open it and save a copy as .xlsx or .csv.',
    );
  }
  if (name.endsWith('.csv') || name.endsWith('.tsv') || name.endsWith('.txt')) {
    final text = utf8.decode(bytes, allowMalformed: true);
    final base = fileName.split('/').last;
    return [RawSheet(base.substring(0, base.lastIndexOf('.')), parseCsv(text))];
  }
  try {
    final book = SpreadsheetDecoder.decodeBytes(bytes);
    return [
      for (final MapEntry(key: sheetName, value: table) in book.tables.entries)
        RawSheet(sheetName, [
          for (final row in table.rows)
            [for (final v in row) v is String && v.trim().isEmpty ? null : v],
        ]),
    ];
  } on Object {
    throw const SpreadsheetReadError(
      'That file couldn’t be opened. Try saving it again as .xlsx or .csv.',
    );
  }
}
