import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/sync/sync_status.dart';
import '../../shared/widgets/app_card.dart';
import '../categories/categories_screen.dart';
import '../home/budget_dialog.dart';

const _currencies = {
  'USD': 'US Dollar',
  'INR': 'Indian Rupee',
  'EUR': 'Euro',
  'GBP': 'British Pound',
  'CAD': 'Canadian Dollar',
  'AUD': 'Australian Dollar',
  'SGD': 'Singapore Dollar',
  'AED': 'UAE Dirham',
  'JPY': 'Japanese Yen',
};

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _pickCurrency(BuildContext context, WidgetRef ref) async {
    final settings = ref.read(settingsProvider);
    final code = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => ListView(
        shrinkWrap: true,
        children: [
          for (final MapEntry(key: code, value: name) in _currencies.entries)
            ListTile(
              title: Text(name),
              subtitle: Text(code),
              trailing: code == settings.currencyCode ? const Icon(Icons.check_rounded) : null,
              onTap: () => Navigator.pop(context, code),
            ),
        ],
      ),
    );
    if (code != null) {
      await ref.read(settingsProvider.notifier).update(settings.copyWith(currencyCode: code));
    }
  }

  Future<void> _editSplitWith(BuildContext context, WidgetRef ref) async {
    final settings = ref.read(settingsProvider);
    final controller = TextEditingController(text: settings.splitWith);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Who do you split bills with?'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'e.g. your roommate’s name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name != null) {
      await ref.read(settingsProvider.notifier).update(settings.copyWith(splitWith: name));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final money = ref.watch(moneyFormatProvider);
    final categoryCount = ref.watch(activeCategoriesProvider).length;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 120),
        children: [
          Text('Settings', style: Theme.of(context).textTheme.headlineMedium),
          const SectionHeader('Sync'),
          const _SyncCard(),
          const SectionHeader('Money'),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                _Item(
                  icon: Icons.savings_outlined,
                  title: 'Monthly living budget',
                  value: settings.hasBudget ? money.whole(settings.monthlyBudgetCents) : 'Not set',
                  onTap: () => showBudgetDialog(context, ref),
                ),
                const Divider(indent: 56),
                _Item(
                  icon: Icons.currency_exchange_rounded,
                  title: 'Currency',
                  value: settings.currencyCode,
                  onTap: () => _pickCurrency(context, ref),
                ),
                const Divider(indent: 56),
                _Item(
                  icon: Icons.people_outline_rounded,
                  title: 'Split bills with',
                  value: settings.splitWith.isEmpty ? 'Not set' : settings.splitWith,
                  onTap: () => _editSplitWith(context, ref),
                ),
                const Divider(indent: 56),
                _Item(
                  icon: Icons.category_outlined,
                  title: 'Categories',
                  value: '$categoryCount',
                  onTap: () =>
                      Navigator.of(context)
                          .push(MaterialPageRoute<void>(builder: (_) => const CategoriesScreen())),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({required this.icon, required this.title, required this.value, this.onTap});

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListTile(
      leading: Icon(icon, color: c.ink2),
      title: Text(title),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: TextStyle(color: c.muted)),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, color: c.muted),
        ],
      ),
      onTap: onTap,
    );
  }
}

class _SyncCard extends ConsumerWidget {
  const _SyncCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final status = ref.watch(syncStatusProvider).value;
    if (status == null) return const SizedBox.shrink();

    final (icon, color, title, detail) = switch (status.phase) {
      SyncPhase.localOnly => (
        Icons.phone_iphone_rounded,
        c.ink2,
        'On this device only',
        'Everything works offline. Set up Firebase to back up and sync across devices.',
      ),
      SyncPhase.syncing => (Icons.sync_rounded, c.invested, 'Syncing…', null),
      SyncPhase.offline => (
        Icons.cloud_off_rounded,
        c.warn,
        'Offline',
        'Changes are saved on this device and will sync when you’re back online.',
      ),
      SyncPhase.error => (
        Icons.sync_problem_rounded,
        c.warn,
        'Sync paused',
        status.message ?? 'Will retry shortly.',
      ),
      SyncPhase.idle => (
        Icons.cloud_done_rounded,
        c.lived,
        'Backed up to ${status.backendName}',
        status.lastSyncedAt == null
            ? null
            : 'Last synced ${DateFormat.jm().format(status.lastSyncedAt!)}',
      ),
    };

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
              ),
              if (status.pendingCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: c.warnSoft,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    '${status.pendingCount} pending',
                    style: TextStyle(fontSize: 11.5, color: c.warn, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          if (detail != null) ...[
            const SizedBox(height: 6),
            Text(detail, style: TextStyle(color: c.muted, fontSize: 13)),
          ],
          if (status.phase != SyncPhase.localOnly) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: status.phase == SyncPhase.syncing
                  ? null
                  : () => ref.read(syncEngineProvider).syncNow(),
              icon: const Icon(Icons.sync_rounded, size: 18),
              label: const Text('Sync now'),
            ),
          ],
        ],
      ),
    );
  }
}
