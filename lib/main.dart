import 'package:flutter/material.dart';
import 'const/page_str_const.dart';
import 'const/page_export_const.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(canvasColor: Colors.transparent),
      initialRoute: pages[0],
      routes: {
        pages[0]: (context) => LoginCheck(),
        pages[1]: (context) => ExpensePage()
      },
      // home: LoginCheck(),
    );
  }
}
