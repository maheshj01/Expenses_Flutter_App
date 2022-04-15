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

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    loadTheme();
  }

  static ThemeMode get getTheme => _theme;

  static void setTheme(ThemeMode theme) {
    _theme = theme;
    _prefs.setBool('$_themeModeKey', theme == ThemeMode.dark);
  }

  static Future<void> loadTheme() async {
    _theme = _prefs.getBool('$_themeModeKey') ?? false == true
        ? ThemeMode.dark
        : ThemeMode.light;
    setTheme(_theme);
  }

  void notify() {
    notifyListeners();
  }
}
