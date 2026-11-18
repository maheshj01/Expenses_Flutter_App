import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/app_settings.dart';
import '../../domain/repositories/settings_repository.dart';

/// Device-local preferences. These are personal settings, so they are
/// intentionally not synced.
class PrefsSettingsRepository implements SettingsRepository {
  PrefsSettingsRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _budget = 'monthlyBudgetCents';
  static const _currency = 'currencyCode';
  static const _splitsBills = 'splitsBills';
  static const _savedGuests = 'savedGuests';

  /// Before saved people, a single "usually split with" name lived here.
  static const _legacySplitWith = 'splitWith';
  static const _onboarded = 'onboarded';
  static const _name = 'name';
  static const _income = 'incomeCents';
  static const _payFrequency = 'payFrequency';
  static const _savingsGoal = 'savingsGoalCents';
  static const _goals = 'goals';

  @override
  AppSettings load() {
    final legacy = _prefs.getString(_legacySplitWith)?.trim() ?? '';
    return AppSettings(
      monthlyBudgetCents: _prefs.getInt(_budget) ?? 0,
      currencyCode: _prefs.getString(_currency) ?? 'USD',
      splitsBills: _prefs.getBool(_splitsBills) ?? legacy.isNotEmpty,
      savedGuests: _prefs.getStringList(_savedGuests) ?? [if (legacy.isNotEmpty) legacy],
      onboarded: _prefs.getBool(_onboarded) ?? false,
      name: _prefs.getString(_name) ?? '',
      incomeCents: _prefs.getInt(_income) ?? 0,
      payFrequency: PayFrequency.parse(_prefs.getString(_payFrequency)),
      savingsGoalCents: _prefs.getInt(_savingsGoal) ?? 0,
      goals: MoneyGoal.parseAll(_prefs.getStringList(_goals) ?? const []),
    );
  }

  @override
  Future<void> save(AppSettings s) async {
    await Future.wait([
      _prefs.setInt(_budget, s.monthlyBudgetCents),
      _prefs.setString(_currency, s.currencyCode),
      _prefs.setBool(_splitsBills, s.splitsBills),
      _prefs.setStringList(_savedGuests, s.savedGuests),
      _prefs.remove(_legacySplitWith),
      _prefs.setBool(_onboarded, s.onboarded),
      _prefs.setString(_name, s.name),
      _prefs.setInt(_income, s.incomeCents),
      _prefs.setString(_payFrequency, s.payFrequency.name),
      _prefs.setInt(_savingsGoal, s.savingsGoalCents),
      _prefs.setStringList(_goals, [for (final g in s.goals) g.name]),
    ]);
  }
}
