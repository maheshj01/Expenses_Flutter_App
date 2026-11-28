import 'dart:math' as math;

import '../entities/category.dart';
import '../entities/ledger_entry.dart';

/// Totals for any period (a month, a year), split into the three buckets
/// the app is built around: what you spent, earned, and saved (earned minus
/// spent), plus how much of it you invested.
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

  /// Whether any income was logged. Without it, [savedCents] would just be
  /// spending with a minus sign, so screens show [investedCents] instead.
  bool get hasIncome => earnedCents > 0;

  /// What you didn't spend: earned minus spent. Negative when you spent
  /// more than you earned.
  ///
  /// Investing doesn't change it: money put into investments or a savings
  /// account is saved money that went somewhere, not spending.
  int get savedCents => earnedCents - livedCents;

  /// Saved as a share of what you earned, 0 to 1 (0 without income or when
  /// nothing was saved).
  double get savedShare =>
      !hasIncome || savedCents <= 0 ? 0 : (savedCents / earnedCents).clamp(0, 1).toDouble();

  /// The part of [savedCents] that wasn't invested. Never negative.
  int get cashCents => math.max(0, savedCents - investedCents);

  /// How much of what you invested came from savings made before this
  /// period, because you invested more than you saved in it.
  int get fromEarlierSavingsCents => math.max(0, investedCents - math.max(0, savedCents));

  /// Progress toward a savings goal: what you saved, or, with no income
  /// logged, what you invested.
  int get towardGoalCents => hasIncome ? savedCents : investedCents;

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
