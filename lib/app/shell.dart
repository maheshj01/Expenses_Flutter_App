import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/entries/activity_screen.dart';
import '../features/entries/entry_editor_sheet.dart';
import '../features/history/history_screen.dart';
import '../features/home/home_screen.dart';
import '../features/settings/settings_screen.dart';
import 'providers.dart';
import 'theme.dart';

class ShellTab {
  const ShellTab(this.label, this.icon, this.selectedIcon, this.screen);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget screen;
}

final shellTabs = <ShellTab>[
  ShellTab(
    'Home',
    Icons.home_outlined,
    Icons.home_rounded,
    Consumer(
      builder: (context, ref, _) =>
          HomeScreen(onSeeAll: () => ref.read(shellTabProvider.notifier).select(1)),
    ),
  ),
  const ShellTab(
    'Activity',
    Icons.receipt_long_outlined,
    Icons.receipt_long_rounded,
    ActivityScreen(),
  ),
  const ShellTab('History', Icons.bar_chart_outlined, Icons.bar_chart_rounded, HistoryScreen()),
  const ShellTab('Settings', Icons.settings_outlined, Icons.settings_rounded, SettingsScreen()),
];

/// Bottom navigation with the big "add" button in the middle.
class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final index = ref.watch(shellTabProvider).clamp(0, shellTabs.length - 1);
    final half = (shellTabs.length / 2).ceil();

    Widget item(int i) {
      final tab = shellTabs[i];
      final selected = i == index;
      return Expanded(
        child: InkResponse(
          onTap: () => ref.read(shellTabProvider.notifier).select(i),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(selected ? tab.selectedIcon : tab.icon, color: selected ? c.ink : c.muted),
              const SizedBox(height: 2),
              Text(
                tab.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: selected ? c.ink : c.muted,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: IndexedStack(index: index, children: [for (final t in shellTabs) t.screen]),
      floatingActionButton: FloatingActionButton.large(
        tooltip: 'Add entry',
        onPressed: () => showEntryEditor(context),
        child: const Icon(Icons.add_rounded, size: 32),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        color: c.card,
        surfaceTintColor: Colors.transparent,
        height: 68,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: Row(
          children: [
            for (var i = 0; i < half; i++) item(i),
            const SizedBox(width: 96),
            for (var i = half; i < shellTabs.length; i++) item(i),
            if (shellTabs.length.isOdd) const Spacer(),
          ],
        ),
      ),
    );
  }
}
