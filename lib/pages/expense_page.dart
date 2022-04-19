import 'dart:math';

import 'package:expense_manager/model/expense.dart';
import 'package:expense_manager/utils/extensions.dart';
import 'package:flutter/material.dart';
import 'package:expense_manager/constants/exports.dart';
import 'package:expense_manager/model/filter.dart';
import 'package:expense_manager/utils/settings.dart';
import 'package:expense_manager/widgets/widgets.dart';
import 'package:expense_manager/services/expense.dart';

class ExpensesListPage extends StatefulWidget {
  final ScrollController? scrollController;

  const ExpensesListPage({Key? key, this.scrollController}) : super(key: key);

  @override
  _ExpensesListPageState createState() => _ExpensesListPageState();
}

final expenseService = ExpenseService();
final TextEditingController amountController = new TextEditingController();
final TextEditingController descriptionController = TextEditingController();
final TextEditingController labelController = TextEditingController();

class _ExpensesListPageState extends State<ExpensesListPage>
    with TickerProviderStateMixin {
  Future<void> _showFilterSheet({Function(FilterModel)? onFilter}) async {
    showEMBottomSheet(context,
        FilterSheet(filter: filter, onFilterChange: (x) => onFilter!(x)));
  }

  @override
  void dispose() {
    _animationController.dispose();
    amountController.dispose();
    descriptionController.dispose();
    expenseService.dispose();
    super.dispose();
  }

  late AnimationController _animationController;
  double animationDuration = 0.0;
  int totalItems = 6;
  final int totalDuration = 6000;
  FilterModel filter = FilterModel(labels: [], sortByDate: true);
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
        vsync: this, duration: Duration(milliseconds: totalDuration));
    _controller = widget.scrollController ?? ScrollController();
  }

  List<Expense> expenses = [];

  Future<void> applyFilter(FilterModel x,
      {List<Expense>? filteredExpense}) async {
    expenses = filteredExpense ?? await expenseService.getExpenses();
    List<Expense> filteredList = [];
    if (x.labels.isEmpty) {
      expenseService.loadTheExpenses(filteredList: expenses);
      filteredList = expenses;
    } else {
      expenses.forEach((expense) {
        final expenseLabels = expense.labels;
        expenseLabels.forEach((label) {
          if (x.labels.contains(label) &&
              !filteredList.containsObject(expense)) {
            filteredList.add(expense);
          }
        });
      });
    }
    if (x.didSortChange) {
      if (x.sortByDate) {
        filteredList = filteredList.reversed.toList();
      }
    }
    expenseService.loadTheExpenses(filteredList: filteredList);
    setState(() {
      filter = x;
    });
  }

  late ScrollController _controller;
  String expenseByDefault = 'Daily';
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        resizeToAvoidBottomInset: true,
        body: Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: StreamBuilder<List<Expense>>(
              stream: expenseService.expenseListStream,
              builder: (BuildContext context,
                  AsyncSnapshot<List<Expense>> expenseSnapshot) {
                if (expenseSnapshot.data == null)
                  return Center(child: CircularProgressIndicator());
                else {
                  totalItems = expenseSnapshot.data!.length;
                  animationDuration = totalItems / 100; // in seconds
                  _animationController.forward();
                  return CustomScrollView(
                    controller: _controller,
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
                                colors: ExpenseTheme.isDark
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
                                  stream: expenseService.totalExpenseController,
                                  builder: (BuildContext context,
                                      AsyncSnapshot<double> totalSnapshot) {
                                    if (totalSnapshot.data == null) {
                                      return SizedBox();
                                    }
                                    return TotalSpentValue(
                                      currency: Settings.currency.symbol,
                                      value: totalSnapshot.data!,
                                    );
                                  })),
                        ),
                      ),
                      SliverAppBar(
                        pinned: true,
                        leading: SizedBox(),
                        titleSpacing: 0,
                        toolbarHeight: 18,
                        flexibleSpace: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Container(
                                  padding: EdgeInsets.only(left: 16),
                                  width: 150,
                                  child: EmDropdownButton<String>(
                                      items: expenseBy,
                                      onChanged: (x) async {
                                        if (expenseByDefault == x) return;
                                        setState(() {
                                          expenseByDefault = x;
                                        });
                                        final filterExpenses =
                                            await expenseService.getExpenses();
                                        final filteredExpenses = showExpenseFor(
                                            expenseByDefault, filterExpenses);
                                        applyFilter(filter,
                                            filteredExpense: filteredExpenses);
                                      },
                                      dropdownItem: (x) => Text(
                                            x,
                                            style: ExpenseTheme
                                                .textTheme.headline4!
                                                .copyWith(
                                                    fontWeight:
                                                        FontWeight.normal),
                                          ),
                                      value: expenseByDefault),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: IconButton(
                                    icon: Icon(Icons.sort,
                                        color:
                                            ExpenseTheme.colorScheme.primary),
                                    onPressed: () {
                                      _showFilterSheet(onFilter: (x) async {
                                        return applyFilter(x);
                                      });
                                    }),
                              ),
                            ],
                          ),
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
                                  item.dateTime!.isSameDate(prevItem.dateTime!);
                            }
                            if (index == 0 || !(isSameDate)) {
                              return Column(
                                children: [
                                  SizedBox(
                                    height: 12,
                                  ),
                                  Text(item.dateTime!.formatDate()),
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
                    color: ExpenseTheme.isDark
                        ? color ?? Colors.white
                        : color ?? Colors.black,
                    fontWeight: FontWeight.w500),
                children: [
              TextSpan(text: '$currency ', style: ExpenseTheme.rupeeStyle),
              TextSpan(
                  text: '${value.toStringAsFixed(2)}',
                  style: ExpenseTheme.inputTextStyle),
            ])),
        hasLabel
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  "Total Spent",
                  style: TextStyle(
                      fontSize: 18,
                      color: ExpenseTheme.isDark ? Colors.white : Colors.black),
                ),
              )
            : SizedBox(),
      ],
    );
  }
}
