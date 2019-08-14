import 'package:expense_manager/const/page_str_const.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../const/color_const.dart';

class ExpensePage extends StatefulWidget {
  @override
  _ExpensePageState createState() => _ExpensePageState();
}

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
                    color: bottomsheet_background_color,
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
      textAlign: TextAlign.center,
      cursorColor: Colors.white,
      keyboardType: TextInputType.number,
      style: inputTextStyle,
      maxLines: 3,
      maxLength: 50,
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
          print("hide Bottom Sheet");
          Navigator.pop(context);
        },
      ),
    );
  }

  Widget _listView() {
    return ListView.builder(
      itemCount: 10,
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
                    "hello world this is my first payment Iam goona make it to the moon  is my first payment Iam goona make it to the moon",
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
                                  "500",
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
        backgroundColor: scaffold_background_color,
        floatingActionButton: FloatingActionButton(
          backgroundColor: floating_background_color,
          onPressed: () {
            print("show sheet");
            _getExpenseDetails();
          },
          tooltip: 'Increment',
          child: Icon(
            Icons.add,
            color: floating_icon_color,
          ),
        ),
        appBar: AppBar(
          backgroundColor: scaffold_background_color,
          actions: <Widget>[
            Theme(
              data: ThemeData(canvasColor: Colors.blueAccent),
              child: DropdownButton<String>(
                items: list,
                value: selectedValue,
                onChanged: (String value) {
                  setState(() {
                    selectedValue = value;
                    print(DateTime.now().month);
                  });
                  print('selected $value');
                },
              ),
            )
          ],
        ),
        body: Column(
          children: <Widget>[
            Expanded(
              flex: 6,
              child: Container(
                  padding: EdgeInsets.only(bottom: 10), child: _listView()),
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
                      child: Text("45575",
                          style: TextStyle(fontSize: 25, color: Colors.white)),
                    ),
                  ],
                ),
              ),
            )
          ],
        ));
  }
}
