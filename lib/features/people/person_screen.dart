import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../app/social_providers.dart';
import '../../app/theme.dart';
import '../../core/ids.dart';
import '../../domain/social/account.dart';
import '../../domain/social/connection.dart';
import '../../domain/social/settlement.dart';
import '../../domain/social/shared_bill.dart';
import '../../shared/animations/animated_amount.dart';
import '../../shared/animations/fade_slide_in.dart';
import '../../shared/money_format.dart';
import '../../shared/widgets/app_card.dart';
import 'bill_sheet.dart';
import 'people_widgets.dart';
import 'safety_sheets.dart';

/// Everything shared with one person: the balance, settling up, and every
/// bill and payment between you.
///
/// Also opens for someone you're no longer connected with who still has an
/// open balance: you can settle up, report or block, but not split new
/// bills or remove them.
class PersonScreen extends ConsumerWidget {
  const PersonScreen({super.key, required this.person});

  final Profile person;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final other = person;
    // Looked up live, so blocking or being removed shows at once.
    final connection = ref
        .watch(friendsProvider)
        .where((f) => f.other.uid == person.uid)
        .firstOrNull;
    final me = ref.watch(accountProvider).value?.uid ?? '';
    final balance = ref.watch(balancesProvider).withPerson(other.uid);
    final bills = ref.watch(billsWithProvider(other.uid));
    final settlements = ref.watch(settlementsWithProvider(other.uid));
    final currency = ref.watch(settingsProvider.select((s) => s.currencyCode));
    final main = balance[currency] ?? balance.values.firstOrNull ?? 0;
    final mainCurrency = balance.containsKey(currency)
        ? currency
        : (balance.keys.firstOrNull ?? currency);

    final timeline = <(DateTime, Widget)>[
      for (final b in bills) (b.date, _BillRow(bill: b, me: me, other: other)),
      for (final s in settlements) (s.date, _SettlementRow(settlement: s, me: me, other: other)),
    ]..sort((a, b) => b.$1.compareTo(a.$1));

    return Scaffold(
      appBar: AppBar(
        actions: [
          SafetyMenuButton(
            person: other,
            onRemove: connection == null ? null : () => _disconnect(context, ref, connection),
            // While a balance is open they stay reachable from People.
            onBlocked: balance.isEmpty ? () => Navigator.of(context).pop() : null,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 40),
        children: [
          FadeSlideIn(
            child: Column(
              children: [
                Hero(tag: 'person-${other.uid}', child: PersonAvatar(other, size: 76)),
                const SizedBox(height: 10),
                Text(
                  other.displayName,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
                if (other.handle.isNotEmpty)
                  Text('@${other.handle}', style: TextStyle(color: c.muted)),
                if (connection == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Not connected · settle up to clear the balance',
                      style: TextStyle(color: c.muted, fontSize: 13),
                    ),
                  ),
                const SizedBox(height: 16),
                Text(
                  main == 0
                      ? 'You’re settled up'
                      : (main > 0
                            ? '${other.displayName} owes you'
                            : 'You owe ${other.displayName}'),
                  style: TextStyle(color: c.muted),
                ),
                AnimatedAmount(
                  cents: main.abs(),
                  builder: (context, value) => Text(
                    MoneyFormat(mainCurrency)(value),
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -1.5,
                      color: main == 0 ? c.muted : (main > 0 ? c.lived : c.warn),
                      fontFeatures: tabularFigures,
                    ),
                  ),
                ),
                if (balance.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: BalanceText({...balance}..remove(mainCurrency), alignEnd: false),
                  ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: main == 0
                      ? null
                      : () => showSettleUpSheet(
                          context,
                          other: other,
                          me: me,
                          balanceCents: main,
                          currency: mainCurrency,
                        ),
                  icon: const Icon(Icons.handshake_outlined, size: 18),
                  label: const Text('Settle up'),
                ),
              ],
            ),
          ),
          const SectionHeader('History'),
          if (timeline.isEmpty)
            AppCard(
              child: EmptyState(
                emoji: '🧾',
                title: 'Nothing shared yet',
                message: 'Add an entry and tap “Split” to share it with ${other.displayName}.',
              ),
            )
          else
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              child: Column(
                children: [
                  for (final (i, (_, row)) in timeline.indexed) ...[
                    if (i > 0) const Divider(),
                    FadeSlideIn(index: i.clamp(0, 8), child: row),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _disconnect(BuildContext context, WidgetRef ref, Connection connection) async {
    final name = person.displayName;
    final balance = ref.read(balancesProvider).withPerson(person.uid);
    if (balance.isNotEmpty) {
      await _settleFirst(context, ref, balance);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove $name?'),
        content: Text(
          'You won’t be able to split new bills with $name. Bills you already share stay as they are.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(socialBackendProvider)!.removeConnection(connection.id);
    if (context.mounted) Navigator.of(context).pop();
  }

  /// Explains that [person] can only be removed once the balance is zero,
  /// and offers to settle up (or block instead).
  Future<void> _settleFirst(BuildContext context, WidgetRef ref, Map<String, int> balance) async {
    final name = person.displayName;
    final currency = ref.read(settingsProvider).currencyCode;
    final mainCurrency = balance.containsKey(currency) ? currency : balance.keys.first;
    final main = balance[mainCurrency]!;
    final amount = MoneyFormat(mainCurrency)(main.abs());
    final settle = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Settle up with $name first'),
        content: Text(
          '${main > 0 ? '$name owes you $amount' : 'You owe $name $amount'}'
          '${balance.length > 1 ? ', plus balances in other currencies' : ''}. '
          'You can remove $name once you’re settled up. '
          'To stop them sharing with you right away, block them instead.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Settle up'),
          ),
        ],
      ),
    );
    if (settle != true || !context.mounted) return;
    await showSettleUpSheet(
      context,
      other: person,
      me: ref.read(accountProvider).value?.uid ?? '',
      balanceCents: main,
      currency: mainCurrency,
    );
  }
}

class _BillRow extends StatelessWidget {
  const _BillRow({required this.bill, required this.me, required this.other});

  final SharedBill bill;
  final String me;
  final Profile other;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final money = MoneyFormat(bill.currencyCode);
    final iPaid = bill.createdBy == me;
    final theyPaid = bill.createdBy == other.uid;
    final owed = iPaid ? bill.owedBy(other.uid) : (theyPaid ? bill.owedBy(me) : 0);
    final detail = iPaid
        ? 'You paid ${money(bill.amountCents)}'
        : '${bill.nameOf(bill.createdBy)} paid ${money(bill.amountCents)}';
    return InkWell(
      onTap: () => showBillSheet(context, bill.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              child: Column(
                children: [
                  Text(
                    DateFormat.MMM().format(bill.date).toUpperCase(),
                    style: TextStyle(fontSize: 10.5, color: c.muted, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${bill.date.day}',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          bill.note.isEmpty ? 'Shared bill' : bill.note,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
                        ),
                      ),
                      if (bill.isDisputed) ...[const SizedBox(width: 6), const DisputedTag()],
                    ],
                  ),
                  Text(detail, style: TextStyle(color: c.muted, fontSize: 12.5)),
                ],
              ),
            ),
            if (owed > 0)
              Text(
                iPaid ? '+${money(owed)}' : '−${money(owed)}',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: iPaid ? c.lived : c.warn,
                  fontFeatures: tabularFigures,
                ),
              )
            else
              Text(
                bill.isFlaggedBy(iPaid ? other.uid : me) ? 'on hold' : '—',
                style: TextStyle(color: c.muted, fontSize: 13),
              ),
          ],
        ),
      ),
    );
  }
}

