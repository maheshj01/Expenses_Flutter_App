import 'package:expense_manager/constants/exports.dart';
import 'package:expense_manager/model/model.dart';
import 'package:flutter/material.dart';

class ExpenseListTile extends StatefulWidget {
  ExpenseListTile(
      {Key? key,
      required this.index,
      required this.model,
      required this.controller,
      required this.durationInMilliSeconds})
      : super(key: key);

  final AnimationController controller;
  final double durationInMilliSeconds;
  Expense model;
  final int index;

  @override
  State<ExpenseListTile> createState() => _ExpenseListTileState();
}

class _ExpenseListTileState extends State<ExpenseListTile> {
  late Animation<Offset> _animation;
  late double start;
  late double end;
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    start = (widget.durationInMilliSeconds * widget.index).toDouble() * 0.2;
    end = start + widget.durationInMilliSeconds;
    _animation = Tween<Offset>(
      begin: Offset(0.0, 2.0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: widget.controller,
        curve: Interval(
          start,
          end,
          curve: Curves.easeIn,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
        animation: _animation,
        builder: (context, snapshot) {
          List<String> labels = [];
          if (!widget.model.label!.isEmpty) {
            labels = widget.model.label!.split(',').toList();
          }
          return SlideTransition(
            position: _animation,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: ExpenseTheme.isDarkTheme(context)
                    ? ExpenseTheme.darkColorScheme.surface
                    : ExpenseTheme.lightColorScheme.primary,
              ),
              height: 120,
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: EdgeInsets.only(left: 10, right: 5),
                          child: Text(
                            widget.model.description!,
                            textAlign: TextAlign.justify,
                            style: TextStyle(
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ),
                        labels.isEmpty
                            ? SizedBox()
                            : Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Row(
                                  children: [
                                    for (int i = 0; i < labels.length; i++)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 4.0),
                                        child:
                                            Chip(label: Text('${labels[i]}')),
                                      )
                                  ],
                                ),
                              )
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 8,
                  ),
                  TotalSpentValue(
                    currency: rupeeSymbol,
                    value: widget.model.amount!,
                    hasLabel: false,
                    color: ExpenseTheme.darkColorScheme.primary,
                  )
                ],
              ),
            ),
          );
        });
  }
}
