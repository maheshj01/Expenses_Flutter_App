import '../../domain/entities/app_settings.dart';
import '../../domain/entities/category.dart';

/// How money comes in, asked before any amounts.
enum IncomeKind {
  /// A paycheck, pension or allowance of about the same size.
  regular,

  /// Freelance, commission, seasonal: asked as a typical month.
  varies,

  /// No income of their own, e.g. a home maker or student.
  none,
}

/// Answers collected during onboarding, applied all at once at the end.
class OnboardingDraft {
  OnboardingDraft.from(AppSettings s)
    : name = s.name,
      currencyCode = s.currencyCode,
      incomeCents = s.incomeCents,
      payFrequency = s.payFrequency,
      spendingCents = s.monthlyBudgetCents,
      savingsCents = s.savingsGoalCents,
      goals = {...s.goals},
      // A returning user with no income said so before.
      incomeKind = s.onboarded ? (s.incomeCents > 0 ? IncomeKind.regular : IncomeKind.none) : null,
      // Asked again on first run; shown as answered when editing the plan.
      sharesBills = s.onboarded ? s.splitsBills : null;

  String name;
  String currencyCode;
  int incomeCents;
  PayFrequency payFrequency;
  int spendingCents;
  int savingsCents;
  Set<MoneyGoal> goals;

  /// null until the user answers.
  IncomeKind? incomeKind;

  /// Whether amounts can be compared with an income.
  bool get hasIncome => monthlyIncomeCents > 0;

  /// null until the user answers.
  bool? sharesBills;

  /// Spending categories to keep. null until the categories step is shown.
  Set<String>? categoryIds;

  /// Set once the savings field was pre-filled, so it is not overwritten.
  bool savingsSuggested = false;

  int get monthlyIncomeCents => switch (incomeKind) {
    IncomeKind.none => 0,
    IncomeKind.varies => incomeCents,
    _ => payFrequency.toMonthly(incomeCents),
  };

  AppSettings applyTo(AppSettings s) => s.copyWith(
    onboarded: true,
    name: name.trim(),
    currencyCode: currencyCode,
    incomeCents: incomeKind == IncomeKind.none ? 0 : incomeCents,
    payFrequency: incomeKind == IncomeKind.varies ? PayFrequency.monthly : payFrequency,
    monthlyBudgetCents: spendingCents,
    savingsGoalCents: savingsCents,
    goals: goals,
    splitsBills: sharesBills ?? false,
  );
}

/// Extra spending categories offered during onboarding, beyond the
/// starter set. Fixed ids avoid duplicates across devices.
const suggestedCategories = <Category>[
  Category(id: 'eating_out', name: 'Eating out', emoji: '🍔', color: 0xFFFFF4D6),
  Category(id: 'subscriptions', name: 'Subscriptions', emoji: '📺', color: 0xFFF3E9FA),
  Category(id: 'fitness', name: 'Fitness', emoji: '🏋️', color: 0xFFE9F6EA),
  Category(id: 'pets', name: 'Pets', emoji: '🐶', color: 0xFFFBF0DC),
  Category(id: 'kids', name: 'Kids', emoji: '🧸', color: 0xFFFBE7EE),
  Category(id: 'education', name: 'Education', emoji: '🎓', color: 0xFFE4F1FA),
  Category(id: 'gifts', name: 'Gifts', emoji: '🎁', color: 0xFFFBEAEA),
  Category(id: 'insurance', name: 'Insurance', emoji: '🛡️', color: 0xFFE6ECF5),
  Category(id: 'debt', name: 'Debt payments', emoji: '💳', color: 0xFFEDE9FB),
];

/// Selected by default on first run.
const defaultSelectedCategoryIds = {
  'food',
  'housing',
  'electricity',
  'car',
  'productivity',
  'shopping',
  'entertainment',
  'misc',
};
