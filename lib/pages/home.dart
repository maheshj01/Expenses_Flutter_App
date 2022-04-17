import 'package:expense_manager/model/model.dart';
import 'package:expense_manager/model/navbar.dart';
import 'package:expense_manager/model/spend.dart';
import 'package:expense_manager/pages/expense_page.dart';
import 'package:expense_manager/themes/expense_theme.dart';
import 'package:expense_manager/utils/settings.dart';
import 'package:expense_manager/utils/utils.dart';
import 'package:expense_manager/widgets/animated_indexed_stack.dart';
import 'package:expense_manager/widgets/expense_sheet.dart';
import 'package:expense_manager/widgets/navbar.dart';
import 'package:expense_manager/pages/profile.dart';
import 'package:expense_manager/widgets/widgets_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  final _navBarNotifier = NavbarNotifier();

  void _addScrollListener() {
    _scrollController.addListener(() {
      if (_scrollController.position.userScrollDirection ==
          ScrollDirection.forward) {
        if (_navBarNotifier.hideBottomNavBar) {
          _navBarNotifier.hideBottomNavBar = false;
        }
      } else {
        if (!_navBarNotifier.hideBottomNavBar) {
          _navBarNotifier.hideBottomNavBar = true;
        }
      }
    });
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _scrollController = ScrollController();
    _addScrollListener();
  }

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
        expenseService.expenseModelStreamSink.add(Expense.withFields(
            DateTime.now(),
            spend.value,
            spend.description,
            spend.type.name.capitalize(),
            spend.label,
            0.0,
            false));
      },
    ));
  }

  late ScrollController _scrollController;
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
        animation: _navBarNotifier,
        builder: (context, snapshot) {
          return Stack(children: [
            AnimatedIndexedStack(
              index: _selectedIndex,
              children: [
                ExpensesListPage(
                  scrollController: _scrollController,
                ),
                EmDashboard(),
                Container(
                  color: Colors.blue,
                ),
                EmProfile()
              ],
            ),
            Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: AdaptiveNavBar(
                  index: _selectedIndex,
                  items: [
                    MenuItem(Icons.account_balance_wallet_rounded, 'Expenses'),
                    MenuItem(Icons.dashboard, 'Dashboard'),
                    MenuItem(Icons.people, 'Shared'),
                    MenuItem(Icons.person, 'Profile'),
                  ],
                  isHidden: _navBarNotifier.hideBottomNavBar,
                  onChanged: (x) {
                    setState(() {
                      _selectedIndex = x;
                    });
                  },
                )),
            Positioned(
              bottom: kBottomNavigationBarHeight * 1.4,
              right: 24,
              child: AnimatedOpacity(
                opacity: _selectedIndex == 3 ? 0 : 1,
                duration: Duration(milliseconds: 300),
                child: FloatingActionButton(
                    onPressed: () {
                      if (_selectedIndex == 3) return;
                      _getExpenseDetails();
                    },
                    tooltip: 'Add Expense',
                    child: Text('${Settings.currency.symbol}',
                        style: ExpenseTheme.rupeeStyle.copyWith(
                            fontSize: Settings.currency.symbol.length > 1
                                ? 18
                                : 32))),
              ),
            )
          ]);
        });
  }
}

class EmDashboard extends StatefulWidget {
  const EmDashboard({Key? key}) : super(key: key);

  @override
  State<EmDashboard> createState() => EmDashboardState();
}

class EmDashboardState extends State<EmDashboard> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(children: []),
    );
  }
}
