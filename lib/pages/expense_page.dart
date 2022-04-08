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
        body: Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: StreamBuilder<List<Expense>>(
              stream: bloc.expenseListStream,
              builder: (BuildContext context,
                  AsyncSnapshot<List<Expense>> snapshot) {
                return snapshot.data == null
                    ? Center(
                        child: Text(
                            emptyListMessage[
                                Random().nextInt(emptyListMessage.length)],
                            textAlign: TextAlign.center,
                            style:
                                TextStyle(color: Colors.white, fontSize: 16)))
                    : CustomScrollView(
                        slivers: <Widget>[
                          SliverPersistentHeader(
                            delegate: EmSliverAppBar(
                              child: OverflowBox(
                                  maxHeight: 200, child: TotalSpentValue()),
                            ),
                          ),
                          SliverList(
                              delegate: SliverChildBuilderDelegate(
                            (BuildContext context, int index) {
                              return ExpenseListTile(
                                model: snapshot.data![index % 2],
                              );
                            },
                            childCount: snapshot.data!.length * 10,
                          ))
                        ],
                      );
              },
            )));
  }
}

class TotalSpentValue extends StatelessWidget {
  const TotalSpentValue({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    var brightness = MediaQuery.of(context).platformBrightness;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        StreamBuilder(
          stream: bloc.totalExpenseController,
          builder: (BuildContext context, AsyncSnapshot<double> snapshot) {
            return RichText(
                text: TextSpan(
                    style: TextStyle(
                        color: brightness == Brightness.dark
                            ? Colors.black
                            : Colors.white),
                    children: [
                  TextSpan(
                      text: '$rupeeSymbol  ', style: ExpenseTheme.rupeeStyle),
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
              style: TextStyle(
                fontSize: 18,
              )),
        ),
      ],
    );
  }
}

class EmSliverAppBar extends SliverPersistentHeaderDelegate {
  final Widget child;
  EmSliverAppBar({required this.child});
  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    // TODO: implement build
    return child;
  }

  @override
  // TODO: implement maxExtent
  double get maxExtent => 200.0;

  @override
  // TODO: implement minExtent
  double get minExtent => 20.0;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) =>
      true;
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
