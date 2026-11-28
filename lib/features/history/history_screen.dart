import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../domain/entities/ledger_entry.dart';
import '../../shared/widgets/app_card.dart';
import 'year_screen.dart';

/// Every year you have data for, newest first.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final years = ref.watch(yearsProvider);
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 120),
        children: [
          Text('History', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 4),
          Text(
            'Every year at a glance. Tap one to see its months.',
            style: TextStyle(color: context.colors.muted, fontSize: 13),
          ),
          const SizedBox(height: 12),
          for (final (i, year) in years.indexed) ...[
            if (i > 0) const SizedBox(height: 10),
            _YearCard(year: year, previous: years.contains(year - 1) ? year - 1 : null),
          ],
        ],
      ),
    );
  }
}

class _YearCard extends ConsumerWidget {
  const _YearCard({required this.year, this.previous});

  final int year;
  final int? previous;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final money = ref.watch(moneyFormatProvider);
    final s = ref.watch(yearSummaryProvider(year));
    final prev = previous == null ? null : ref.watch(yearSummaryProvider(previous!));
    final isCurrent = year == DateTime.now().year;

    // Compare the average month, not totals: the current year (and the
    // first year of history) usually covers only part of the year.
    int months(int y) => {
      for (final e in ref.watch(yearEntriesProvider(y)).value ?? const <LedgerEntry>[])
        e.date.month,
    }.length;
    String? change;
    if (prev != null && prev.livedCents > 0 && months(year) > 0 && months(previous!) > 0) {
      final now = s.livedCents / months(year);
      final before = prev.livedCents / months(previous!);
      final pct = ((now - before) / before * 100).round();
      change = pct == 0
          ? 'Same monthly spending as $previous'
          : '${pct > 0 ? '↑' : '↓'} ${pct.abs()}% a month on spending vs $previous';
    }

    Widget figure(String label, int cents, Color color) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          FittedBox(
            child: Text(
              money.whole(cents),
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                fontFeatures: tabularFigures,
              ),
            ),
          ),
        ],
      ),
    );

    // Where the money went: spent, invested, and what's left in cash.
    final cash = s.cashCents < 0 ? 0 : s.cashCents;
    final total = s.livedCents + s.investedCents + cash;
    return AppCard(
      onTap: () =>
          Navigator.of(context)
              .push(MaterialPageRoute<void>(builder: (_) => YearScreen(year: year))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '$year',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              if (isCurrent) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: c.livedSoft,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    'so far',
                    style: TextStyle(fontSize: 11, color: c.lived, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
              const Spacer(),
              Icon(Icons.chevron_right_rounded, color: c.muted),
            ],
          ),
          if (s.entryCount == 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('No entries yet', style: TextStyle(color: c.muted, fontSize: 13)),
            )
          else ...[
            const SizedBox(height: 12),
            SegmentBar(
              height: 8,
              segments: total <= 0
                  ? const []
                  : [
                      (s.livedCents / total, c.lived),
                      (s.investedCents / total, c.invested),
                      (cash / total, c.muted),
                    ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                figure('Spent', s.livedCents, c.lived),
                if (s.hasIncome)
                  figure('Saved', s.savedCents, s.savedCents < 0 ? c.warn : c.invested)
                else
                  figure('Invested', s.investedCents, c.invested),
                figure('Earned', s.earnedCents, c.earned),
              ],
            ),
            if (change != null) ...[
              const SizedBox(height: 8),
              Text(change, style: TextStyle(fontSize: 12.5, color: c.muted)),
            ],
          ],
        ],
      ),
    );
  }
}
