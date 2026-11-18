import '../../domain/entities/app_settings.dart';
import '../../domain/entities/category.dart';

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
      splitWith = s.splitWith,
      sharesBills = s.splitWith.isNotEmpty ? true : null;

  String name;
  String currencyCode;
  int incomeCents;
  PayFrequency payFrequency;
  int spendingCents;
  int savingsCents;
  Set<MoneyGoal> goals;

  /// null until the user answers.
  bool? sharesBills;
  String splitWith;

  /// Spending categories to keep. null until the categories step is shown.
  Set<String>? categoryIds;

  /// Set once the savings field was pre-filled, so it is not overwritten.
  bool savingsSuggested = false;

  int get monthlyIncomeCents => payFrequency.toMonthly(incomeCents);

  AppSettings applyTo(AppSettings s) => s.copyWith(
    onboarded: true,
    name: name.trim(),
    currencyCode: currencyCode,
    incomeCents: incomeCents,
    payFrequency: payFrequency,
    monthlyBudgetCents: spendingCents,
    savingsGoalCents: savingsCents,
    goals: goals,
    splitWith: sharesBills ?? false ? splitWith.trim() : '',
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
