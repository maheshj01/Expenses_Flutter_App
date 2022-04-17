import 'package:expense_manager/constants/exports.dart';
import 'package:expense_manager/model/currency.dart';
import 'package:expense_manager/model/navbar.dart';
import 'package:expense_manager/utils/settings.dart';
import 'package:expense_manager/widgets/dropdown.dart';
import 'package:flutter/material.dart';

class EmProfile extends StatefulWidget {
  const EmProfile({Key? key}) : super(key: key);

  @override
  State<EmProfile> createState() => _EmProfileState();
}

class _EmProfileState extends State<EmProfile> {
  late bool isDark;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance!.addPostFrameCallback((_) {
      isDark = Settings.getTheme == ThemeMode.dark;
    });
  }

  @override
  void dispose() {
    // WidgetsBinding.instance!.addPostFrameCallback((_) {
    //   navBar.hideBottomNavBar = false;
    // });
    super.dispose();
  }

  late NavbarNotifier navBar;
  String dropdownValue = 'One';
  @override
  Widget build(BuildContext context) {
    Widget _subtitle(String subtitle) {
      return Text(subtitle, style: TextStyle(fontSize: 18));
    }

    return Material(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          DrawerHeader(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Container(
                    child: CircleAvatar(
                  minRadius: 48,
                  child: Container(
                      child: FlutterLogo(
                    size: 48,
                  )),
                )),
                Container(
                  child: Text(
                    "Flutter",
                    style: ExpenseTheme.textTheme.bodySmall,
                  ),
                  padding: EdgeInsets.only(bottom: 10),
                  alignment: Alignment.bottomCenter,
                ),
              ],
            ),
          ),
          // ListTile(
          //   title: _subtitle('Export File'),
          //   leading: Icon(Icons.shopping_cart),
          //   onTap: () {
          //     // Update the state of the app
          //     // ...
          //     Navigator.push(context,
          //         MaterialPageRoute(builder: (context) => ExpensesListPage()));
          //   },
          // ),
          // ListTile(
          //   title: _subtitle('Create Alert'),
          //   leading: Icon(Icons.add_shopping_cart),
          //   onTap: () {},
          // ),
          // ListTile(
          //   title: _subtitle("Define budget"),
          //   leading: Icon(Icons.account_balance_wallet_outlined),
          //   onTap: () {},
          // ),
          ListTile(
            title: _subtitle('Theme'),
            leading: Icon(Icons.color_lens),
            trailing: ToggleButtons(
                children: const [
                  Text('Light'),
                  Text('Dark'),
                ],
                constraints: const BoxConstraints(minWidth: 80, minHeight: 40),
                onPressed: (int index) {
                  Settings.setTheme(
                      index == 1 ? ThemeMode.dark : ThemeMode.light);
                },
                isSelected: [
                  Settings.getTheme == ThemeMode.light,
                  Settings.getTheme == ThemeMode.dark,
                ]),
            onTap: () {},
          ),
          ListTile(
              leading: Icon(Icons.currency_bitcoin),
              title: _subtitle('Currency'),
              trailing: SizedBox(
                  width: 160,
                  child: EmDropdownButton<Currency>(
                      items: currencyList,
                      onChanged: (newValue) {
                        Settings.setCurrency(newValue);
                      },
                      dropdownItem: (Currency value) => Text(
                            '${value.symbol} ${value.name}',
                            style: ExpenseTheme.textTheme.subtitle2!
                                .copyWith(fontSize: 15),
                          ),
                      value: Settings.currency))),
        ],
      ),
    );
  }
}
