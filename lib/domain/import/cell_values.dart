/// Reads dates and amounts the many ways spreadsheets store them.
abstract final class CellValues {
  static const _months = {
    'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6, //
    'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
  };

  static final _numeric = RegExp(r'^(\d{1,4})[/.\-](\d{1,2})[/.\-](\d{1,4})$');
  static final _named = RegExp(r'^(\d{1,2})?\s*([a-z]{3})[a-z]*\.?\s*(\d{1,2})?,?\s*(\d{2,4})$');

  /// A calendar date from a `DateTime`, an Excel serial day number, or text
  /// such as `2026-01-03`, `1/3/2026`, `3 Jan 2026` or `Jan 3, 2026`.
  ///
  /// [dayFirst] decides `3/1/2026`: 3 January when true, March 1 otherwise.
  static DateTime? date(Object? value, {bool dayFirst = false}) {
    if (value is DateTime) return DateTime(value.year, value.month, value.day);
    if (value is num) return _fromSerial(value);
    if (value is! String) return null;
    final text = value.trim().toLowerCase();
    if (text.isEmpty) return null;

    final serial = num.tryParse(text);
    if (serial != null) return _fromSerial(serial);

    final m = _numeric.firstMatch(text);
    if (m != null) {
      final a = int.parse(m.group(1)!), b = int.parse(m.group(2)!), c = int.parse(m.group(3)!);
      if (m.group(1)!.length == 4) return _make(a, b, c);
      final year = c < 100 ? 2000 + c : c;
      final (month, day) = dayFirst || a > 12 ? (b, a) : (a, b);
      return _make(year, month, day);
    }

    final n = _named.firstMatch(text);
    if (n != null) {
      final month = _months[n.group(2)];
      final day = int.tryParse(n.group(1) ?? n.group(3) ?? '');
      final y = int.parse(n.group(4)!);
      if (month != null && day != null) return _make(y < 100 ? 2000 + y : y, month, day);
    }

    final parsed = DateTime.tryParse(value.trim());
    return parsed == null ? null : DateTime(parsed.year, parsed.month, parsed.day);
  }

  /// True when [value] can only be read day-first, like `25/12/2026`.
  static bool looksDayFirst(Object? value) {
    if (value is! String) return false;
    final m = _numeric.firstMatch(value.trim());
    return m != null && m.group(1)!.length < 4 && int.parse(m.group(1)!) > 12;
  }

  /// Excel counts days from 1899-12-30. Only plausible dates are accepted.
  static DateTime? _fromSerial(num serial) {
    if (serial < 20000 || serial > 80000) return null;
    final d = DateTime.utc(1899, 12, 30).add(Duration(days: serial.floor()));
    return DateTime(d.year, d.month, d.day);
  }

  static DateTime? _make(int year, int month, int day) {
    if (month < 1 || month > 12 || day < 1 || day > 31 || year < 1950 || year > 2200) return null;
    final d = DateTime(year, month, day);
    return d.month == month ? d : null;
  }

  /// An amount in cents from a number or text such as `$1,166.50`,
  /// `(12.00)`, `-500` or `1.234,56`. Null when it isn't a number.
  static int? cents(Object? value) {
    if (value is num) return (value * 100).round();
    if (value is! String) return null;
    var text = value.trim();
    if (text.isEmpty) return null;
    var negative = false;
    if (text.startsWith('(') && text.endsWith(')')) {
      negative = true;
      text = text.substring(1, text.length - 1);
    }
    text = text.replaceAll(RegExp(r'[^\d.,\-]'), '');
    if (text.startsWith('-') || text.endsWith('-')) {
      negative = !negative;
      text = text.replaceAll('-', '');
    }
    if (RegExp(r'^\d{1,3}(\.\d{3})*,\d{1,2}$').hasMatch(text)) {
      text = text.replaceAll('.', '').replaceAll(',', '.'); // 1.234,56
    } else {
      text = text.replaceAll(',', '');
    }
    final number = double.tryParse(text);
    if (number == null) return null;
    final c = (number * 100).round();
    return negative ? -c : c;
  }
}
