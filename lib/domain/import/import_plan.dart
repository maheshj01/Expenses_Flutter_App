import '../../core/day.dart';
import '../../core/year_month.dart';
import '../entities/category.dart';
import '../entities/ledger_entry.dart';
import 'cell_values.dart';
import 'column_mapping.dart';
import 'raw_sheet.dart';

/// One row read from a spreadsheet.
class ImportRow {
  const ImportRow({
    required this.sheet,
    required this.rowNumber,
    required this.date,
    required this.cents,
    this.category = '',
    this.note = '',
    this.splitWays = 1,
    this.splitWith = const [],
  });

  final String sheet;

  /// 1-based, as shown in spreadsheet apps.
  final int rowNumber;
  final DateTime date;

  /// Full amount. Negative means money back.
  final int cents;
  final String category;
  final String note;
  final int splitWays;
  final List<String> splitWith;
}

/// A row that has data but couldn't be read.
class ImportProblem {
  const ImportProblem(this.sheet, this.rowNumber, this.reason);

  final String sheet;
  final int rowNumber;
  final String reason;
}

/// A sheet found in the file, and whether to import it.
class SheetChoice {
  const SheetChoice({required this.sheet, required this.mapping, required this.included});

  final RawSheet sheet;

  /// Null when no header row with a date and an amount was found.
  final ColumnMapping? mapping;
  final bool included;

  SheetChoice copyWith({ColumnMapping? mapping, bool? included}) => SheetChoice(
    sheet: sheet,
    mapping: mapping ?? this.mapping,
    included: included ?? this.included,
  );

  /// Sheets with both a date and an amount column. When some of them also
  /// have a category column, only those are picked at first: the others
  /// tend to be loans or notes kept on the side.
  static List<SheetChoice> detect(List<RawSheet> sheets) {
    final found = [for (final s in sheets) (s, ColumnMapping.detect(s))];
    final anyCategorised = found.any(
      (f) => f.$2?.columns.containsKey(ImportField.category) ?? false,
    );
    return [
      for (final (sheet, mapping) in found)
        SheetChoice(
          sheet: sheet,
          mapping: mapping,
          included:
              mapping != null &&
              (!anyCategorised || mapping.columns.containsKey(ImportField.category)),
        ),
    ];
  }
}

/// Rows read from one sheet.
({List<ImportRow> rows, List<ImportProblem> problems}) readSheet(
  RawSheet sheet,
  ColumnMapping mapping,
) {
  final cols = mapping.columns;
  Object? at(int r, ImportField f) => cols[f] == null ? null : sheet.cell(r, cols[f]!);
  String text(int r, ImportField f) {
    final v = at(r, f);
    if (v == null) return '';
    if (v is double && v == v.roundToDouble()) return v.toInt().toString();
    return v.toString().trim();
  }

  final first = mapping.headerRow + 1;
  final dayFirst = [for (var r = first; r < sheet.rows.length; r++) at(r, ImportField.date)]
      .any(CellValues.looksDayFirst);

  final rows = <ImportRow>[];
  final problems = <ImportProblem>[];
  for (var r = first; r < sheet.rows.length; r++) {
    final rawDate = at(r, ImportField.date);
    final rawAmount = at(r, ImportField.amount);
    final hasDate = rawDate != null && rawDate.toString().trim().isNotEmpty;
    final hasAmount = rawAmount != null && rawAmount.toString().trim().isNotEmpty;
    if (!hasDate && !hasAmount) continue;
    if (!hasDate && _isTotalRow(sheet.rows[r])) continue;

    final date = CellValues.date(rawDate, dayFirst: dayFirst);
    final cents = CellValues.cents(rawAmount);
    if (date == null && _isTotalRow(sheet.rows[r])) continue;
    if (date == null) {
      problems.add(
        ImportProblem(sheet.name, r + 1, hasDate ? 'Unreadable date “$rawDate”' : 'No date'),
      );
      continue;
    }
    if (cents == null) {
      problems.add(
        ImportProblem(
          sheet.name,
          r + 1,
          hasAmount ? 'Unreadable amount “$rawAmount”' : 'No amount',
        ),
      );
      continue;
    }
    if (cents == 0) continue;

    final names = [
      for (final n in text(r, ImportField.splitWith).split(RegExp(r',|;|\band\b|&')))
        if (n.trim().isNotEmpty) n.trim(),
    ];
    var ways = int.tryParse(text(r, ImportField.splitWays)) ?? 1;
    if (ways < 1) ways = 1;
    if (ways < names.length + 1 && names.isNotEmpty) ways = names.length + 1;

    rows.add(
      ImportRow(
        sheet: sheet.name,
        rowNumber: r + 1,
        date: date,
        cents: cents,
        category: text(r, ImportField.category),
        note: text(r, ImportField.note),
        splitWays: ways > 99 ? 99 : ways,
        splitWith: names,
      ),
    );
  }
  return (rows: rows, problems: problems);
}

