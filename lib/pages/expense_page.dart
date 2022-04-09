import 'dart:math';

import 'package:expense_manager/constants/exports.dart';
import 'package:expense_manager/utils/utils.dart';
import 'package:expense_manager/model/spend.dart';
import 'package:expense_manager/widgets/bottom_sheet.dart';
import 'package:expense_manager/widgets/drawer.dart';
import 'package:expense_manager/widgets/expense_list_tile.dart';
import 'package:flutter/material.dart';
import 'package:expense_manager/blocs/sqform_bloc.dart';
import 'package:expense_manager/model/model.dart';
import 'package:intl/intl.dart';

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
        shape: RoundedRectangleBorder(
          //the rounded corner is created here
          borderRadius: BorderRadius.circular(14.0),
        ),
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

  /**
   * 
   * [2, 2, 3, 4, 4]
   * 
   * output
   *    0      1 ,  2       3
   * [['T', 2, 2],['T', 3],['T', 4, 4]
   */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        resizeToAvoidBottomInset: true,
        floatingActionButton: FloatingActionButton(
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
                if (snapshot.data == null)
                  return Center(
                      child: Text(
                          emptyListMessage[
                              Random().nextInt(emptyListMessage.length)],
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white, fontSize: 16)));
                else {
                  return CustomScrollView(
                    slivers: <Widget>[
                      // SliverPersistentHeader(
                      //   delegate: EmSliverAppBar(
                      //     child: OverflowBox(
                      //         maxHeight: 200, child: TotalSpentValue()),
                      //   ),
                      // ),
                      SliverAppBar(
                        pinned: true,
                        snap: false,
                        floating: false,
                        expandedHeight: 160.0,
                        flexibleSpace: const FlexibleSpaceBar(
                          expandedTitleScale: 1.2,
                          titlePadding: EdgeInsets.only(
                              top: kToolbarHeight,
                              bottom: kTextTabBarHeight / 2),
                          title: OverflowBox(
                              maxHeight: 200, child: TotalSpentValue()),
                          // background: FlutterLogo(),
                        ),
                      ),
                      SliverList(
                          delegate: SliverChildBuilderDelegate(
                        (BuildContext context, int index) {
                          bool isSameDate = true;
                          final item = snapshot.data![index];
                          if (index == 0) {
                            isSameDate = false;
                          } else {
                            final prevItem = snapshot.data![index - 1];
                            isSameDate =
                                item.datetime!.isSameDate(prevItem.datetime!);
                          }
                          if (index == 0 || !(isSameDate)) {
                            return Column(
                              children: [
                                SizedBox(
                                  height: 12,
                                ),
                                Text(item.datetime!.formatDate()),
                                ExpenseListTile(
                                  model: snapshot.data![index],
                                ),
                              ],
                            );
                          } else {
                            return ExpenseListTile(
                              model: snapshot.data![index],
                            );
                          }
                        },
                        childCount: snapshot.data!.length,
                      ))
                    ],
                  );
                }
              },
            )));
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
                text: TextSpan(
                    style: TextStyle(
                        color: ExpenseTheme.isDarkTheme(context)
                            ? Colors.white
                            : Colors.black),
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
          child: Text(
            "Total Spent",
            style: TextStyle(
                fontSize: 18,
                color: ExpenseTheme.isDarkTheme(context)
                    ? Colors.white
                    : Colors.black),
          ),
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
