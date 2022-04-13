import 'package:expense_manager/constants/exports.dart';
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
        child: Container(
          alignment: Alignment.bottomCenter,
          child: Text(
            "Come to the Dart Side",
            style: ExpenseTheme.inputTextStyle,
            textAlign: TextAlign.center,
          ),
        ),
        flex: 1,
      ),
      Expanded(
          flex: 2,
          child: Center(
            child: ElevatedButton(
              child: Text("Skip"),
              onPressed: () {
                Navigator.pushReplacementNamed(context, 'ExpensePage');
              },
            ),
          ))
    ]));
  }
}
