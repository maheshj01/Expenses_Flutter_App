import 'package:expense_manager/const/color_const.dart';
import 'package:flutter/material.dart';
import '../const/page_str_const.dart';

class LoginCheck extends StatefulWidget {
  @override
  _LoginCheckState createState() => _LoginCheckState();
}

class _LoginCheckState extends State<LoginCheck> {
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: scaffoldBackgroundColor,
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
                child: RaisedButton(
                  child: Text("Skip"),
                  onPressed: () {
                    Navigator.pushReplacementNamed(context, pages[1]);
                  },
                ),
              ))
        ]));
  }
}
