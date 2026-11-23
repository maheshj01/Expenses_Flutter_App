import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/social_providers.dart';
import '../../app/theme.dart';
import '../../domain/social/account.dart';
import '../../domain/social/connection.dart';
import '../../shared/animations/animated_amount.dart';
import '../../shared/animations/fade_slide_in.dart';
import '../../shared/animations/motion.dart';
import '../../shared/money_format.dart';
import '../../shared/widgets/app_card.dart';
import 'account_views.dart';
import 'add_person_sheet.dart';
import 'inbox_screen.dart';
import 'people_widgets.dart';
import 'person_screen.dart';
import 'safety_sheets.dart';

/// The People tab: sign in, pick a username, then everyone you split with.
class PeopleScreen extends ConsumerWidget {
  const PeopleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backend = ref.watch(socialBackendProvider);
    final account = ref.watch(accountProvider);
    final profile = ref.watch(myProfileProvider);

    final Widget body;
    if (backend == null) {
      body = const _Unavailable(key: ValueKey('unavailable'));
    } else if (account.isLoading || (account.value != null && profile.isLoading)) {
      body = const Center(key: ValueKey('loading'), child: CircularProgressIndicator());
    } else if (account.value == null) {
      body = const SignInView(key: ValueKey('sign-in'));
    } else if (profile.value == null) {
      body = const ClaimHandleView(key: ValueKey('claim'));
    } else {
      body = const _PeopleHome(key: ValueKey('people'));
    }

    return SafeArea(
      bottom: false,
      child: AnimatedSwitcher(
        duration: Motion.of(context, Motion.medium),
        switchInCurve: Motion.enter,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.04), end: Offset.zero).animate(animation),
            child: child,
          ),
        ),
        child: body,
      ),
    );
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(18),
    child: AppCard(
      child: EmptyState(
        emoji: '📴',
        title: 'Sharing is off',
        message: 'This build keeps everything on your device. Turn on sync to split bills.',
      ),
    ),
  );
}

class _PeopleHome extends ConsumerStatefulWidget {
  const _PeopleHome({super.key});

  @override
  ConsumerState<_PeopleHome> createState() => _PeopleHomeState();
}

