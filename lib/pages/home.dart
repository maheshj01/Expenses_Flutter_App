import 'package:expense_manager/pages/expense_page.dart';
import 'package:expense_manager/widgets/navbar.dart';
import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: AdaptiveNavBar(
        index: _selectedIndex,
        onChanged: (x) {
          setState(() {
            _selectedIndex = x;
          });
        },
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          Container(
            color: Colors.red,
          ),
          ExpensePage(),
          Container(
            color: Colors.blue,
          ),
        ],
      ),
    );
  }
}
