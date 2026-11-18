import 'package:flutter/material.dart';

import 'shell.dart';
import 'theme.dart';

class MoneyTraceApp extends StatelessWidget {
  const MoneyTraceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MoneyTrace',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      home: const AppShell(),
    );
  }
}
