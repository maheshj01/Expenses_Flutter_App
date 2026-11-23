/// How often income arrives.
enum PayFrequency {
  weekly('Weekly', 'a week'),
  biweekly('Every 2 weeks', 'every 2 weeks'),
  semimonthly('Twice a month', 'twice a month'),
  monthly('Monthly', 'a month');

  const PayFrequency(this.label, this.per);

  final String label;

  /// Used in sentences: "$1,800 every 2 weeks".
  final String per;

  /// Converts one paycheck to an average month (52 weeks / 12 months).
  int toMonthly(int cents) => switch (this) {
    PayFrequency.weekly => (cents * 52 / 12).round(),
    PayFrequency.biweekly => (cents * 26 / 12).round(),
    PayFrequency.semimonthly => cents * 2,
    PayFrequency.monthly => cents,
  };

  static PayFrequency parse(String? value) =>
      PayFrequency.values.firstWhere((f) => f.name == value, orElse: () => PayFrequency.monthly);
}

/// What the user is working towards. Shapes suggestions and the home screen.
enum MoneyGoal {
  emergencyFund('🛟', 'Build an emergency fund'),
  investMore('📈', 'Save or invest more'),
  payOffDebt('💳', 'Pay off debt'),
  bigPurchase('🏡', 'Save for something big'),
  spendLess('✂️', 'Spend less'),
  understand('🔍', 'See where my money goes');

  const MoneyGoal(this.emoji, this.label);

  final String emoji;
  final String label;

  static Set<MoneyGoal> parseAll(Iterable<String> values) => {
    for (final v in values) ...MoneyGoal.values.where((g) => g.name == v),
  };
}

class AppSettings {
  const AppSettings({
    this.monthlyBudgetCents = 0,
    this.currencyCode = 'USD',
    this.splitsBills = false,
    this.savedGuests = const [],
    this.onboarded = false,
    this.name = '',
    this.incomeCents = 0,
    this.payFrequency = PayFrequency.monthly,
    this.savingsGoalCents = 0,
    this.goals = const {},
  });

  /// Monthly budget for living (spending) costs. 0 means not set.
  final int monthlyBudgetCents;
  final String currencyCode;

  /// The user said they split bills with others.
  final bool splitsBills;

  /// People not on the app the user splits with, offered in the split picker.
  final List<String> savedGuests;

  /// True once the first-run setup has been completed or skipped.
  final bool onboarded;

  /// What to call the user. Optional.
  final String name;

  /// One paycheck, in cents, received every [payFrequency].
  final int incomeCents;
  final PayFrequency payFrequency;

  /// How much the user wants to set aside (invest or keep) each month.
  final int savingsGoalCents;
  final Set<MoneyGoal> goals;

  bool get hasBudget => monthlyBudgetCents > 0;

  bool get hasIncome => incomeCents > 0;

  bool get hasSavingsGoal => savingsGoalCents > 0;

  int get monthlyIncomeCents => payFrequency.toMonthly(incomeCents);

  /// [savedGuests] plus any of [names] not saved yet (ignoring case).
  List<String> withGuests(Iterable<String> names) {
    final known = {for (final n in savedGuests) n.toLowerCase()};
    return [
      ...savedGuests,
      for (final n in names)
        if (n.trim().isNotEmpty && known.add(n.trim().toLowerCase())) n.trim(),
    ];
  }

  AppSettings copyWith({
    int? monthlyBudgetCents,
    String? currencyCode,
    bool? splitsBills,
    List<String>? savedGuests,
    bool? onboarded,
    String? name,
    int? incomeCents,
    PayFrequency? payFrequency,
    int? savingsGoalCents,
    Set<MoneyGoal>? goals,
  }) {
    return AppSettings(
      monthlyBudgetCents: monthlyBudgetCents ?? this.monthlyBudgetCents,
      currencyCode: currencyCode ?? this.currencyCode,
      splitsBills: splitsBills ?? this.splitsBills,
      savedGuests: savedGuests ?? this.savedGuests,
      onboarded: onboarded ?? this.onboarded,
      name: name ?? this.name,
      incomeCents: incomeCents ?? this.incomeCents,
      payFrequency: payFrequency ?? this.payFrequency,
      savingsGoalCents: savingsGoalCents ?? this.savingsGoalCents,
      goals: goals ?? this.goals,
    );
  }
}
