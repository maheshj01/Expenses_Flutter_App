import 'package:expense_manager/constants/exports.dart';
import 'package:expense_manager/main.dart';
import 'package:expense_manager/pages/expense_page.dart';
import 'package:flutter/material.dart';

class EmDrawer extends StatefulWidget {
  const EmDrawer({Key? key}) : super(key: key);

  @override
  State<EmDrawer> createState() => _EmDrawerState();
}

class _EmDrawerState extends State<EmDrawer> {
  bool isDark = false;
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
                    // Container(
                    //   child: CircleAvatar(
                    //     child: Container(
                    //       child: Image.network(
                    //           "https://icon-library.com/images/male-user-icon/male-user-icon-13.jpg"),
                    //     ),
                    //   ),
                    // ),
                    Container(
                      child: Text(
                        "Name",
                        style: TextStyle(color: Colors.white, fontSize: 18),
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
                                builder: (context) => ExpensePage()));
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
                  ],
                ),
              ),
              Divider(),
              Container(
                padding: EdgeInsets.only(right: 16),
                alignment: Alignment.centerRight,
                child: IconButton(
                    onPressed: () {
                      if (isDark) {
                        appSettings.setTheme(ThemeMode.dark);
                      } else {
                        appSettings.setTheme(ThemeMode.light);
                      }
                      isDark = !isDark;
                    },
                    icon: Icon(
                      Icons.wb_sunny,
                      color: ExpenseTheme.colorScheme.primary,
                    )),
              ),
              // Switch(
              //     value: appSettings.getTheme == ThemeMode.dark,
              //     onChanged: (isDark) {
              //       if (isDark) {
              //         appSettings.setTheme(ThemeMode.dark);
              //       } else {
              //         appSettings.setTheme(ThemeMode.light);
              //       }
              //     }),
              SizedBox(
                height: 50,
              )
            ],
          ),
        ));
  }
}
