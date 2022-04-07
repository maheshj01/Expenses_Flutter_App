import 'dart:math';

import 'package:expense_manager/constants/exports.dart';
import 'package:expense_manager/model/spend.dart';
import 'package:expense_manager/widgets/bottom_sheet.dart';
import 'package:expense_manager/widgets/drawer.dart';
import 'package:expense_manager/widgets/expense_list_tile.dart';
import 'package:flutter/material.dart';
import 'package:expense_manager/blocs/sqform_bloc.dart';
import 'package:expense_manager/model/model.dart';

class ExpensePage extends StatefulWidget {
  @override
  _ExpensePageState createState() => _ExpensePageState();
}

// final bloc = ExpenseBloc();
final bloc = SqfOrmBloc();
final TextEditingController amountController = new TextEditingController();
final TextEditingController descriptionController = TextEditingController();
// final pdf = document.Document();

class _ExpensePageState extends State<ExpensePage> {
  Future _getExpenseDetails() {
    return showModalBottomSheet(
        isScrollControlled: true,
        context: context,
        builder: (BuildContext builder) {
          return EmBottomSheet(
            onSubmit: (Spend spend) {
              bloc.expenseModalController.add(Expense.withFields(
                  DateTime.now(),
                  spend.value,
                  spend.description,
                  spend.type.name.capitalize(),
                  0.0,
                  false));
            },
          );
        });
  }

  List<DropdownMenuItem<String>> list = [
    DropdownMenuItem<String>(
      value: 'August',
      child: Text(
        'August',
        style: TextStyle(color: Colors.white),
      ),
    ),
    DropdownMenuItem<String>(
      value: 'September',
      child: Text(
        'September',
        style: TextStyle(color: Colors.white),
      ),
    ),
    DropdownMenuItem<String>(
        value: 'October',
        child: Text(
          'October',
          style: TextStyle(color: Colors.white),
        )),
    DropdownMenuItem<String>(
      value: 'November',
      child: Text(
        'November',
        style: TextStyle(color: Colors.white),
      ),
    )
  ];
  String selectedValue = "August";

  @override
  void dispose() {
    amountController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        resizeToAvoidBottomInset: true,
        floatingActionButton: FloatingActionButton(
            backgroundColor: ExpenseTheme.floatingBackgroundColor,
            onPressed: () {
              _getExpenseDetails();
            },
            tooltip: 'Add Expense',
            child: Text('$rupeeSymbol',
                style: ExpenseTheme.rupeeStyle.copyWith(fontSize: 32))),
        drawer: Drawer(child: EmDrawer()),
        body: Column(
          children: <Widget>[
            SizedBox(height: 200, child: TotalSpentValue()),
            Expanded(
              flex: 6,
              child: Container(
                  padding: EdgeInsets.only(bottom: 10),
                  child: StreamBuilder<List<Expense>>(
                    stream: bloc.expenseListStream,
                    builder: (BuildContext context,
                        AsyncSnapshot<List<Expense>> snapshot) {
                      return snapshot.data == null
                          ? Center(
                              child: Text(
                                  emptyListMessage[Random()
                                      .nextInt(emptyListMessage.length)],
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 16)))
                          : ListView.builder(
                              itemCount: snapshot.data?.length,
                              itemBuilder: (BuildContext context, int item) {
                                return ExpenseListTile(
                                  model: snapshot.data![item],
                                );
                              },
                            );
                    },
                  )),
            ),
          ],
        ));
  }
}

class TotalSpentValue extends StatelessWidget {
  const TotalSpentValue({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        StreamBuilder(
          stream: bloc.totalExpenseController,
          builder: (BuildContext context, AsyncSnapshot<double> snapshot) {
            return RichText(
                text: TextSpan(children: [
              TextSpan(text: '$rupeeSymbol  ', style: ExpenseTheme.rupeeStyle),
              TextSpan(
                  text: snapshot.data == null
                      ? '0.00'
                      : '${snapshot.data.toString()}',
                  style: ExpenseTheme.inputTextStyle),
            ]));
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text("Total Spent",
              style: TextStyle(fontSize: 18, color: Colors.white)),
        ),
      ],
    );
  }
}

class EmIcon extends StatelessWidget {
  EmIcon(this.iconData, {Key? key, required this.onTap}) : super(key: key);
  final IconData iconData;
  final Function onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(10),
      child: IconButton(
          icon: Icon(iconData),
          iconSize: 40,
          color: Colors.white,
          onPressed: () => onTap()),
    );
  }
}
