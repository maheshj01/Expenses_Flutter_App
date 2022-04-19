import 'package:expense_manager/constants/exports.dart';
import 'package:expense_manager/firebase_options.dart';
import 'package:expense_manager/pages/home.dart';
import 'package:expense_manager/utils/settings.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Settings.init();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  Settings appSettings = Settings();
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
        animation: appSettings,
        builder: (context, snapshot) {
          return MaterialApp(
            debugShowCheckedModeBanner: kDebugMode,
            theme: ExpenseTheme.lightThemeData,
            darkTheme: ExpenseTheme.darkThemeData,
            themeMode: Settings.getTheme,
            initialRoute: pages[0],
            routes: {
              pages[0]: (context) => LoginCheck(),
              pages[1]: (context) => ExpensesListPage(),
              pages[2]: (context) => HomePage()
            },
            // home: LoginCheck(),
          );
        });
  }
}
