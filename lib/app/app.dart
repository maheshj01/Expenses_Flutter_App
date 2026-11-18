import 'package:flutter/material.dart';

import 'shell.dart';
import 'theme.dart';

class ThreeBucksApp extends StatelessWidget {
  const ThreeBucksApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Three Bucks',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      home: const AppShell(),
    );
  }
}
