import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/app_settings.dart';
import '../../domain/repositories/settings_repository.dart';

/// Device-local preferences. These are personal UI settings, so they are
/// intentionally not synced.
class PrefsSettingsRepository implements SettingsRepository {
  PrefsSettingsRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _budget = 'monthlyBudgetCents';
  static const _currency = 'currencyCode';
  static const _splitWith = 'splitWith';

  @override
  AppSettings load() => AppSettings(
    monthlyBudgetCents: _prefs.getInt(_budget) ?? 0,
    currencyCode: _prefs.getString(_currency) ?? 'USD',
    splitWith: _prefs.getString(_splitWith) ?? '',
  );

  @override
  Future<void> save(AppSettings s) async {
    await _prefs.setInt(_budget, s.monthlyBudgetCents);
    await _prefs.setString(_currency, s.currencyCode);
    await _prefs.setString(_splitWith, s.splitWith);
  }
}
