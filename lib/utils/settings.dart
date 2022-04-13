import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Settings extends ChangeNotifier {
  late SharedPreferences _prefs;
  ThemeMode _theme = ThemeMode.system;
  static const String _themeModeKey = 'themeMode';
  Settings() {
    _init();
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    loadTheme();
  }

  ThemeMode get getTheme => _theme;

  void setTheme(ThemeMode theme) {
    _theme = theme;
    _prefs.setBool('$_themeModeKey', theme == ThemeMode.dark);
    notifyListeners();
  }

  Future<void> loadTheme() async {
    _theme = _prefs.getBool('$_themeModeKey') ?? false == true
        ? ThemeMode.dark
        : ThemeMode.light;
    setTheme(_theme);
  }

  void notifyListeners() {
    super.notifyListeners();
  }
}
