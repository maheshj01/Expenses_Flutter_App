import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/account_flow.dart';
import '../../app/providers.dart';
import '../../app/social_providers.dart';
import '../../app/theme.dart';
import '../../domain/account/account_deletion.dart';
import '../../shared/widgets/app_card.dart';
import 'goodbye_page.dart';
import 'hold_to_confirm.dart';

/// How many entries would go, for the delete page.
final _entryCountProvider = FutureProvider.autoDispose<int>(
  (ref) => ref.watch(entryRepositoryProvider).count(),
);

/// Settings row that opens [DeleteAccountPage]. Named for what it does to
/// this person: a signed-in account is deleted (and restorable for a
/// while); without one there's only this phone's data and its backup to
/// erase.
class DeleteAccountTile extends ConsumerWidget {
  const DeleteAccountTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final signedIn = ref.watch(accountProvider).value != null;
    return ListTile(
      leading: Icon(Icons.delete_outline_rounded, color: c.warn),
      title: Text(signedIn ? 'Delete account' : 'Erase my data', style: TextStyle(color: c.warn)),
      subtitle: Text(
        signedIn
            ? 'Restorable for ${AccountDeletion.graceDays} days'
            : 'Remove everything from this phone and our servers',
      ),
      onTap: () =>
          Navigator.of(context)
              .push(MaterialPageRoute<void>(builder: (_) => const DeleteAccountPage())),
    );
  }
}

/// One calm page that says exactly what goes, whether there is a way back,
/// and asks for a held press before doing it.
class DeleteAccountPage extends ConsumerStatefulWidget {
  const DeleteAccountPage({super.key});

  @override
  ConsumerState<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

/// What the page describes. Frozen once the hold completes: clearing the
/// phone empties the providers underneath while the goodbye fades in, and
/// the page shouldn't change its story mid-fade.
typedef _Subject = ({bool signedIn, String? handle, int entries, String name});

class _DeleteAccountPageState extends ConsumerState<DeleteAccountPage> {
  _Subject? _frozen;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final flow = ref.watch(accountFlowProvider);
    final deleting = flow.status == AccountFlowStatus.deleting || _frozen != null;
    final subject =
        _frozen ??
        (
          signedIn: ref.watch(accountProvider).value != null,
          handle: ref.watch(myProfileProvider).value?.handle,
          entries: ref.watch(_entryCountProvider).value ?? 0,
          name: ref.watch(settingsProvider.select((s) => s.name)),
        );
    final signedIn = subject.signedIn;
    final who = subject.handle == null ? 'your account' : '@${subject.handle}';
    final entries = subject.entries;
    final name = subject.name.trim();
    final restoreBy = DateFormat.yMMMMd().format(
      DateTime.now().add(const Duration(days: AccountDeletion.graceDays)),
    );

    return PopScope(
      canPop: !deleting,
      child: Scaffold(
        backgroundColor: c.background,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(4),
                child: IconButton(
                  icon: Icon(Icons.arrow_back_ios_new, size: 20, color: c.ink),
                  tooltip: 'Back',
                  onPressed: deleting ? null : () => Navigator.of(context).maybePop(),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    const Label('ACCOUNT'),
                    const SizedBox(height: 6),
                    Text(
                      signedIn ? 'Delete your account' : 'Erase your data',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(height: 1.15),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      signedIn
                          ? 'This removes everything from this phone and from your backup as $who.'
                          : 'This removes everything from this phone and from Three Bucks’ servers.',
                      style: TextStyle(fontSize: 15, height: 1.45, color: c.muted),
                    ),
                    const SizedBox(height: 24),
                    const Label('WHAT GOES'),
                    const SizedBox(height: 10),
                    AppCard(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        children: [
                          _Item(
                            icon: Icons.receipt_long_outlined,
                            title: entries == 1 ? '1 entry' : '$entries entries',
                            detail: 'Every expense, split, note and edit',
                          ),
                          _Item(
                            icon: Icons.tune_rounded,
                            title: 'Your plan',
                            detail: name.isEmpty
                                ? 'Categories, budget and goals'
                                : '$name’s categories, budget and goals',
                          ),
                          if (signedIn)
                            _Item(
                              icon: Icons.people_outline_rounded,
                              title: 'Your username',
                              detail: '$who, your connections and the people you blocked',
                            ),
                          _Item(
                            icon: Icons.cloud_outlined,
                            title: signedIn ? 'Your backup' : 'The copy on our servers',
                            detail: signedIn
                                ? 'Everything saved as $who'
                                : 'Kept so it could sync later',
                            last: true,
                          ),
                        ],
                      ),
                    ),
                    if (signedIn) ...[
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          'Bills you shared stay visible to the others on them.',
                          style: TextStyle(fontSize: 12.5, color: c.muted),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    _Note(
                      icon: signedIn ? Icons.history_rounded : Icons.info_outline_rounded,
                      title: signedIn
                          ? '${AccountDeletion.graceDays} days to change your mind'
                          : 'This can’t be undone',
                      body: signedIn
                          ? 'Sign in again before $restoreBy and everything comes back. '
                                'After that, it is gone for good.'
                          : 'You haven’t signed in, so there is no copy to come back to. '
                                'To keep one, export a spreadsheet from Settings first.',
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (flow.message != null && !deleting)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          flow.message!,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: c.warn),
                        ),
                      ),
                    HoldToConfirm(
                      label: signedIn ? 'Hold to delete account' : 'Hold to erase everything',
                      busyLabel: signedIn ? 'Deleting…' : 'Erasing…',
                      color: c.warn,
                      busy: deleting,
                      onConfirmed: () => _delete(subject),
                    ),
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: deleting ? null : () => Navigator.of(context).maybePop(),
                      child: Text(
                        signedIn ? 'Keep my account' : 'Keep my data',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: c.muted),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _delete(_Subject subject) async {
    setState(() => _frozen = subject);
    final outcome = await ref.read(accountFlowProvider.notifier).deleteAccount();
    if (!mounted) return;
    if (outcome == null) {
      // Failed: back to the live page, with the reason shown.
      setState(() => _frozen = null);
      return;
    }
    fadeToFresh(
      context,
      GoodbyePage(
        outcome: outcome,
        signedInAs: subject.handle == null ? null : '@${subject.handle}',
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({required this.icon, required this.title, required this.detail, this.last = false});

  final IconData icon;
  final String title;
  final String detail;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Icon(icon, size: 22, color: c.ink2),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                    Text(detail, style: TextStyle(fontSize: 12.5, color: c.muted)),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!last) const Divider(height: 1, indent: 52, endIndent: 16),
      ],
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: c.livedSoft, borderRadius: BorderRadius.circular(11)),
          child: Icon(icon, size: 20, color: c.lived),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(body, style: TextStyle(fontSize: 13.5, height: 1.4, color: c.muted)),
            ],
          ),
        ),
      ],
    );
  }
}