bool _isTotalRow(List<Object?> row) => row.any(
  (v) => const {'total', 'totals', 'subtotal', 'grandtotal', 'sum'}.contains(normaliseHeader(v)),
);

/// Rows that share a category name in the file, and where they go.
class CategoryGroup {
  const CategoryGroup({
    required this.key,
    required this.label,
    required this.count,
    required this.cents,
    required this.target,
    required this.isNew,
  });

  /// The name in the file, normalised. Empty for rows without a category.
  final String key;

  /// The name as written most often in the file.
  final String label;
  final int count;
  final int cents;

  /// An existing category, or one that will be created.
  final Category target;
  final bool isNew;
}

class MonthTotal {
  const MonthTotal(this.month, this.count, this.cents);

  final YearMonth month;
  final int count;

  /// Sum of your shares.
  final int cents;
}

/// What an import will do, worked out before anything is saved.
class ImportPlan {
  const ImportPlan({
    required this.rows,
    required this.problems,
    required this.groups,
    required this.entries,
    required this.duplicates,
    required this.months,
  });

  final List<ImportRow> rows;
  final List<ImportProblem> problems;
  final List<CategoryGroup> groups;

  /// Entries to save, duplicates left out unless asked for.
  final List<LedgerEntry> entries;

  /// Rows matching an entry you already have (same day and amount).
  final int duplicates;
  final List<MonthTotal> months;

  List<Category> get newCategories => [
    for (final g in groups)
      if (g.isNew) g.target,
  ];

  /// Existing categories that are archived but get entries again.
  List<String> get categoriesToRestore => {
    for (final g in groups)
      if (!g.isNew && g.target.archived) g.target.id,
  }.toList();

  DateTime? get firstDate => entries.isEmpty ? null : entries.map((e) => e.date).reduce(_min);

  DateTime? get lastDate => entries.isEmpty ? null : entries.map((e) => e.date).reduce(_max);

  static DateTime _min(DateTime a, DateTime b) => a.isBefore(b) ? a : b;

  static DateTime _max(DateTime a, DateTime b) => a.isAfter(b) ? a : b;
}

