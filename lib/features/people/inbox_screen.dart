import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/social_providers.dart';
import '../../app/theme.dart';
import '../../domain/social/account.dart';
import '../../domain/social/inbox.dart';
import '../../shared/animations/fade_slide_in.dart';
import '../../shared/animations/motion.dart';
import '../../shared/money_format.dart';
import '../../shared/widgets/app_card.dart';
import 'bill_sheet.dart';
import 'people_widgets.dart';
import 'safety_sheets.dart';

/// Requests, flags, new bills and payments, newest first. Opening it marks
/// everything as read; things that need an answer stay until answered.
class InboxScreen extends ConsumerStatefulWidget {
  const InboxScreen({super.key});

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen> {
  /// When it was last opened before now, to mark what's new.
  late final DateTime _seenBefore = ref.read(inboxSeenProvider);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(inboxSeenProvider.notifier).markSeen(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inbox = ref.watch(inboxProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Inbox')),
      body: inbox.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(18),
              child: AppCard(
                child: EmptyState(
                  emoji: '📭',
                  title: 'All caught up',
                  message: 'Requests, new bills and flags show up here.',
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
              itemCount: inbox.items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final item = inbox.items[i];
                return FadeSlideIn(
                  key: ValueKey(item.key),
                  index: i.clamp(0, 8),
                  child: _InboxTile(item: item, isNew: item.at.isAfter(_seenBefore)),
                );
              },
            ),
    );
  }
}

class _InboxTile extends ConsumerWidget {
  const _InboxTile({required this.item, required this.isNew});

  final InboxItem item;
  final bool isNew;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final backend = ref.read(socialBackendProvider)!;
    final bill = item.bill;
    final person =
        item.connection?.other ??
        bill?.people[item.who] ??
        ref.watch(friendsProvider).where((f) => f.other.uid == item.who).firstOrNull?.other ??
        Profile(uid: item.who, handle: '', name: 'Someone');
    final name = person.displayName;
    final title = bill == null || bill.note.isEmpty ? 'a bill' : '“${bill.note}”';
    final money = MoneyFormat(bill?.currencyCode ?? item.settlement?.currencyCode ?? 'USD');

    final (text, detail) = switch (item.kind) {
      InboxKind.request => ('$name wants to split bills with you', '@${person.handle}'),
      InboxKind.flag => (
        '$name flagged their share of $title',
        '${item.flag!.reason.label}${item.flag!.note.isEmpty ? '' : ' · “${item.flag!.note}”'}',
      ),
      InboxKind.newBill => ('$name added you to $title', 'Your share ${money(bill!.shareCents)}'),
      InboxKind.billUpdated => (
        '$name updated $title',
        'Your share is now ${money(bill!.shareCents)}',
      ),
      InboxKind.settlement => (
        item.settlement!.from == item.who
            ? '$name recorded paying you ${money(item.settlement!.amountCents)}'
            : '$name recorded that you paid ${money(item.settlement!.amountCents)}',
        null,
      ),
    };

    return AppCard(
      padding: const EdgeInsets.all(14),
      color: item.kind == InboxKind.flag ? c.warnSoft : null,
      onTap: bill == null ? null : () => showBillSheet(context, bill.id),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PersonAvatar(person, size: 38),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
                    if (detail != null)
                      Text(detail, style: TextStyle(color: c.muted, fontSize: 13)),
                    const SizedBox(height: 2),
                    Text(_ago(item.at), style: TextStyle(color: c.muted, fontSize: 12)),
                  ],
                ),
              ),
              AnimatedOpacity(
                opacity: isNew || item.needsAction ? 1 : 0,
                duration: Motion.of(context, Motion.medium),
                child: Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 6),
                  decoration: BoxDecoration(
                    color: item.needsAction ? c.warn : c.invested,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
          if (item.kind == InboxKind.request) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => backend.removeConnection(item.connection!.id),
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: () => backend.acceptConnection(item.connection!.id),
                    child: const Text('Accept'),
                  ),
                ),
                SafetyMenuButton(person: item.connection!.other, icon: Icons.more_horiz_rounded),
              ],
            ),
          ],
          if (item.kind == InboxKind.flag) ...[
            const SizedBox(height: 8),
            Text(
              'Edit the bill to fix it, or take $name off it.',
              style: TextStyle(fontSize: 12.5, color: c.ink2),
            ),
          ],
        ],
      ),
    );
  }

  static String _ago(DateTime at) {
    final diff = DateTime.now().difference(at);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat.MMMd().format(at);
  }
}
