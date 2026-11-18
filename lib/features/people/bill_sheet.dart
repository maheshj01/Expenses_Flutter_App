import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../app/social_providers.dart';
import '../../app/theme.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/ledger_entry.dart';
import '../../domain/social/account.dart';
import '../../domain/social/shared_bill.dart';
import '../../shared/animations/fade_slide_in.dart';
import '../../shared/animations/motion.dart';
import '../../shared/money_format.dart';
import '../../shared/widgets/category_avatar.dart';
import '../entries/entry_editor_sheet.dart';
import 'people_widgets.dart';
import 'split_picker_sheet.dart';

/// Details of a shared bill. The payer can edit it, delete it or take
/// someone off it; everyone else can flag their own share.
Future<void> showBillSheet(BuildContext context, String billId) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => BillSheet(billId: billId),
  );
}

class BillSheet extends ConsumerWidget {
  const BillSheet({super.key, required this.billId});

  final String billId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final bill = ref.watch(billMapProvider)[billId];
    final me = ref.watch(accountProvider).value?.uid;
    if (bill == null || me == null || bill.deleted) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('This bill isn’t shared with you any more.')),
      );
    }
    final money = MoneyFormat(bill.currencyCode);
    final mine = bill.createdBy == me;
    final cats = ref.watch(categoryMapProvider);
    final myFlag = bill.flags[me];

    String who(String uid) => uid == me ? 'You' : bill.nameOf(uid);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              CategoryAvatar(cats[bill.categoryId], size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bill.note.isEmpty
                          ? (cats[bill.categoryId]?.name ?? 'Shared bill')
                          : bill.note,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '${mine ? 'You paid' : '${who(bill.createdBy)} paid'} · '
                      '${DateFormat.yMMMd().format(bill.date)}',
                      style: TextStyle(color: c.muted, fontSize: 13),
                    ),
                  ],
                ),
              ),
              AnimatedSwitcher(
                duration: Motion.of(context, Motion.medium),
                child: bill.isDisputed ? const DisputedTag() : const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            money(bill.amountCents),
            style: const TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w600,
              letterSpacing: -1.5,
              fontFeatures: tabularFigures,
            ),
          ),
          Text(
            'Split ${bill.ways} ways · ${money(bill.shareCents)} each',
            style: TextStyle(color: c.lived, fontWeight: FontWeight.w600),
          ),
          if (bill.memo.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: c.sunk, borderRadius: BorderRadius.circular(14)),
              child: Text('“${bill.memo}” — ${who(bill.createdBy)}'),
            ),
          ],
          const SizedBox(height: 16),
          for (final (i, uid) in bill.members.indexed)
            FadeSlideIn(
              index: i,
              child: _MemberRow(
                bill: bill,
                uid: uid,
                me: me,
                money: money,
                onRemove: mine && uid != me ? () => _remove(context, ref, bill, uid) : null,
              ),
            ),
          if (bill.guests > 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '+ ${bill.guestNames.isEmpty ? bill.guests : describeSplit(bill.guestNames, bill.guests - bill.guestNames.length)} '
                'not on the app · ${money(bill.shareCents * bill.guests)}',
                style: TextStyle(color: c.muted),
              ),
            ),
          const SizedBox(height: 16),
          if (mine) ...[
            FilledButton.icon(
              onPressed: () => _edit(context, ref, bill),
              icon: const Icon(Icons.edit_rounded, size: 18),
              label: Text(bill.isDisputed ? 'Edit to resolve' : 'Edit bill'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => _delete(context, ref, bill),
              style: TextButton.styleFrom(foregroundColor: c.warn),
              child: const Text('Delete bill'),
            ),
          ] else ...[
            _CategoryRow(billId: bill.id),
            const SizedBox(height: 8),
            AnimatedSwitcher(
              duration: Motion.of(context, Motion.medium),
              child: myFlag == null
                  ? OutlinedButton.icon(
                      key: const ValueKey('flag'),
                      onPressed: () => showFlagSheet(context, bill),
                      icon: const Icon(Icons.flag_outlined, size: 18),
                      label: const Text('Flag my share'),
                    )
                  : _MyFlagCard(
                      key: const ValueKey('flagged'),
                      flag: myFlag,
                      payer: who(bill.createdBy),
                      onWithdraw: () => ref.read(socialBackendProvider)!.setFlag(bill.id, null),
                    ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, SharedBill bill) async {
    final entry = await ref.read(entryRepositoryProvider).byId(bill.id);
    if (!context.mounted) return;
    Navigator.of(context).pop();
    await showEntryForm(
      context,
      entry:
          entry ??
          LedgerEntry(
            id: bill.id,
            amountCents: bill.amountCents,
            categoryId: bill.categoryId,
            date: bill.date,
            note: bill.note,
            splitWays: bill.ways,
            billId: bill.id,
            createdAt: bill.createdAt,
          ),
    );
  }

  Future<void> _remove(BuildContext context, WidgetRef ref, SharedBill bill, String uid) async {
    final ok = await _confirm(
      context,
      'Take ${bill.nameOf(uid)} off this bill?',
      'It will be split between the rest of you.',
      'Remove',
    );
    if (!ok) return;
    final members = [...bill.members]..remove(uid);
    await ref
        .read(socialBackendProvider)!
        .saveBill(
          bill.copyWith(
            members: members,
            people: {...bill.people}..remove(uid),
            flags: {...bill.flags}..remove(uid),
            editedAt: DateTime.now(),
          ),
        );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, SharedBill bill) async {
    final ok = await _confirm(
      context,
      'Delete this bill?',
      'It disappears for everyone on it, and from your spending.',
      'Delete',
    );
    if (!ok) return;
    await ref
        .read(socialBackendProvider)!
        .saveBill(bill.copyWith(deleted: true, editedAt: DateTime.now()));
    await ref.read(entryRepositoryProvider).delete(bill.id);
    if (context.mounted) Navigator.of(context).pop();
  }
}

Future<bool> _confirm(BuildContext context, String title, String message, String action) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(context, true), child: Text(action)),
      ],
    ),
  );
  return ok ?? false;
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.bill,
    required this.uid,
    required this.me,
    required this.money,
    this.onRemove,
  });

  final SharedBill bill;
  final String uid;
  final String me;
  final MoneyFormat money;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final flag = bill.flags[uid];
    final payer = uid == bill.createdBy;
    final name = uid == me ? 'You' : bill.nameOf(uid);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PersonAvatar(bill.people[uid] ?? Profile(uid: uid, handle: '', name: name), size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                AnimatedSwitcher(
                  duration: Motion.of(context, Motion.medium),
                  child: flag == null
                      ? Text(
                          payer ? 'paid' : 'owes ${money(bill.shareCents)}',
                          key: const ValueKey('ok'),
                          style: TextStyle(color: c.muted, fontSize: 13),
                        )
                      : Text(
                          '🚩 ${flag.reason.label}${flag.note.isEmpty ? '' : ' · “${flag.note}”'}',
                          key: const ValueKey('flag'),
                          style: TextStyle(color: c.warn, fontSize: 13),
                        ),
                ),
              ],
            ),
          ),
          Text(
            money(bill.shareCents),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              decoration: flag != null ? TextDecoration.lineThrough : null,
              color: flag != null ? c.muted : c.ink,
              fontFeatures: tabularFigures,
            ),
          ),
          if (onRemove != null)
            IconButton(
              tooltip: 'Remove from bill',
              visualDensity: VisualDensity.compact,
              onPressed: onRemove,
              icon: Icon(Icons.person_remove_outlined, size: 20, color: c.muted),
            ),
        ],
      ),
    );
  }
}

