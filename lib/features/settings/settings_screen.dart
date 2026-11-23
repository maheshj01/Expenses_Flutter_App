import 'package:flutter/material.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/account_deletion.dart';
import '../../app/providers.dart';
import '../../app/shell.dart';
import '../../app/social_providers.dart';
import '../../app/support.dart';
import '../../app/theme.dart';
import '../../data/sync/sync_status.dart';
import '../../domain/social/social_backend.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/currency_picker.dart';
import '../categories/categories_screen.dart';
import '../data_io/export_sheet.dart';
import '../data_io/import_screen.dart';
import '../home/budget_dialog.dart';
import '../onboarding/onboarding_flow.dart';
import '../people/safety_sheets.dart';
import '../people/saved_guests_sheet.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _pickCurrency(BuildContext context, WidgetRef ref) async {
    final settings = ref.read(settingsProvider);
    final code = await showCurrencyPicker(context, current: settings.currencyCode);
    if (code != null) {
      await ref.read(settingsProvider.notifier).update(settings.copyWith(currencyCode: code));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final money = ref.watch(moneyFormatProvider);
    final categoryCount = ref.watch(activeCategoriesProvider).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 60),
        children: [
          const SectionHeader('Account'),
          const _AccountCard(),
          const SectionHeader('Sync'),
          const _SyncCard(),
          const SectionHeader('Money'),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                _Item(
                  icon: Icons.flag_outlined,
                  title: 'Plan & goals',
                  value: settings.hasIncome
                      ? '${money.whole(settings.monthlyIncomeCents)}/mo'
                      : 'Set up',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const OnboardingFlow(editing: true)),
                  ),
                ),
                const Divider(indent: 56),
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
                  title: 'People not on the app',
                  value: switch (settings.savedGuests.length) {
                    0 => 'None',
                    1 => settings.savedGuests.first,
                    final n => '$n people',
                  },
                  onTap: () => showSavedGuestsSheet(context),
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
          const SectionHeader('Your data'),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                _Item(
                  icon: Icons.upload_file_rounded,
                  title: 'Import from a spreadsheet',
                  value: '.xlsx, .csv',
                  onTap: () =>
                      Navigator.of(context)
                          .push(MaterialPageRoute<void>(builder: (_) => const ImportScreen())),
                ),
                const Divider(indent: 56),
                _Item(
                  icon: Icons.ios_share_rounded,
                  title: 'Export to a spreadsheet',
                  value: 'Email',
                  onTap: () => showExportSheet(context),
                ),
              ],
            ),
          ),
          if (Support.email.isNotEmpty || Support.privacyPolicyUrl.isNotEmpty) ...[
            const SectionHeader('Help'),
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  if (Support.email.isNotEmpty)
                    _Item(
                      icon: Icons.mail_outline_rounded,
                      title: 'Contact support',
                      value: 'Email',
                      onTap: () => _contactSupport(context),
                    ),
                  if (Support.email.isNotEmpty && Support.privacyPolicyUrl.isNotEmpty)
                    const Divider(indent: 56),
                  if (Support.privacyPolicyUrl.isNotEmpty)
                    _Item(
                      icon: Icons.privacy_tip_outlined,
                      title: 'Privacy policy',
                      value: '',
                      onTap: () => launchUrl(Uri.parse(Support.privacyPolicyUrl)),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

Future<void> _contactSupport(BuildContext context) async {
  try {
    await FlutterEmailSender.send(const Email(recipients: [Support.email], subject: 'Three Bucks'));
  } catch (_) {
    // No mail account set up: fall back to a mailto: link, then to the address.
    final opened = await launchUrl(Uri(scheme: 'mailto', path: Support.email));
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Email us at ${Support.email}')));
    }
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
              if (status.pendingCount > 0 && status.phase != SyncPhase.localOnly)
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

/// Who you're signed in as for sharing, with sign out and delete.
class _AccountCard extends ConsumerWidget {
  const _AccountCard();

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete your account?'),
        content: const Text(
          'Your account, username, connections and online backup are deleted '
          'and can’t be recovered. Bills already shared stay visible to the '
          'others on them. Everything you track stays on this device.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: context.colors.warn),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await deleteAccountAndData(
        sync: ref.read(syncEngineProvider),
        social: ref.read(socialBackendProvider)!,
      );
    } on SignInCancelled {
      // Backed out of confirming who they are; nothing was deleted.
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final backend = ref.watch(socialBackendProvider);
    final account = ref.watch(accountProvider).value;
    final profile = ref.watch(myProfileProvider).value;
    if (backend == null) {
      return const AppCard(
        child: Text('Sharing is off in this build, so there is no account to sign in to.'),
      );
    }
    if (account == null) {
      return AppCard(
        child: Row(
          children: [
            Icon(Icons.person_outline_rounded, color: c.ink2),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Not signed in. You only need an account to split bills with people.'),
            ),
            TextButton(
              onPressed: () {
                ref.read(shellTabProvider.notifier).select(peopleTabIndex);
                Navigator.of(context).popUntil((r) => r.isFirst);
              },
              child: const Text('Set up'),
            ),
          ],
        ),
      );
    }
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.verified_user_outlined, color: c.lived),
            title: Text(profile == null ? 'Signed in' : '@${profile.handle}'),
            subtitle: Text(
              'with ${account.method.label}${account.email == null ? '' : ' · ${account.email}'}',
            ),
          ),
          const Divider(indent: 56),
          ListTile(
            leading: Icon(Icons.block_rounded, color: c.ink2),
            title: const Text('Blocked people'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${ref.watch(blockedProvider).value?.length ?? 0}',
                  style: TextStyle(color: c.muted),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded, color: c.muted),
              ],
            ),
            onTap: () =>
                Navigator.of(context)
                    .push(MaterialPageRoute<void>(builder: (_) => const BlockedPeopleScreen())),
          ),
          const Divider(indent: 56),
          ListTile(
            leading: Icon(Icons.logout_rounded, color: c.ink2),
            title: const Text('Sign out'),
            subtitle: const Text('What you track stays on this device'),
            onTap: backend.signOut,
          ),
          const Divider(indent: 56),
          ListTile(
            leading: Icon(Icons.delete_outline_rounded, color: c.warn),
            title: Text('Delete account', style: TextStyle(color: c.warn)),
            onTap: () => _deleteAccount(context, ref),
          ),
        ],
      ),
    );
  }
}
