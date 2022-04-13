import 'dart:math';

import 'package:expense_manager/constants/exports.dart';
import 'package:expense_manager/model/filter.dart';
import 'package:expense_manager/model/spend.dart';
import 'package:expense_manager/widgets/expense_sheet.dart';
import 'package:expense_manager/widgets/drawer.dart';
import 'package:expense_manager/widgets/expense_list_tile.dart';
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
    //     DateTime(2021, 12, 6, 1, 1, 1),
    //     double.parse((Random().nextDouble() * 1000).toStringAsFixed(2)),
    //     'I am a description for expense.',
    //     SpendType.once.name.capitalize(),
    //     'Shopping',
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

  Future<void> onFilterTap(String x) async {
    if (!filter.labels.contains(x)) {
      setState(() {
        filter.labels.add(x);
      });
    } else {
      setState(() {
        filter.labels.remove(x);
      });

      /// no labels were selected
      if (filter.labels.isEmpty) {
        bloc.loadTheExpenses();
        return;
      }
    }
    final expenses = await bloc.getExpenses();
    List<Expense> filteredList = [];
    expenses.forEach((expense) {
      final expenseLabels = expense.label!.split(',').toList();
      expenseLabels.forEach((label) {
        if (filter.labels.contains(label) &&
            !filteredList.containsObject(expense)) {
          filteredList.add(expense);
        }
        ;
      });
    });
    bloc.loadTheExpenses(filteredList: filteredList);
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
  FilterModel filter = FilterModel(labels: [], sortByNewest: true);
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
                        floating: false,
                        expandedHeight: 50.0,
                        leading: SizedBox(),
                        // flexibleSpace: ,
                        flexibleSpace: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                                child: StreamBuilder<List<String>>(
                                    stream: bloc.labelStream,
                                    builder: (BuildContext context,
                                        AsyncSnapshot<List<String>>
                                            labelSnapshot) {
                                      return labelSnapshot.data == null ||
                                              labelSnapshot.data!.isEmpty
                                          ? SizedBox()
                                          : LabelsFilterWidget(
                                              labels: labelSnapshot.data!,
                                              selectedlabels: filter.labels,
                                              color: ExpenseTheme
                                                  .colorScheme.primary
                                                  .withOpacity(0.4),
                                              onTap: (x) async =>
                                                  onFilterTap(x));
                                    })),
                            Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: IconButton(
                                  icon: Icon(Icons.sort,
                                      color: ExpenseTheme.colorScheme.primary),
                                  onPressed: () {
                                    _showFilterSheet(onFilter: (x) async {
                                      if (x.didSortChange) {
                                        expenses = await bloc.getExpenses();
                                        if (x.sortByNewest) {
                                          bloc.expenseListStreamSink
                                              .add(expenses.reversed.toList());
                                        } else {
                                          bloc.expenseListStreamSink
                                              .add(expenses);
                                        }
                                      }
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

class FilterSheet extends StatefulWidget {
  final FilterModel filter;
  final Function(FilterModel) onFilterChange;
  const FilterSheet(
      {Key? key, required this.onFilterChange, required this.filter})
      : super(key: key);

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  bool isNewest = true;
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    isNewest = widget.filter.sortByNewest;
  }

  @override
  Widget build(BuildContext context) {
    Widget filterTile(String text, {bool isSelected = false}) {
      return InkWell(
          onTap: () {
            setState(() {
              isNewest = text == 'Newest' ? true : false;
            });
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  text,
                  style: ExpenseTheme.textTheme.headline6!.copyWith(
                      fontWeight: isSelected
                          ? ExpenseTheme.bold
                          : ExpenseTheme.semiBold),
                ),
              ),
              isSelected
                  ? Icon(Icons.check, color: Colors.green, size: 24)
                  : SizedBox()
            ],
          ));
    }

    return Padding(
        padding: const EdgeInsets.only(left: 16.0, top: 16, right: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sort by',
              style: ExpenseTheme.textTheme.headline4,
            ),
            SizedBox(
              height: 8,
            ),
            Divider(),
            filterTile('Newest', isSelected: isNewest),
            filterTile('Last Added', isSelected: !isNewest),
            Divider(),
            SizedBox(
              height: 150,
            ),
            Row(children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.filter.didSortChange =
                        widget.filter.sortByNewest != isNewest;
                    widget.filter.sortByNewest = isNewest;
                    widget.onFilterChange(widget.filter);
                  },
                  child: Text('Apply'),
                ),
              ),
              SizedBox(
                width: 8,
              ),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text('Cancel'),
                ),
              ),
            ]),
          ],
        ));
  }
}

class LabelsFilterWidget extends StatelessWidget {
  const LabelsFilterWidget(
      {Key? key,
      this.onTap,
      this.color,
      required this.labels,
      required this.selectedlabels})
      : super(key: key);
  final Function(String)? onTap;
  final Color? color;
  final List<String> labels;
  final List<String> selectedlabels;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      itemCount: labels.length,
      scrollDirection: Axis.horizontal,
      itemBuilder: (_, x) {
        final label = labels[x];
        bool isSelected = selectedlabels.contains(label);
        return InkWell(
          onTap: () => onTap!(label),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Chip(
                backgroundColor: isSelected
                    ? color!.withOpacity(1.0)
                    : color!.withOpacity(0.4),
                label: Text(
                  label,
                  style: ExpenseTheme.rupeeStyle,
                )),
          ),
        );
      },
    );
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
  EmIcon(this.iconData, {Key? key, required this.onTap, this.size = 40})
      : super(key: key);
  final IconData iconData;
  final Function onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(10),
      child: IconButton(
          icon: Icon(iconData),
          iconSize: size,
          color: Colors.white,
          onPressed: () => onTap()),
    );
  }
}
