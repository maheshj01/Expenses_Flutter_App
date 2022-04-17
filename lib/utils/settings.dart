import 'package:expense_manager/services/expense.dart';
import 'package:expense_manager/model/currency.dart';
import 'package:expense_manager/themes/expense_theme.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Settings extends ChangeNotifier {
  static final Settings _singleton = Settings._internal();

  factory Settings() {
    return _singleton;
  }

  Settings._internal();

  static late SharedPreferences _prefs;
  static ThemeMode _theme = ThemeMode.system;
  static String _themeModeKey = 'themeMode';
  static String _currencyKey = 'currency';
  static Currency _currency = Currency.init();

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    loadTheme();
    fetchCurrency();
  }

  static Currency get currency => _currency;

  static void setCurrency(Currency value) {
    _currency = value;
    _prefs.setString(_currencyKey, value.code);
    _singleton.notify();
  }

  static ThemeMode get getTheme => _theme;

  static void setTheme(ThemeMode theme) {
    _theme = theme;
    bool isDark = theme == ThemeMode.dark;
    _prefs.setBool('$_themeModeKey', isDark);
    ExpenseTheme.isDark = isDark;
    _singleton.notify();
  }

  static Future<void> loadTheme() async {
    final bool isDark = _prefs.getBool('$_themeModeKey') ?? false;
    _theme = isDark == true ? ThemeMode.dark : ThemeMode.light;
    ExpenseTheme.isDark = isDark;
    setTheme(_theme);
  }

  static Future<void> fetchCurrency() async {
    final _currencyCode = _prefs.getString('$_currencyKey');
    if (_currencyCode == null) {
      _currency = Currency.init();
    } else {
      _currency = currencyList.firstWhere(
          (element) => element.code == _currencyCode,
          orElse: () => Currency.init());
    }
    setCurrency(_currency);
  }

  static void clear() {
    final expenseService = ExpenseService();
    _prefs.clear();
  }

  void notify() {
    notifyListeners();
  }
}
