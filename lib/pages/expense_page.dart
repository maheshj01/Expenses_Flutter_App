import 'dart:math';

import 'package:flutter/material.dart';
import 'package:expense_manager/blocs/expense_bloc.dart';
import 'package:expense_manager/const/page_str_const.dart';
import 'package:expense_manager/model/expense_modal.dart';
import 'package:pdf/widgets.dart' as document;
import '../const/color_const.dart';

class ExpensePage extends StatefulWidget {
  @override
  _ExpensePageState createState() => _ExpensePageState();
}

final bloc = ExpenseBloc();
final TextEditingController amountController = new TextEditingController();
final TextEditingController descriptionController = TextEditingController();
final pdf = document.Document();

class _ExpensePageState extends State<ExpensePage> {
  Future _getExpenseDetails() {
    return showModalBottomSheet(
        isScrollControlled: true,
        context: context,
        builder: (BuildContext builder) {
          return SingleChildScrollView(
            child: Container(
                padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom),
                decoration: BoxDecoration(
                    color: bottomSheetBackgroundColor,
                    borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20))),
                child: Column(
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        _bottomSheetIcons(Icons.clear),
                        _expenseAmountField(),
                        _bottomSheetIcons(Icons.done)
                      ],
                    ),
                    Container(
                      height: 40,
                    ),
                    Container(
                      margin: EdgeInsets.symmetric(horizontal: 10),
                      child: _expenseDescriptionField(),
                    ),
                    Container(
                      height: 20,
                    ),
                  ],
                )),
          );
        });
  }

  Widget _expenseDescriptionField() {
    return TextField(
      controller: descriptionController,
      textAlign: TextAlign.center,
      cursorColor: Colors.white,
      keyboardType: TextInputType.text,
      style: inputTextStyle,
      maxLines: 3,
      maxLength: 100,
      autofocus: false,
      decoration: InputDecoration(
        counterText: "",
        hasFloatingPlaceholder: false,
        hintStyle: inputTextStyle,
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
        style: inputTextStyle,
        maxLength: 6,
        autofocus: false,
        decoration: InputDecoration(
          hintText: "0",
          hintStyle: inputTextStyle,
          prefixStyle: inputTextStyle,
          counterText: "",
          labelText: '₹',
          prefixText: '₹',
          hasFloatingPlaceholder: false,
          labelStyle: inputTextStyle,
          focusedBorder: inputBorder,
          border: inputBorder,
          filled: true,
          fillColor: Colors.black38,
        ),
        onTap: () {},
      ),
    );
  }

  Widget _bottomSheetIcons(IconData icon) {
    return Padding(
      padding: EdgeInsets.all(10),
      child: IconButton(
        icon: Icon(icon),
        iconSize: 40,
        color: Colors.white,
        onPressed: () {
          ExpenseModal expenseModal;
          icon == Icons.done
              ? {
                  expenseModal = ExpenseModal(
                      double.parse(amountController.text),
                      descriptionController.text),
                  // bloc.expenseList.insert(0, expenseModal),
                  // bloc.expenseListStreamSink.add(bloc.expenseList),
                  bloc.updateTotalExpense(expenseModal),
                }
              : {};
          print("hide Bottom Sheet");
          Navigator.pop(context);
        },
      ),
    );
  }

  Widget _listView(context, snapshot) {
    return ListView.builder(
      itemCount: snapshot.data.length,
      itemBuilder: (BuildContext context, int item) {
        return Container(
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
        );
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
                                "https://icon-library.net/images/male-user-icon/male-user-icon-13.jpg"),
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
        backgroundColor: scaffoldBackgroundColor,
        floatingActionButton: FloatingActionButton(
          backgroundColor: floatingBackgroundColor,
          onPressed: () {
            print("show sheet");
            _getExpenseDetails();
          },
          tooltip: 'Increment',
          child: Icon(
            Icons.add,
            color: floatingIconColor,
          ),
        ),
        drawer: Drawer(child: drawer()),
        appBar: AppBar(
          centerTitle: true,
          title: Text("Expenses Manager"),
          backgroundColor: scaffoldBackgroundColor,
        ),
        body: Column(
          children: <Widget>[
            Expanded(
              flex: 6,
              child: Container(
                  padding: EdgeInsets.only(bottom: 10),
                  child: StreamBuilder(
                    stream: bloc.expenseListStream,
                    builder: (BuildContext context,
                        AsyncSnapshot<List<ExpenseModal>> snapshot) {
                      return snapshot.data == null
                          ? Center(
                              child: Text(
                                  emptyList[Random().nextInt(emptyList.length)],
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 16)))
                          : _listView(context, snapshot);
                    },
                  )),
            ),
            Container(
              height: 5,
              color: Colors.white,
            ),
            Expanded(
              flex: 1,
              child: Container(
                margin: EdgeInsets.only(left: 15, right: 15),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 10,
                    ),
                    Expanded(
                      flex: 1,
                      child: Text("Total",
                          style: TextStyle(fontSize: 25, color: Colors.white)),
                    ),
                    Container(
                      margin: EdgeInsets.only(right: 3),
                      child: Text("₹",
                          style: TextStyle(fontSize: 20, color: Colors.white)),
                    ),
                    Expanded(
                        flex: 1,
                        child: StreamBuilder(
                          stream: bloc.totalExpenseController,
                          builder: (BuildContext context,
                              AsyncSnapshot<double> snapshot) {
                            return snapshot.data == null
                                ? Text(
                                    "0.00",
                                    style: inputTextStyle,
                                  )
                                : Text(snapshot.data.toString(),
                                    style: inputTextStyle);
                          },
                        )),
                  ],
                ),
              ),
            )
          ],
        ));
  }
}