/// Turns spreadsheet rows into entries: matches categories, spots rows you
/// already have, and gives every row a stable id so importing the same
/// file twice never doubles anything.
abstract final class ImportPlanner {
  static ImportPlan build({
    required List<SheetChoice> sheets,
    required List<Category> categories,
    required List<LedgerEntry> existing,
    Map<String, Category> overrides = const {},
    bool includeDuplicates = false,
  }) {
    final rows = <ImportRow>[];
    final problems = <ImportProblem>[];
    for (final s in sheets) {
      if (!s.included || s.mapping == null) continue;
      final read = readSheet(s.sheet, s.mapping!);
      rows.addAll(read.rows);
      problems.addAll(read.problems);
    }
    rows.sort((a, b) => a.date.compareTo(b.date));

    // Group by category name.
    final spellings = <String, Map<String, int>>{};
    final counts = <String, int>{}, totals = <String, int>{};
    for (final r in rows) {
      final key = categoryKey(r.category);
      spellings
          .putIfAbsent(key, () => {})
          .update(r.category.trim(), (v) => v + 1, ifAbsent: () => 1);
      counts.update(key, (v) => v + 1, ifAbsent: () => 1);
      totals.update(key, (v) => v + r.cents, ifAbsent: () => r.cents);
    }

    final groups = <CategoryGroup>[];
    for (final key in counts.keys) {
      final label = key.isEmpty ? 'No category' : _bestSpelling(spellings[key]!);
      final override = overrides[key];
      final existingMatch = override ?? matchCategory(key, categories);
      final target =
          existingMatch ?? newCategoryFor(key.isEmpty ? 'Misc' : label, categories.length);
      groups.add(
        CategoryGroup(
          key: key,
          label: label,
          count: counts[key]!,
          cents: totals[key]!,
          target: target,
          isNew: !categories.any((c) => c.id == target.id),
        ),
      );
    }
    groups.sort((a, b) => b.count.compareTo(a.count));
    final targetOf = {for (final g in groups) g.key: g.target.id};

    // Each existing (day, amount) can absorb one imported row.
    final have = <(int, int), int>{};
    for (final e in existing) {
      have.update((DayKey.fromDate(e.date), e.amountCents), (v) => v + 1, ifAbsent: () => 1);
    }

    final seen = <String, int>{};
    final entries = <LedgerEntry>[];
    var duplicates = 0;
    final byMonth = <YearMonth, (int, int)>{};
    for (final r in rows) {
      final day = DayKey.fromDate(r.date);
      final base = '$day|${r.cents}|${r.note.toLowerCase()}|${categoryKey(r.category)}';
      final n = seen.update(base, (v) => v + 1, ifAbsent: () => 0);
      final slot = (day, r.cents);
      if ((have[slot] ?? 0) > 0) {
        have[slot] = have[slot]! - 1;
        duplicates++;
        if (!includeDuplicates) continue;
      }
      final entry = LedgerEntry(
        id: 'imp_${_hash('$base|$n')}',
        amountCents: r.cents,
        categoryId: targetOf[categoryKey(r.category)]!,
        date: r.date,
        note: r.note,
        splitWays: r.splitWays,
        guestNames: r.splitWith,
      );
      entries.add(entry);
      final m = YearMonth(r.date.year, r.date.month);
      final (c, sum) = byMonth[m] ?? (0, 0);
      byMonth[m] = (c + 1, sum + entry.shareCents);
    }

    return ImportPlan(
      rows: rows,
      problems: problems,
      groups: groups,
      entries: entries,
      duplicates: duplicates,
      months: [
        for (final MapEntry(key: m, value: (c, sum)) in byMonth.entries) MonthTotal(m, c, sum),
      ]..sort((a, b) => a.month.compareTo(b.month)),
    );
  }

  /// The spelling used most, preferring a capitalised one on a tie.
  static String _bestSpelling(Map<String, int> counts) {
    int score(MapEntry<String, int> e) =>
        e.value * 2 + (e.key.isNotEmpty && e.key[0] != e.key[0].toLowerCase() ? 1 : 0);
    return counts.entries.reduce((a, b) => score(b) > score(a) ? b : a).key;
  }

  /// "Groceries ", "groceries" and "Grocery" group together: lowercase,
  /// single spaces, without a plural s.
  static String categoryKey(String name) {
    final key = name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    return key.length > 3 && key.endsWith('s') && !key.endsWith('ss')
        ? key.substring(0, key.length - 1)
        : key;
  }

  /// An existing category with the same name, ignoring case and a plural s.
  static Category? matchCategory(String key, List<Category> categories) {
    if (key.isEmpty) {
      return categories.where((c) => c.id == 'misc').firstOrNull;
    }
    for (final c in categories) {
      if (categoryKey(c.name) == key) return c;
    }
    for (final MapEntry(key: pattern, value: id) in _synonyms.entries) {
      if (!RegExp(pattern).hasMatch(key)) continue;
      final match = categories.where((c) => c.id == id).firstOrNull;
      if (match != null) return match;
    }
    return null;
  }

