import 'dart:math';

import 'package:expense_manager/constants/exports.dart';
import 'package:expense_manager/model/spend.dart';
import 'package:expense_manager/themes/expense_theme.dart';
import 'package:flutter/material.dart';
import 'package:expense_manager/blocs/sqform_bloc.dart';
import 'package:expense_manager/constants/strings.dart';
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
  Color dismissColor = ExpenseTheme.dismissedRight;
  Future _getExpenseDetails() {
    return showModalBottomSheet(
        isScrollControlled: true,
        context: context,
        builder: (BuildContext builder) {
          return EmBottomSheet(
            onSubmit: (Spend spend) {
              bloc.expenseModalController.add(Expense.withFields(spend.value,
                  spend.description, spend.type.name.capitalize(), 0.0, false));
            },
          );
        });
  }

  Widget _listView(context, snapshot) {
    return ListView.builder(
      itemCount: snapshot.data.length,
      itemBuilder: (BuildContext context, int item) {
        return Dismissible(
            direction: DismissDirection.startToEnd,
            dismissThresholds: {
              DismissDirection.startToEnd: 0.4,
              DismissDirection.endToStart: 0.4
            },
            background: Container(
              color: dismissColor,
            ),
            onDismissed: (direction) {
              // bloc.removeExpenseItem(snapshot.data[item].id);
              if (direction == DismissDirection.startToEnd) {
                dismissColor = ExpenseTheme.dismissedRight;
                bloc.removeExpenseItem(snapshot.data[item]);
              } else {
                dismissColor = ExpenseTheme.dismissedLeft;
              }
            },
            key: Key("expenseItem$item"),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.black,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: <Widget>[
                  Expanded(
                    flex: 6,
                    child: Container(
                      padding: EdgeInsets.only(left: 10, right: 5),
                      child: Text(
                        snapshot.data[item].description,
                        textAlign: TextAlign.justify,
                        style: TextStyle(
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 5,
                      ),
                    ),
                  ),
                  Expanded(
                      flex: 3,
                      child: Column(
                        children: <Widget>[
                          Expanded(
                            flex: 1,
                            child: Container(
                              alignment: Alignment.center,
                              child: Text(
                                DateTime.now().day.toString() +
                                    '/' +
                                    DateTime.now().month.toString() +
                                    '/' +
                                    DateTime.now().year.toString(),
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Row(
                              children: <Widget>[
                                Container(
                                  margin: EdgeInsets.only(right: 10, left: 10),
                                  child: Text(
                                    '₹',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                                Expanded(
                                  flex: 4,
                                  child: Container(
                                    child: Text(
                                      snapshot.data[item].amount.toString(),
                                      style: TextStyle(
                                          fontSize: 25, color: Colors.white),
                                    ),
                                  ),
                                )
                              ],
                            ),
                          )
                        ],
                      ))
                ],
              ),
              height: MediaQuery.of(context).size.width / 4,
              margin: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            ));
      },
    );
  }

  Widget drawer() {
    return Theme(
        data: ThemeData.dark(),
        child: Drawer(
            elevation: 1.5,
            child: Column(
              children: <Widget>[
                DrawerHeader(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Container(
                        child: CircleAvatar(
                          child: Container(
                            child: Image.network(
                                "https://icon-library.com/images/male-user-icon/male-user-icon-13.jpg"),
                          ),
                        ),
                      ),
                      Container(
                        child: Text(
                          "Name",
                          style: TextStyle(color: Colors.white, fontSize: 18),
                        ),
                        padding: EdgeInsets.only(bottom: 10),
                        alignment: Alignment.bottomCenter,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    // Important: Remove any padding from the ListView.
                    padding: EdgeInsets.zero,
                    children: <Widget>[
                      ListTile(
                        title: Text('Export File',
                            style:
                                TextStyle(color: Colors.white, fontSize: 18)),
                        leading: Icon(Icons.shopping_cart),
                        onTap: () {
                          // Update the state of the app
                          // ...
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => ExpensePage()));
                        },
                      ),
                      ListTile(
                        title: Text('Create Alert',
                            style:
                                TextStyle(color: Colors.white, fontSize: 18)),
                        leading: Icon(Icons.add_shopping_cart),
                        onTap: () {},
                      ),
                      ListTile(
                        title: Text("Profile",
                            style:
                                TextStyle(color: Colors.white, fontSize: 18)),
                        leading: Icon(Icons.person_pin),
                        onTap: () {},
                      ),
                    ],
                  ),
                ),
                Container(
                  color: Colors.black,
                  width: double.infinity,
                  height: 0.1,
                ),
              ],
            )));
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
                style: ExpenseTheme.rupeeStyle
                    .copyWith(color: Colors.black, fontSize: 32))),
        drawer: Drawer(child: drawer()),
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
                          : _listView(context, snapshot);
                    },
                  )),
            ),
          ],
        ));
  }
}

