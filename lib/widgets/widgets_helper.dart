import 'package:expense_manager/themes/expense_theme.dart';
import 'package:flutter/material.dart';

Future<void> showEMBottomSheet(BuildContext context, Widget child) {
  return showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
            topLeft: Radius.circular(14.0), topRight: Radius.circular(14.0)),
      ),
      builder: (BuildContext builder) => SingleChildScrollView(
          child: Container(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom),
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20))),
              child: child)));
}

Widget title(String title) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Text(
          '$title',
          style: ExpenseTheme.textTheme.headline4,
        ),
      );
    }