class _MyFlagCard extends StatelessWidget {
  const _MyFlagCard({super.key, required this.flag, required this.payer, required this.onWithdraw});

  final BillFlag flag;
  final String payer;
  final VoidCallback onWithdraw;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: c.warnSoft, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'You flagged this: ${flag.reason.label}',
            style: TextStyle(color: c.warn, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Your share doesn’t count until $payer fixes the bill or you withdraw the flag.',
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: onWithdraw, child: const Text('Withdraw flag')),
        ],
      ),
    );
  }
}

final _entryProvider = FutureProvider.autoDispose.family<LedgerEntry?, String>(
  (ref, id) => ref.watch(entryRepositoryProvider).byId(id),
);

/// Lets someone who didn't pay file their share under their own category.
class _CategoryRow extends ConsumerWidget {
  const _CategoryRow({required this.billId});

  final String billId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final entry = ref.watch(_entryProvider(billId)).value;
    if (entry == null) return const SizedBox.shrink();
    final category = ref.watch(categoryMapProvider)[entry.categoryId];
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: AnimatedSwitcher(
        duration: Motion.of(context, Motion.fast),
        child: CategoryAvatar(category, key: ValueKey(category?.id), size: 36),
      ),
      title: const Text('In your spending as'),
      subtitle: Text(category?.name ?? 'Uncategorised'),
      trailing: Icon(Icons.chevron_right_rounded, color: c.muted),
      onTap: () async {
        final picked = await _pickCategory(context, ref, entry.categoryId);
        if (picked == null) return;
        await ref.read(entryRepositoryProvider).save(entry.copyWith(categoryId: picked));
        ref.invalidate(_entryProvider(billId));
      },
    );
  }

  Future<String?> _pickCategory(BuildContext context, WidgetRef ref, String current) {
    final categories = ref
        .read(activeCategoriesProvider)
        .where((cat) => cat.kind == CategoryKind.spending)
        .toList();
    return showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      builder: (context) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          for (final cat in categories)
            ListTile(
              leading: CategoryAvatar(cat, size: 32),
              title: Text(cat.name),
              trailing: cat.id == current ? const Icon(Icons.check_rounded) : null,
              onTap: () => Navigator.pop(context, cat.id),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Flagging
// ---------------------------------------------------------------------------

Future<void> showFlagSheet(BuildContext context, SharedBill bill) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _FlagSheet(bill: bill),
  );
}

