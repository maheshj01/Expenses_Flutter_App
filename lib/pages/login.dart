import 'package:expense_manager/constants/exports.dart';
import 'package:expense_manager/main.dart';
import 'package:expense_manager/widgets/filter_sheet.dart';
import 'package:flutter/material.dart';

class LoginCheck extends StatefulWidget {
  @override
  _LoginCheckState createState() => _LoginCheckState();
}

class _LoginCheckState extends State<LoginCheck> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Column(children: <Widget>[
      Expanded(
        flex: 2,
        child: Center(
            child: Image.asset(appSettings.getTheme == ThemeMode.light
                ? '$imagesDirectory/logo_dark.png'
                : '$imagesDirectory/logo_white.png')),
      ),
      Expanded(
          child: Column(
        children: [EmButton(onTap: () {}, text: 'Sign up')],
      ))
    ]));
  }
}