class _SettlementRow extends ConsumerWidget {
  const _SettlementRow({required this.settlement, required this.me, required this.other});

  final Settlement settlement;
  final String me;
  final Profile other;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = settlement;
    final money = MoneyFormat(s.currencyCode);
    final text = s.from == me ? 'You paid ${other.displayName}' : '${other.displayName} paid you';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          SizedBox(width: 40, child: Icon(Icons.handshake_outlined, color: c.lived)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
                Text(
                  '${DateFormat.MMMd().format(s.date)} · recorded by '
                  '${s.createdBy == me ? 'you' : other.displayName}',
                  style: TextStyle(color: c.muted, fontSize: 12.5),
                ),
              ],
            ),
          ),
          Text(
            money(s.amountCents),
            style: const TextStyle(fontWeight: FontWeight.w600, fontFeatures: tabularFigures),
          ),
          if (s.createdBy == me)
            IconButton(
              tooltip: 'Undo',
              visualDensity: VisualDensity.compact,
              onPressed: () => ref.read(socialBackendProvider)!.deleteSettlement(s.id),
              icon: Icon(Icons.undo_rounded, size: 18, color: c.muted),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Settle up
// ---------------------------------------------------------------------------

Future<void> showSettleUpSheet(
  BuildContext context, {
  required Profile other,
  required String me,
  required int balanceCents,
  required String currency,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) =>
        _SettleUpSheet(other: other, me: me, balanceCents: balanceCents, currency: currency),
  );
}

class _SettleUpSheet extends ConsumerStatefulWidget {
  const _SettleUpSheet({
    required this.other,
    required this.me,
    required this.balanceCents,
    required this.currency,
  });

  final Profile other;
  final String me;
  final int balanceCents;
  final String currency;

  @override
  ConsumerState<_SettleUpSheet> createState() => _SettleUpSheetState();
}

class _SettleUpSheetState extends ConsumerState<_SettleUpSheet> {
  late final TextEditingController _amount = TextEditingController(
    text: (widget.balanceCents.abs() / 100).toStringAsFixed(2),
  );

  /// True when you paid them.
  late bool _iPaid = widget.balanceCents < 0;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  int get _cents => ((double.tryParse(_amount.text.replaceAll(',', '')) ?? 0) * 100).round();

  Future<void> _record() async {
    final cents = _cents;
    if (cents <= 0) return;
    final now = DateTime.now();
    await ref
        .read(socialBackendProvider)!
        .addSettlement(
          Settlement(
            id: newId(),
            from: _iPaid ? widget.me : widget.other.uid,
            to: _iPaid ? widget.other.uid : widget.me,
            amountCents: cents,
            currencyCode: widget.currency,
            date: now,
            createdBy: widget.me,
            createdAt: now,
          ),
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final money = MoneyFormat(widget.currency);
    final name = widget.other.displayName;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Settle up', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              'Record a payment made outside the app, like a bank transfer. No money moves here.',
              style: TextStyle(color: c.muted, fontSize: 13.5),
            ),
            const SizedBox(height: 16),
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: true, label: Text('I paid $name')),
                ButtonSegment(value: false, label: Text('$name paid me')),
              ],
              selected: {_iPaid},
              onSelectionChanged: (s) => setState(() => _iPaid = s.first),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amount,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w600,
                fontFeatures: tabularFigures,
              ),
              decoration: InputDecoration(prefixText: money.symbol),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _cents > 0 ? _record : null,
              child: Text(_cents > 0 ? 'Record ${money(_cents)}' : 'Record payment'),
            ),
          ],
        ),
      ),
    );
  }
}
