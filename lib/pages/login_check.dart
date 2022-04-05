import 'package:expense_manager/constants/strings.dart';
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
            "Login to Keep Data Synced with the Cloud",
            style: inputTextStyle,
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
                Navigator.pushReplacementNamed(context, pages[1]);
              },
            ),
          ))
    ]));
  }
}
