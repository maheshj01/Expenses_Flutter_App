class AppSettings {
  const AppSettings({this.monthlyBudgetCents = 0, this.currencyCode = 'USD', this.splitWith = ''});

  /// Monthly budget for living (spending) costs. 0 means not set.
  final int monthlyBudgetCents;
  final String currencyCode;

  /// Name of the person you usually split bills with (shown as a hint).
  final String splitWith;

  bool get hasBudget => monthlyBudgetCents > 0;

  AppSettings copyWith({int? monthlyBudgetCents, String? currencyCode, String? splitWith}) {
    return AppSettings(
      monthlyBudgetCents: monthlyBudgetCents ?? this.monthlyBudgetCents,
      currencyCode: currencyCode ?? this.currencyCode,
      splitWith: splitWith ?? this.splitWith,
    );
  }
}