class _FlagSheet extends ConsumerStatefulWidget {
  const _FlagSheet({required this.bill});

  final SharedBill bill;

  @override
  ConsumerState<_FlagSheet> createState() => _FlagSheetState();
}

class _FlagSheetState extends ConsumerState<_FlagSheet> {
  FlagReason _reason = FlagReason.wrongAmount;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    await ref
        .read(socialBackendProvider)!
        .setFlag(
          widget.bill.id,
          BillFlag(reason: _reason, note: _note.text.trim(), at: DateTime.now()),
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bill = widget.bill;
    final money = MoneyFormat(bill.currencyCode);
    final payer = bill.nameOf(bill.createdBy);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'What’s wrong?',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Until it’s sorted, your ${money(bill.shareCents)} won’t count toward what you owe '
              '$payer or toward your spending.',
              style: TextStyle(color: c.muted, fontSize: 13.5, height: 1.35),
            ),
            const SizedBox(height: 12),
            RadioGroup<FlagReason>(
              groupValue: _reason,
              onChanged: (r) => setState(() => _reason = r ?? _reason),
              child: Column(
                children: [
                  for (final r in FlagReason.values)
                    RadioListTile<FlagReason>(
                      value: r,
                      contentPadding: EdgeInsets.zero,
                      title: Text(r.label),
                    ),
                ],
              ),
            ),
            TextField(
              controller: _note,
              maxLength: 120,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(hintText: 'Add a note for $payer (optional)'),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: c.warn),
              onPressed: _submit,
              icon: const Icon(Icons.flag_rounded, size: 18),
              label: const Text('Flag my share'),
            ),
          ],
        ),
      ),
    );
  }
}
