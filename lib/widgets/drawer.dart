import 'package:expense_manager/constants/exports.dart';
import 'package:expense_manager/model/navbar.dart';
import 'package:expense_manager/utils/settings.dart';
import 'package:flutter/material.dart';

class EmDrawer extends StatefulWidget {
  const EmDrawer({Key? key}) : super(key: key);

  @override
  State<EmDrawer> createState() => _EmDrawerState();
}

class _EmDrawerState extends State<EmDrawer> {
  late bool isDark;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance!.addPostFrameCallback((_) {
      navBar = NavbarNotifier();
      navBar.hideBottomNavBar = true;
      isDark = Settings.getTheme == ThemeMode.dark;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance!.addPostFrameCallback((_) {
      navBar.hideBottomNavBar = false;
    });
    super.dispose();
  }

  late NavbarNotifier navBar;

  @override
  Widget build(BuildContext context) {
    return Drawer(
        elevation: 1.5,
        child: Material(
          child: Column(
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
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: <Widget>[
                    ListTile(
                      title:
                          Text('Export File', style: TextStyle(fontSize: 18)),
                      leading: Icon(Icons.shopping_cart),
                      onTap: () {
                        // Update the state of the app
                        // ...
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => ExpensesListPage()));
                      },
                    ),
                    ListTile(
                      title:
                          Text('Create Alert', style: TextStyle(fontSize: 18)),
                      leading: Icon(Icons.add_shopping_cart),
                      onTap: () {},
                    ),
                    ListTile(
                      title: Text("Profile", style: TextStyle(fontSize: 18)),
                      leading: Icon(Icons.person_pin),
                      onTap: () {},
                    ),
                    ListTile(
                      title:
                          Text("Define budget", style: TextStyle(fontSize: 18)),
                      leading: Icon(Icons.account_balance_wallet_outlined),
                      onTap: () {},
                    ),
                  ],
                ),
              ),
              Divider(),
              Container(
                padding: EdgeInsets.only(right: 16),
                alignment: Alignment.centerRight,
                child: IconButton(
                    onPressed: () {
                      if (!isDark) {
                        Settings.setTheme(ThemeMode.dark);
                      } else {
                        Settings.setTheme(ThemeMode.light);
                      }
                      isDark = !isDark;
                      Settings().notify();
                    },
                    icon: Icon(
                      Icons.wb_sunny,
                      color: ExpenseTheme.colorScheme.primary,
                    )),
              ),
              SizedBox(
                height: 50,
              )
            ],
          ),
        ));
  }
}