  /// Common names for the starter categories, matched against [categoryKey].
  static const _synonyms = <String, String>{
    r'^grocer': 'food',
    r'^(rent|mortgage|home|house)$': 'housing',
    r'^(utilit|power|electric|gas & electric)': 'electricity',
    r'^(gas|fuel|petrol|auto|transport|transportation)$': 'car',
    r'^(health|doctor|pharmacy|medicine|healthcare)$': 'medical',
    r'^(cloth|clothing|apparel)': 'shopping',
    r'^(gadget|tech)': 'electronics',
    r'^(paycheck|income|wage|payroll)$': 'salary',
    r'^(vacation|trip|flight)$': 'travel',
    r'^(other|miscellaneou|general)$': 'misc',
  };

  /// A new category for [name], with a kind, emoji and colour guessed from it.
  static Category newCategoryFor(String name, int sortOrder) {
    final key = categoryKey(name);
    final slug = key.replaceAll(RegExp('[^a-z0-9]+'), '_').replaceAll(RegExp(r'^_|_$'), '');
    final title = name.trim().isEmpty
        ? 'Misc'
        : name.trim()[0].toUpperCase() + name.trim().substring(1);
    return Category(
      id: 'imp_${slug.isEmpty ? _hash(key) : slug}',
      name: title,
      emoji: _emojiFor(key),
      color: _palette[_hash(key).codeUnits.fold(0, (a, b) => a + b) % _palette.length],
      kind: _kindFor(key),
      sortOrder: sortOrder,
    );
  }

  static CategoryKind _kindFor(String key) {
    if (RegExp(
      r'invest|saving|emergency fund|fixed deposit|stock|share|crypto|401k|\bira\b|brokerage|etf|mutual|\bsip\b|retire',
    ).hasMatch(key)) {
      return CategoryKind.investing;
    }
    if (RegExp(r'salary|income|paycheck|payroll|wage|bonus|dividend|interest earned')
        .hasMatch(key)) {
      return CategoryKind.income;
    }
    return CategoryKind.spending;
  }

  static const _emojis = <String, String>{
    'rent|hous|home|mortgage': '🏠',
    'grocer|food': '🛒',
    'eat|restaurant|dining|takeout|coffee|cafe': '🍔',
    'fuel|gas|car|auto|parking|uber|lyft|taxi|transport|transit': '🚗',
    'travel|flight|hotel|trip|vacation': '✈️',
    'health|medic|doctor|pharma|dental': '💊',
    'gift|donation|charity': '🎁',
    'electric|utilit|water|power': '⚡',
    'phone|internet|wifi|mobile|productiv': '📱',
    'shop|cloth|amazon': '🛍️',
    'entertain|movie|netflix|game|fun': '🎬',
    'subscri|stream': '📺',
    'educat|school|course|book|tuition': '🎓',
    'pet|dog|cat': '🐶',
    'kid|child|baby': '🧸',
    'insur': '🛡️',
    'gym|fitness|sport': '🏋️',
    'electronic|gadget|tech': '💻',
    'saving|emergency fund|deposit': '🐷',
    'invest|stock|crypto|retire': '📈',
    'salary|income|pay|bonus': '💼',
    'loan|debt|credit': '💳',
  };

  static String _emojiFor(String key) {
    for (final MapEntry(key: pattern, value: emoji) in _emojis.entries) {
      if (RegExp(pattern).hasMatch(key)) return emoji;
    }
    return '🏷️';
  }

  static const _palette = [
    0xFFE8F3E4, 0xFFEDE9FB, 0xFFFFF4D6, 0xFFE3EEFB, 0xFFE6F4F3, 0xFFFBE7EE, //
    0xFFE9F6EA, 0xFFF3E9FA, 0xFFE4F1FA, 0xFFFBEAEA, 0xFFE6ECF5, 0xFFFBF0DC,
  ];

  /// FNV-1a, 32-bit twice over, as 16 hex characters. Stable everywhere.
  static String _hash(String s) {
    var a = 0x811c9dc5, b = 0x050c5d1f;
    for (final c in s.codeUnits) {
      a = ((a ^ c) * 0x01000193) & 0xFFFFFFFF;
      b = ((b ^ c) * 0x01000193 + 7) & 0xFFFFFFFF;
    }
    return a.toRadixString(16).padLeft(8, '0') + b.toRadixString(16).padLeft(8, '0');
  }
}
