import 'dart:math';

import 'package:expense_manager/constants/exports.dart';
import 'package:expense_manager/model/filter.dart';
import 'package:expense_manager/model/spend.dart';
import 'package:expense_manager/widgets/expense_sheet.dart';
import 'package:expense_manager/widgets/drawer.dart';
import 'package:expense_manager/widgets/expense_list_tile.dart';
import 'package:expense_manager/widgets/filter_sheet.dart';
import 'package:expense_manager/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:expense_manager/blocs/expense_bloc.dart';
import 'package:expense_manager/model/model.dart';

class ExpensePage extends StatefulWidget {
  @override
  _ExpensePageState createState() => _ExpensePageState();
}

final bloc = ExpenseBloc();
final TextEditingController amountController = new TextEditingController();
final TextEditingController descriptionController = TextEditingController();
final TextEditingController labelController = TextEditingController();

class _ExpensePageState extends State<ExpensePage>
    with TickerProviderStateMixin {
  Future<void> _getExpenseDetails() async {
    // final double value = Random().nextDouble() * 1000;
    // bloc.expenseModelStreamSink.add(Expense.withFields(
    //     DateTime(2022, 2, 1, 1, 1, 1),
    //     double.parse((Random().nextDouble() * 1000).toStringAsFixed(2)),
    //     'I am a description for expense.',
    //     SpendType.once.name.capitalize(),
    //     'food',
    //     value,
    //     false));
    showEMBottomSheet(context, ExpenseSheet(
      onSubmit: (Spend spend) {
        bloc.expenseModelStreamSink.add(Expense.withFields(
            DateTime(2022, 1, 1, 1, 1, 1),
            spend.value,
            spend.description,
            spend.type.name.capitalize(),
            spend.label,
            0.0,
            false));
      },
    ));
  }

  Future<void> _showFilterSheet({Function(FilterModel)? onFilter}) async {
    showEMBottomSheet(context,
        FilterSheet(filter: filter, onFilterChange: (x) => onFilter!(x)));
  }

  @override
  void dispose() {
    _animationController.dispose();
    amountController.dispose();
    descriptionController.dispose();
    bloc.dispose();
    super.dispose();
  }

  late AnimationController _animationController;
  double animationDuration = 0.0;
  int totalItems = 6;
  final int totalDuration = 6000;
  FilterModel filter = FilterModel(labels: [], sortByDate: true);
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _animationController = AnimationController(
        vsync: this, duration: Duration(milliseconds: totalDuration));
  }

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
                  AsyncSnapshot<List<Expense>> expenseSnapshot) {
                if (expenseSnapshot.data == null)
                  return Center(child: CircularProgressIndicator());
                else {
                  totalItems = expenseSnapshot.data!.length;
                  animationDuration = totalItems / 100; // in seconds
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
                                colors: ExpenseTheme.isDarkTheme(context)
                                    ? [
                                        ExpenseTheme.darkColorScheme.surface,
                                        ExpenseTheme.darkColorScheme.background,
                                      ]
                                    : [
                                        ExpenseTheme.lightColorScheme.surface,
                                        ExpenseTheme
                                            .lightColorScheme.background,
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
                                      AsyncSnapshot<double> totalSnapshot) {
                                    if (totalSnapshot.data == null) {
                                      return SizedBox();
                                    }
                                    return TotalSpentValue(
                                      currency: rupeeSymbol,
                                      value: totalSnapshot.data!,
                                    );
                                  })),
                        ),
                      ),
                      SliverAppBar(
                        pinned: true,
                        leading: SizedBox(),
                        titleSpacing: 0,
                        toolbarHeight: 0,
                        flexibleSpace: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(child: SizedBox()),
                            Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: IconButton(
                                  icon: Icon(Icons.sort,
                                      color: ExpenseTheme.colorScheme.primary),
                                  onPressed: () {
                                    _showFilterSheet(onFilter: (x) async {
                                      expenses = await bloc.getExpenses();
                                      List<Expense> filteredList = [];
                                      if (x.labels.isEmpty) {
                                        bloc.loadTheExpenses(
                                            filteredList: expenses);
                                        filteredList = expenses;
                                      } else {
                                        expenses.forEach((expense) {
                                          final expenseLabels = expense.label!
                                              .split(',')
                                              .toList();
                                          expenseLabels.forEach((label) {
                                            if (x.labels.contains(label) &&
                                                !filteredList
                                                    .containsObject(expense)) {
                                              filteredList.add(expense);
                                            }
                                          });
                                        });
                                      }
                                      if (x.didSortChange) {
                                        if (x.sortByDate) {
                                          filteredList =
                                              filteredList.reversed.toList();
                                        }
                                      }
                                      bloc.loadTheExpenses(
                                          filteredList: filteredList);
                                      setState(() {
                                        filter = x;
                                      });
                                    });
                                  }),
                            ),
                          ],
                        ),
                      ),
                      if (expenseSnapshot.data!.isEmpty)
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
                            final list =
                                expenseSnapshot.data!.reversed.toList();
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
                          childCount: expenseSnapshot.data!.length,
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
