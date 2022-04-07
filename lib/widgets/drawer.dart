import 'package:expense_manager/pages/expense_page.dart';
import 'package:flutter/material.dart';

class EmDrawer extends StatefulWidget {
  const EmDrawer({Key? key}) : super(key: key);

  @override
  State<EmDrawer> createState() => _EmDrawerState();
}

class _EmDrawerState extends State<EmDrawer> {
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
                        child: Container(
                          child: Image.network(
                              "https://icon-library.com/images/male-user-icon/male-user-icon-13.jpg"),
                        ),
                      ),
                    ),
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
                  // Important: Remove any padding from the ListView.
                  padding: EdgeInsets.zero,
                  children: <Widget>[
                    ListTile(
                      title: Text('Export File',
                          style: TextStyle(color: Colors.white, fontSize: 18)),
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
                      title: Text('Create Alert',
                          style: TextStyle(color: Colors.white, fontSize: 18)),
                      leading: Icon(Icons.add_shopping_cart),
                      onTap: () {},
                    ),
                    ListTile(
                      title: Text("Profile",
                          style: TextStyle(color: Colors.white, fontSize: 18)),
                      leading: Icon(Icons.person_pin),
                      onTap: () {},
                    ),
                  ],
                ),
              ),
              Container(
                color: Colors.black,
                width: double.infinity,
                height: 0.1,
              ),
            ],
          ),
        ));
  }
}
