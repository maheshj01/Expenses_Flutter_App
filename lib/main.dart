import 'package:expense_manager/constants/exports.dart';
import 'package:expense_manager/utils/settings.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(MyApp());
}

Settings appSettings = Settings();

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
        animation: appSettings,
        builder: (context, snapshot) {
          return MaterialApp(
            debugShowCheckedModeBanner: kDebugMode,
            theme: ExpenseTheme.lightThemeData,
            darkTheme: ExpenseTheme.darkThemeData,
            themeMode: appSettings.getTheme,
            initialRoute: pages[0],
            routes: {
              pages[0]: (context) => LoginCheck(),
              pages[1]: (context) => ExpensePage()
            },
            // home: LoginCheck(),
          );
        });
  }
}
