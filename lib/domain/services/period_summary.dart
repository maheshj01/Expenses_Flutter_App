import '../entities/category.dart';
import '../entities/ledger_entry.dart';

/// Totals for any period (a month, a year), split into the three buckets
/// the app is built around: what you lived on, invested, and earned.
class PeriodSummary {
  const PeriodSummary({
    this.livedCents = 0,
    this.investedCents = 0,
    this.earnedCents = 0,
    this.byCategory = const {},
    this.entryCount = 0,
  });

  factory PeriodSummary.of(Iterable<LedgerEntry> entries, Map<String, Category> categories) {
    var lived = 0, invested = 0, earned = 0, count = 0;
    final byCategory = <String, int>{};
    for (final e in entries) {
      count++;
      final share = e.shareCents;
      byCategory.update(e.categoryId, (v) => v + share, ifAbsent: () => share);
      switch (categories[e.categoryId]?.kind ?? CategoryKind.spending) {
        case CategoryKind.spending:
          lived += share;
        case CategoryKind.investing:
          invested += share;
        case CategoryKind.income:
          earned += share;
      }
    }
    return PeriodSummary(
      livedCents: lived,
      investedCents: invested,
      earnedCents: earned,
      byCategory: byCategory,
      entryCount: count,
    );
  }

  static const empty = PeriodSummary();

  final int livedCents;
  final int investedCents;
  final int earnedCents;

  /// Your share per category id, in cents.
  final Map<String, int> byCategory;
  final int entryCount;

  /// Earned minus lived minus invested. Can be negative when you invest
  /// from savings; that is not overspending.
  int get keptCents => earnedCents - livedCents - investedCents;

  /// Category ids of [kind], biggest first.
  List<MapEntry<String, int>> ranked(Map<String, Category> categories, CategoryKind kind) {
    final list =
        byCategory.entries
            .where(
              (e) => (categories[e.key]?.kind ?? CategoryKind.spending) == kind && e.value != 0,
            )
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));
    return list;
  }
}

/// How much of the monthly living budget can be spent per remaining day.
class BudgetPace {
  const BudgetPace({required this.budgetCents, required this.livedCents, required this.daysLeft});

  /// [today] must fall within the month described by [daysInMonth].
  factory BudgetPace.forMonth({
    required int budgetCents,
    required int livedCents,
    required DateTime today,
    required int daysInMonth,
  }) {
    return BudgetPace(
      budgetCents: budgetCents,
      livedCents: livedCents,
      daysLeft: daysInMonth - today.day + 1,
    );
  }

  final int budgetCents;
  final int livedCents;

  /// Days left including today.
  final int daysLeft;

  int get remainingCents => budgetCents - livedCents;

  bool get isOver => remainingCents < 0;

  double get usedFraction =>
      budgetCents <= 0 ? 0 : (livedCents / budgetCents).clamp(0, 1).toDouble();

  int get safePerDayCents => (isOver || daysLeft <= 0) ? 0 : remainingCents ~/ daysLeft;
}
