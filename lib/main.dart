import 'package:expense_manager/constants/exports.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
          scaffoldBackgroundColor: ExpenseTheme.scaffoldBackgroundColor,
          canvasColor: Colors.transparent),
      initialRoute: pages[0],
      routes: {
        pages[0]: (context) => LoginCheck(),
        pages[1]: (context) => ExpensePage()
      },
      // home: LoginCheck(),
    );
  }
}
