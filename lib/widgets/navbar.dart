import 'package:expense_manager/constants/exports.dart';
import 'package:flutter/material.dart';

class AdaptiveNavBar extends StatefulWidget {
  final bool isDesktop;
  final int index;

  /// defines whether the navabr is hidden or not
  /// This applies only for small screen with bottom navigation bar
  /// For Desktop platforms navbar is always visible
  final bool isHidden;
  final Function(int index)? onChanged;

  const AdaptiveNavBar(
      {Key? key,
      required this.index,
      this.onChanged,
      this.isHidden = false,
      this.isDesktop = false})
      : super(key: key);

  @override
  _AdaptiveNavBarState createState() => _AdaptiveNavBarState();
}

class _AdaptiveNavBarState extends State<AdaptiveNavBar> {
  List<MenuItem> _items = [
    MenuItem(Icons.dashboard, 'Dashboard'),
    MenuItem(Icons.account_balance_wallet_rounded, 'Expenses'),
    MenuItem(Icons.people, 'Shared'),
  ];
  int selectedItem = 0;
//   final NavbarNotifier _navbarNotifier = NavbarNotifier();
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    if (!widget.isDesktop) {
      return ExpNavbar(
        _items,
        isHidden: widget.isHidden,
        index: widget.index,
        onItemTapped: (index) => widget.onChanged!(index),
      );
    } else {
      return NavigationRail(
          backgroundColor: ExpenseTheme.colorScheme.background,
          labelType: NavigationRailLabelType.selected,
          trailing: IconButton(
            icon: Icon(_items.last.iconData),
            onPressed: () {},
          ),
          extended: false,
          onDestinationSelected: (x) => widget.onChanged!(x),
          destinations: _items
              .map((e) => NavigationRailDestination(
                  icon: Icon(e.iconData), label: Text(e.text)))
              .toList(),
          selectedIndex: widget.index);
    }
  }
}

class MenuItem {
  final IconData iconData;
  final String text;
  MenuItem(this.iconData, this.text);
}

/// Bottom navigation bar for mobile/tablets
class ExpNavbar extends StatefulWidget {
  const ExpNavbar(this.menuItems,
      {Key? key,
      required this.onItemTapped,
      required this.index,
      this.isHidden = false})
      : super(key: key);
  final List<MenuItem> menuItems;
  final bool isHidden;
  final int index;
  final Function(int) onItemTapped;

  @override
  _ExpNavbarState createState() => _ExpNavbarState();
}

class _ExpNavbarState extends State<ExpNavbar>
    with SingleTickerProviderStateMixin {
  @override
  void didUpdateWidget(covariant ExpNavbar oldWidget) {
    if (widget.isHidden != isHidden) {
      if (!isHidden) {
        _showBottomNavBar();
      } else {
        _hideBottomNavBar();
      }
      isHidden = !isHidden;
    }
    super.didUpdateWidget(oldWidget);
  }

  void _hideBottomNavBar() {
    _controller.reverse();
    return;
  }

  void _showBottomNavBar() {
    _controller.forward();
    return;
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        duration: const Duration(milliseconds: 500), vsync: this)
      ..addListener(() => setState(() {}));
    animation = Tween(begin: 0.0, end: 100.0).animate(_controller);
  }

  late AnimationController _controller;
  late Animation<double> animation;
  bool isHidden = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
        animation: animation,
        builder: (BuildContext context, Widget? child) {
          return Transform.translate(
            offset: Offset(0, animation.value),
            child: BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              currentIndex: widget.index,
              selectedItemColor: ExpenseTheme.colorScheme.primary,
              onTap: (x) => widget.onItemTapped(x),
              showUnselectedLabels: true,
              unselectedItemColor: ExpenseTheme.colorScheme.onPrimary,
              backgroundColor: ExpenseTheme.colorScheme.surface,
              items: widget.menuItems
                  .map((MenuItem menuItem) => BottomNavigationBarItem(
                        icon: Icon(menuItem.iconData),
                        label: menuItem.text,
                      ))
                  .toList(),
            ),
          );
        });
  }
}