class _PeopleHomeState extends ConsumerState<_PeopleHome> {
  @override
  void initState() {
    super.initState();
    // An invite link opened before signing in waits until now.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _openInvite(ref.read(pendingInviteProvider)),
    );
  }

  void _openInvite(String? handle) {
    if (handle == null || !mounted) return;
    ref.read(pendingInviteProvider.notifier).set(null);
    showAddPersonSheet(context, handle: handle);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(pendingInviteProvider, (_, handle) => _openInvite(handle));
    final c = context.colors;
    final connections = ref.watch(connectionsProvider).value ?? const <Connection>[];
    final friends = ref.watch(friendsProvider);
    final incoming = connections.where((x) => x.isIncomingRequest).toList();
    final outgoing = connections.where((x) => x.isOutgoingRequest).toList();
    final balances = ref.watch(balancesProvider);
    final unsettled = ref.watch(unsettledPeopleProvider);
    final unread = ref.watch(inboxUnreadProvider);
    final currency = ref.watch(settingsProvider.select((s) => s.currencyCode));
    final backend = ref.read(socialBackendProvider)!;
    var i = 0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 120),
      children: [
        Row(
          children: [
            Expanded(child: Text('People', style: Theme.of(context).textTheme.headlineMedium)),
            IconButton(
              tooltip: 'Inbox',
              onPressed: () =>
                  Navigator.of(context)
                      .push(MaterialPageRoute<void>(builder: (_) => const InboxScreen())),
              icon: CountBadge(count: unread, child: const Icon(Icons.inbox_outlined)),
            ),
            IconButton(
              tooltip: 'Add people',
              onPressed: () => showAddPersonSheet(context),
              icon: const Icon(Icons.person_add_alt_rounded),
            ),
          ],
        ),
        const SizedBox(height: 12),
        FadeSlideIn(
          index: i++,
          child: _Totals(
            owedToMe: balances.owedToMe(currency),
            iOwe: balances.iOwe(currency),
            money: MoneyFormat(currency),
          ),
        ),
        if (incoming.isNotEmpty) ...[
          const SectionHeader('Requests'),
          for (final r in incoming)
            FadeSlideIn(
              key: ValueKey(r.id),
              index: i++,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(
                  padding: const EdgeInsets.fromLTRB(14, 6, 4, 10),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          PersonAvatar(r.other),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  r.other.displayName,
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  '@${r.other.handle}',
                                  style: TextStyle(color: c.muted, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          SafetyMenuButton(person: r.other, icon: Icons.more_horiz_rounded),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => backend.removeConnection(r.id),
                              child: const Text('Decline'),
                            ),
                            const SizedBox(width: 6),
                            FilledButton(
                              style: compactButton,
                              onPressed: () => backend.acceptConnection(r.id),
                              child: const Text('Accept'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
        const SectionHeader('Split with'),
        if (friends.isEmpty)
          FadeSlideIn(
            index: i++,
            child: AppCard(
              child: Column(
                children: [
                  const EmptyState(
                    emoji: '👋',
                    title: 'Add the people you split with',
                    message:
                        'Ask for their username, or share yours. You can split once they accept.',
                  ),
                  FilledButton.icon(
                    onPressed: () => showAddPersonSheet(context),
                    icon: const Icon(Icons.person_add_alt_rounded, size: 18),
                    label: const Text('Add people'),
                  ),
                ],
              ),
            ),
          )
        else
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            child: Column(
              children: [
                for (final (j, f) in friends.indexed) ...[
                  if (j > 0) const Divider(indent: 52),
                  FadeSlideIn(
                    key: ValueKey(f.id),
                    index: i++,
                    child: _PersonRow(person: f.other, balance: balances.withPerson(f.other.uid)),
                  ),
                ],
              ],
            ),
          ),
        if (unsettled.isNotEmpty) ...[
          const SectionHeader('Settle up'),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            child: Column(
              children: [
                for (final (j, u) in unsettled.indexed) ...[
                  if (j > 0) const Divider(indent: 52),
                  FadeSlideIn(
                    key: ValueKey('unsettled-${u.profile.uid}'),
                    index: i++,
                    child: _PersonRow(
                      person: u.profile,
                      balance: u.balance,
                      status: u.blocked ? 'Blocked' : 'Not connected',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
        if (outgoing.isNotEmpty) ...[
          const SectionHeader('Waiting for them'),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            child: Column(
              children: [
                for (final o in outgoing)
                  ListTile(
                    key: ValueKey(o.id),
                    contentPadding: EdgeInsets.zero,
                    leading: PersonAvatar(o.other),
                    title: Text(o.other.displayName),
                    subtitle: Text('@${o.other.handle} · request sent'),
                    trailing: TextButton(
                      onPressed: () => backend.removeConnection(o.id),
                      child: const Text('Cancel'),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Totals extends StatelessWidget {
  const _Totals({required this.owedToMe, required this.iOwe, required this.money});

  final int owedToMe;
  final int iOwe;
  final MoneyFormat money;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget column(String label, int cents, Color color) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Label(label),
          const SizedBox(height: 4),
          AnimatedAmount(
            cents: cents,
            builder: (context, value) => Text(
              money(value),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.6,
                color: cents == 0 ? c.muted : color,
                fontFeatures: tabularFigures,
              ),
            ),
          ),
        ],
      ),
    );
    return AppCard(
      child: Row(
        children: [
          column('Owed to you', owedToMe, c.lived),
          Container(width: 1, height: 40, color: c.line),
          const SizedBox(width: 16),
          column('You owe', iOwe, c.warn),
        ],
      ),
    );
  }
}

/// A connection, or someone you still have to settle up with; [status] is
/// added to the username line for them.
class _PersonRow extends StatelessWidget {
  const _PersonRow({required this.person, required this.balance, this.status});

  final Profile person;
  final Map<String, int> balance;
  final String? status;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final other = person;
    final subtitle = [if (other.handle.isNotEmpty) '@${other.handle}', ?status].join(' · ');
    return InkWell(
      onTap: () =>
          Navigator.of(context)
              .push(MaterialPageRoute<void>(builder: (_) => PersonScreen(person: person))),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Hero(tag: 'person-${other.uid}', child: PersonAvatar(other)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(other.displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(subtitle, style: TextStyle(color: c.muted, fontSize: 13)),
                ],
              ),
            ),
            BalanceText(balance),
          ],
        ),
      ),
    );
  }
}
