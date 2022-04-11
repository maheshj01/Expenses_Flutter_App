import 'dart:math';

import 'package:expense_manager/constants/exports.dart';
import 'package:expense_manager/model/spend.dart';
import 'package:expense_manager/widgets/bottom_sheet.dart';
import 'package:expense_manager/widgets/drawer.dart';
import 'package:expense_manager/widgets/expense_list_tile.dart';
import 'package:flutter/material.dart';
import 'package:expense_manager/blocs/expense_bloc.dart';
import 'package:expense_manager/model/model.dart';

class ExpensePage extends StatefulWidget {
  @override
  _ExpensePageState createState() => _ExpensePageState();
}

// final bloc = ExpenseBloc();
final bloc = ExpenseBloc();
final TextEditingController amountController = new TextEditingController();
final TextEditingController descriptionController = TextEditingController();
final TextEditingController labelController = TextEditingController();
// final pdf = document.Document();

class _ExpensePageState extends State<ExpensePage>
    with TickerProviderStateMixin {
  Future _getExpenseDetails() {
    return showModalBottomSheet(
        isScrollControlled: true,
        context: context,
        shape: RoundedRectangleBorder(
          //the rounded corner is created here
          borderRadius: BorderRadius.only(
              topLeft: Radius.circular(14.0), topRight: Radius.circular(14.0)),
        ),
        builder: (BuildContext builder) {
          return EmBottomSheet(
            onSubmit: (Spend spend) {
              bloc.expenseModelStreamSink.add(Expense.withFields(
                  DateTime.now(),
                  spend.value,
                  spend.description,
                  spend.type.name.capitalize(),
                  spend.label,
                  0.0,
                  false));
            },
          );
        });
  }

  Future<void> onFilterTap(String x) async {
    if (!selectedLabels.contains(x)) {
      setState(() {
        selectedLabels.add(x);
      });
    } else {
      setState(() {
        selectedLabels.remove(x);
      });

      /// no labels were selected
      if (selectedLabels.isEmpty) {
        bloc.loadTheExpenses();
        return;
      }
    }
    final expenses = await bloc.getExpenses();
    List<Expense> filteredList = [];
    expenses.forEach((expense) {
      final expenseLabels = expense.label!.split(',').toList();
      bool areAllTileLabelsPresent = true;
      expenseLabels.forEach((label) {
        if (selectedLabels.contains(label)) {
          filteredList.add(expense);
        }
        ;
      });
    });
    bloc.loadTheExpenses(expenses: filteredList);
    bloc.updateTotalFromList(expenses: filteredList);
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
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _animationController = AnimationController(
        vsync: this, duration: Duration(milliseconds: totalDuration));
  }

  List<String> selectedLabels = [];

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
                                              selectedlabels: selectedLabels,
                                              color: ExpenseTheme
                                                  .colorScheme.primary
                                                  .withOpacity(0.4),
                                              onTap: (x) async =>
                                                  onFilterTap(x));
                                    })),
                            Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: IconButton(
                                  icon: Icon(
                                      isReversed ? Icons.sort : Icons.list,
                                      color: ExpenseTheme.colorScheme.primary),
                                  onPressed: () {
                                    expenses = expenseSnapshot.data!;
                                    isReversed = !isReversed;
                                    bloc.expenseListStreamSink
                                        .add(expenses.reversed.toList());
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
