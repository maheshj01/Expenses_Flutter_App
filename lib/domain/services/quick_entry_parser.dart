import '../entities/ledger_entry.dart';

/// Result of parsing free text such as `costco 46.50 split`.
class QuickEntry {
  const QuickEntry({
    this.amountCents,
    this.note = '',
    this.splitWays = 1,
    this.guestNames = const [],
    this.moneyBack = false,
  });

  final int? amountCents;
  final String note;
  final int splitWays;

  /// Saved people named in a split, e.g. "Sam" in `pizza 30 split sam`.
  final List<String> guestNames;
  final bool moneyBack;
}

/// Turns a one-line note into an amount, a note and options, so adding an
/// expense can be as quick as typing `kroger 18`.
///
/// Supported words: `split` / `half` (split 2 ways), `split 3` or `/3`
/// (split 3 ways), and `refund` / `back` / a leading `+` (money back).
/// With a split, any of [knownNames] in the text are taken as the people
/// sharing it: `pizza 30 split with sam and ana` is split 3 ways.
abstract final class QuickEntryParser {
  static final _amount = RegExp(r'(?<![\w/])[+$]?(\d{1,7}(?:[.,]\d{1,2})?)(?![\w/])');
  static final _splitN = RegExp(r'\b(?:split|÷)\s*(\d)\b|/(\d)\b');
  static final _split2 = RegExp(r'\b(split|half|½)\b');
  static final _back = RegExp(r'\b(refund|refunded|back|returned)\b');

  static QuickEntry parse(String input, {Iterable<String> knownNames = const []}) {
    var text = input.trim();
    if (text.isEmpty) return const QuickEntry();

    var splitWays = 1;
    final n = _splitN.firstMatch(text);
    if (n != null) {
      final ways = int.parse(n.group(1) ?? n.group(2)!);
      if (ways >= 2) splitWays = ways;
      text = text.replaceRange(n.start, n.end, ' ');
    } else if (_split2.hasMatch(text)) {
      splitWays = 2;
      text = text.replaceAll(_split2, ' ');
    }

    final names = <String>[];
    if (splitWays > 1) {
      for (final name in knownNames) {
        if (name.trim().isEmpty) continue;
        final word = RegExp(
          '(?<![\\w])${RegExp.escape(name.trim())}(?![\\w])',
          caseSensitive: false,
        );
        if (!word.hasMatch(text)) continue;
        names.add(name.trim());
        text = text.replaceAll(word, ' ');
      }
      if (names.isNotEmpty) {
        text = text.replaceAll(RegExp(r'\b(?:with|and)\b|&', caseSensitive: false), ' ');
        if (names.length + 1 > splitWays) splitWays = names.length + 1;
      }
    }

    final moneyBack = text.startsWith('+') || _back.hasMatch(text);

    int? cents;
    final m = _amount.firstMatch(text);
    if (m != null) {
      final value = double.parse(m.group(1)!.replaceAll(',', '.'));
      cents = (value * 100).round();
      text = text.replaceRange(m.start, m.end, ' ');
    }

    final note = text.replaceAll('+', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    return QuickEntry(
      amountCents: cents,
      note: note.isEmpty ? '' : note[0].toUpperCase() + note.substring(1),
      splitWays: splitWays,
      guestNames: names,
      moneyBack: moneyBack,
    );
  }
}

class CategorySuggestion {
  const CategorySuggestion(this.categoryId, this.matchedWord, this.timesUsed);

  final String categoryId;
  final String matchedWord;
  final int timesUsed;
}

/// Learns which words in your notes map to which category, from your own
/// history ("kroger" -> Food), and suggests a category for new text.
class CategorySuggester {
  CategorySuggester(Iterable<LedgerEntry> history) {
    for (final e in history) {
      for (final word in _words(e.note)) {
        final perCategory = _counts.putIfAbsent(word, () => {});
        perCategory.update(e.categoryId, (v) => v + 1, ifAbsent: () => 1);
      }
    }
  }

  final Map<String, Map<String, int>> _counts = {};

  static Iterable<String> _words(String text) => text
      .toLowerCase()
      .split(RegExp(r"[^a-z0-9']+"))
      .map((w) => w.replaceAll("'", ''))
      .where((w) => w.length >= 3 && int.tryParse(w) == null);

  CategorySuggestion? suggest(String text, {Set<String>? allowedIds}) {
    CategorySuggestion? best;
    for (final word in _words(text)) {
      final perCategory = _counts[word];
      if (perCategory == null) continue;
      for (final MapEntry(key: id, value: count) in perCategory.entries) {
        if (allowedIds != null && !allowedIds.contains(id)) continue;
        if (best == null || count > best.timesUsed) {
          best = CategorySuggestion(id, word, count);
        }
      }
    }
    return best;
  }
}
