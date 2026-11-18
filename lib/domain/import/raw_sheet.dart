/// One sheet of a spreadsheet, or a CSV file, as a grid of plain values:
/// `String`, `num`, `bool`, `DateTime` or `null`.
class RawSheet {
  const RawSheet(this.name, this.rows);

  final String name;
  final List<List<Object?>> rows;

  Object? cell(int row, int column) {
    if (row < 0 || row >= rows.length) return null;
    final r = rows[row];
    return column >= 0 && column < r.length ? r[column] : null;
  }
}

/// Splits CSV text into rows (RFC 4180: quoted fields, doubled quotes,
/// line breaks inside quotes). Detects `;` or tab separated files too.
List<List<Object?>> parseCsv(String text) {
  if (text.startsWith('﻿')) text = text.substring(1);
  final firstLine = text.split('\n').first;
  final separator = [
    ',',
    ';',
    '\t',
  ].reduce((a, b) => firstLine.split(b).length > firstLine.split(a).length ? b : a);

  final rows = <List<Object?>>[];
  var row = <Object?>[];
  final field = StringBuffer();
  var quoted = false;

  void endField() {
    final value = field.toString();
    row.add(value.isEmpty ? null : value);
    field.clear();
  }

  void endRow() {
    endField();
    if (row.any((v) => v != null)) rows.add(row);
    row = <Object?>[];
  }

  for (var i = 0; i < text.length; i++) {
    final ch = text[i];
    if (quoted) {
      if (ch == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          quoted = false;
        }
      } else {
        field.write(ch);
      }
    } else if (ch == '"' && field.isEmpty) {
      quoted = true;
    } else if (ch == separator) {
      endField();
    } else if (ch == '\n') {
      endRow();
    } else if (ch != '\r') {
      field.write(ch);
    }
  }
  if (field.isNotEmpty || row.isNotEmpty) endRow();
  return rows;
}
