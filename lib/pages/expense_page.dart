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

class _ExpensePageState extends State<ExpensePage>
    with TickerProviderStateMixin {
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

  @override
  void dispose() {
    _animationController.dispose();
    amountController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  late AnimationController _animationController;
  double animationDuration = 0.0;
  int totalItems = 6;
  final int totalDuration = 6000;
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _animationController = AnimationController(
        vsync: this, duration: Duration(milliseconds: totalDuration));
  }

  bool isReversed = false;
  List<Expense> expenses = [];
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
                  return Center(child: CircularProgressIndicator());
                else {
                  totalItems = snapshot.data!.length;
                  animationDuration = totalItems / 100; // in seconds
                  print('animation Duration for each item=$animationDuration');
                  _animationController.forward();
                  return CustomScrollView(
                    slivers: <Widget>[
                      SliverAppBar(
                        pinned: true,
                        floating: true,
                        expandedHeight: 160.0,
                        flexibleSpace: FlexibleSpaceBar(
                          background: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                end: Alignment.bottomCenter,
                                begin: Alignment.topCenter,
                                colors: [
                                  ExpenseTheme.colorScheme.surface,
                                  ExpenseTheme.colorScheme.background,
                                ],
                              ),
                            ),
                          ),
                          expandedTitleScale: 1.2,
                          titlePadding: EdgeInsets.only(
                            top: kToolbarHeight * 1.5,
                          ),
                          title: OverflowBox(
                              maxHeight: 200,
                              child: StreamBuilder(
                                  stream: bloc.totalExpenseController,
                                  builder: (BuildContext context,
                                      AsyncSnapshot<double> snapshot) {
                                    if (snapshot.data == null) {
                                      return SizedBox();
                                    }
                                    return TotalSpentValue(
                                      currency: rupeeSymbol,
                                      value: snapshot.data!,
                                    );
                                  })),
                        ),
                      ),
                      SliverAppBar(
                        pinned: true,
                        floating: false,
                        expandedHeight: 50.0,
                        leading: SizedBox(),
                        // flexibleSpace: ,
                        flexibleSpace: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                for (int i = 0; i < expenseTypes.length; i++)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8.0),
                                    child: Chip(
                                        label: Text(
                                      expenseTypes[i].name,
                                      style: ExpenseTheme.rupeeStyle,
                                    )),
                                  ),
                                Expanded(child: SizedBox()),
                                Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: IconButton(
                                      icon: Icon(
                                          isReversed ? Icons.sort : Icons.list,
                                          color:
                                              ExpenseTheme.colorScheme.primary),
                                      onPressed: () {
                                        expenses = snapshot.data!;
                                        isReversed = !isReversed;
                                        bloc.expenseListStreamSink
                                            .add(expenses.reversed.toList());
                                      }),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (snapshot.data!.isEmpty)
                        SliverToBoxAdapter(
                          child: Center(
                              child: Text(
                                  emptyListMessage[Random()
                                      .nextInt(emptyListMessage.length)],
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 16))),
                        )
                      else
                        SliverList(
                            delegate: SliverChildBuilderDelegate(
                          (BuildContext context, int index) {
                            bool isSameDate = true;
                            final list = snapshot.data!.reversed.toList();
                            final item = list[index];
                            if (index == 0) {
                              isSameDate = false;
                            } else {
                              final prevItem = list[index - 1];
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
                                    model: list[index],
                                    controller: _animationController,
                                    durationInMilliSeconds: animationDuration,
                                    index: index,
                                  ),
                                ],
                              );
                            } else {
                              return ExpenseListTile(
                                model: list[index],
                                controller: _animationController,
                                durationInMilliSeconds: animationDuration,
                                index: index,
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
  final double value;
  final String currency;
  final double fontSize;
  final bool hasLabel;
  final Color? color;
  const TotalSpentValue(
      {Key? key,
      required this.value,
      required this.currency,
      this.hasLabel = true,
      this.color,
      this.fontSize = 25.0})
      : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        RichText(
            text: TextSpan(
                style: TextStyle(
                    color: ExpenseTheme.isDarkTheme(context)
                        ? color ?? Colors.white
                        : color ?? Colors.black,
                    fontWeight: FontWeight.w500),
                children: [
              TextSpan(text: '$currency ', style: ExpenseTheme.rupeeStyle),
              TextSpan(
                  text: '${value.toString()}',
                  style: ExpenseTheme.inputTextStyle),
            ])),
        hasLabel
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  "Total Spent",
                  style: TextStyle(
                      fontSize: 18,
                      color: ExpenseTheme.isDarkTheme(context)
                          ? Colors.white
                          : Colors.black),
                ),
              )
            : SizedBox(),
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
