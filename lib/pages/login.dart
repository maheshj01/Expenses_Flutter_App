import 'package:expense_manager/constants/exports.dart';
import 'package:expense_manager/utils/settings.dart';
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
// Settings appSettings = Settings();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Column(
            // crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
          Expanded(
            flex: 2,
            child: Center(
                child: Image.asset(Settings.getTheme == ThemeMode.light
                    ? '$imagesDirectory/logo_dark.png'
                    : '$imagesDirectory/logo_white.png')),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16),
            child: Column(
              children: [
                EmButton(
                    onTap: () {
                      Navigator.of(context).pushNamed(pages[1]);
                    },
                    text: 'Login'),
                SizedBox(
                  height: 16,
                ),
                EmButton(
                    onTap: () {
                      Navigator.of(context).pushNamed(pages[2]);
                    },
                    text: 'Sign Up with Google'),
              ],
            ),
          ),
          SizedBox(
            height: 32,
          )
        ]));
  }
}