class EmBottomSheet extends StatefulWidget {
  final Function(Spend) onSubmit;
  const EmBottomSheet({Key? key, required this.onSubmit}) : super(key: key);

  @override
  State<EmBottomSheet> createState() => _EmBottomSheetState();
}

class _EmBottomSheetState extends State<EmBottomSheet> {
  Widget _expenseDescriptionField() {
    return TextField(
      controller: descriptionController,
      textAlign: TextAlign.center,
      cursorColor: Colors.white,
      keyboardType: TextInputType.text,
      style: ExpenseTheme.inputTextStyle,
      maxLines: 3,
      maxLength: 100,
      autofocus: false,
      decoration: InputDecoration(
        counterText: "",
        floatingLabelBehavior: FloatingLabelBehavior.never,
        hintStyle: ExpenseTheme.inputTextStyle,
        hintText: "Spent for ?",
        alignLabelWithHint: true,
        focusedBorder: inputBorder,
        border: inputBorder,
        filled: true,
        fillColor: Colors.black38,
      ),
      onTap: () {},
    );
  }

  Widget _expenseAmountField() {
    return Container(
      padding: EdgeInsets.all(10),
      width: MediaQuery.of(context).size.width / 2,
      child: TextField(
        controller: amountController,
        textAlign: TextAlign.center,
        cursorColor: Colors.white,
        keyboardType: TextInputType.number,
        style: ExpenseTheme.inputTextStyle,
        maxLength: 6,
        autofocus: false,
        decoration: InputDecoration(
          hintText: "0",
          hintStyle: ExpenseTheme.inputTextStyle,
          prefixStyle: ExpenseTheme.inputTextStyle,
          counterText: "",
          labelText: '₹',
          prefixText: '₹',
          floatingLabelBehavior: FloatingLabelBehavior.never,
          labelStyle: ExpenseTheme.inputTextStyle,
          focusedBorder: inputBorder,
          border: inputBorder,
          filled: true,
          fillColor: Colors.black38,
        ),
        onTap: () {},
      ),
    );
  }

  Spend spend = Spend(value: 0, type: SpendType.once, description: '');
  int selectedIndex = 0;
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Container(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          decoration: BoxDecoration(
              color: ExpenseTheme.bottomSheetBackgroundColor,
              borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20), topRight: Radius.circular(20))),
          child: Column(
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  EmIcon(Icons.clear, onTap: () {
                    amountController.clear();
                    descriptionController.clear();
                    Navigator.pop(context);
                  }),
                  _expenseAmountField(),
                  EmIcon(Icons.done, onTap: () {
                    if (amountController.text.isEmpty ||
                        descriptionController.text.isEmpty) {
                      // Navigator.pop(context);
                      return;
                    }
                    var amount = double.parse(amountController.text);
                    var description = descriptionController.text;
                    /// TODO: WorK on custom scrollview
                    final spentValue = spend.copyWith(
                        value: amount,
                        description: description,
                        type: expenseTypes[selectedIndex]);
                    amountController.clear();
                    descriptionController.clear();
                    Navigator.pop(context);
                    widget.onSubmit(spentValue);
                  })
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: ToggleButtons(
                  fillColor: Colors.grey.shade500,
                  children: <Widget>[
                    for (int i = 0; i < expenseTypes.length; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 8.0),
                        child: Text(
                          '${expenseTypes[i].name}'.capitalize(),
                          style: TextStyle(
                              color: ExpenseTheme.toggleButtonTextColor),
                        ),
                      ),
                  ],
                  onPressed: (x) {
                    setState(() {
                      selectedIndex = x;
                    });
                  },
                  isSelected: [for (int i = 0; i < 3; i++) selectedIndex == i],
                ),
              ),
              Container(
                margin: EdgeInsets.symmetric(horizontal: 10),
                child: _expenseDescriptionField(),
              ),
              SizedBox(
                height: 20,
              ),
            ],
          )),
    );
  }
}

class TotalSpentValue extends StatefulWidget {
  const TotalSpentValue({Key? key}) : super(key: key);

  @override
  State<TotalSpentValue> createState() => _TotalSpentValueState();
}

class _TotalSpentValueState extends State<TotalSpentValue> {
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
