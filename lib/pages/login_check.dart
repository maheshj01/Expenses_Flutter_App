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
        body: Center(
      child: RaisedButton(
        child: Text("Go To Expenses"),
        onPressed: () {
          Navigator.pushReplacementNamed(context, pages[1]);
        },
      ),
    ));
  }
}
