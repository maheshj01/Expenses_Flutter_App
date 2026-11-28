import '../entities/app_settings.dart';

/// The user's intended month: what comes in, what they live on, what they
/// set aside, and what is left unplanned.
class MonthlyPlan {
  const MonthlyPlan({
    required this.incomeCents,
    required this.spendingCents,
    required this.savingsCents,
  });

  factory MonthlyPlan.from(AppSettings s) => MonthlyPlan(
    incomeCents: s.monthlyIncomeCents,
    spendingCents: s.monthlyBudgetCents,
    savingsCents: s.savingsGoalCents,
  );

  final int incomeCents;
  final int spendingCents;
  final int savingsCents;

  /// Income not yet given a job. Negative when the plan asks for more than
  /// comes in.
  int get unplannedCents => incomeCents - spendingCents - savingsCents;

  bool get isOverCommitted => incomeCents > 0 && unplannedCents < 0;

  /// What a typical day of living costs can be, averaged over 30 days.
  int get dailySpendCents => spendingCents ~/ 30;

  /// A suggested spending budget: a share of income, rounded to a tidy
  /// number (nearest 10 in the major unit).
  static int suggestSpending(int monthlyIncomeCents, double share) =>
      ((monthlyIncomeCents * share) / 1000).round() * 1000;

  /// A suggested savings target: what is left after spending, or 20% of
  /// income when spending is unknown.
  static int suggestSavings(int monthlyIncomeCents, int spendingCents) {
    final left = spendingCents > 0 ? monthlyIncomeCents - spendingCents : monthlyIncomeCents ~/ 5;
    return left <= 0 ? 0 : (left / 1000).floor() * 1000;
  }
}
