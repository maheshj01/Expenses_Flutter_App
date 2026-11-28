import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/year_month.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/ledger_entry.dart';
import '../../domain/services/period_summary.dart';
import '../../shared/money_format.dart';
import '../../shared/region_keys.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/category_avatar.dart';
import '../entries/activity_screen.dart';
import 'month_bars_chart.dart';

/// One year: monthly chart, top categories and a row per month.
class YearScreen extends ConsumerWidget {
  const YearScreen({super.key, required this.year});

  final int year;

  /// Under each month: what was saved, or invested when there was no income.
  static String _monthLine(PeriodSummary m, MoneyFormat money) {
    if (!m.hasIncome) {
      return m.investedCents > 0 ? '${money.whole(m.investedCents)} invested' : 'No income';
    }
    return m.savedCents < 0
        ? '${money.whole(-m.savedCents)} over income'
        : '${money.whole(m.savedCents)} saved';
  }

  void _openMonth(BuildContext context, int month) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ActivityScreen(initialMonth: YearMonth(year, month), standalone: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final money = ref.watch(moneyFormatProvider);
    final cats = ref.watch(categoryMapProvider);
    final entries = ref.watch(yearEntriesProvider(year)).value ?? const <LedgerEntry>[];
    final year$ = PeriodSummary.of(entries, cats);

    final byMonth = List.generate(12, (_) => <LedgerEntry>[]);
    for (final e in entries) {
      byMonth[e.date.month - 1].add(e);
    }
    final monthSummaries = [for (final list in byMonth) PeriodSummary.of(list, cats)];
    final now = DateTime.now();
    final lastMonth = year < now.year ? 12 : (year == now.year ? now.month : 0);
    final topSpending = year$.ranked(cats, CategoryKind.spending).take(5).toList();
    final activeMonths = monthSummaries.where((m) => m.livedCents > 0).length;

    return Scaffold(
      appBar: AppBar(title: Text('$year')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 40),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Label('Monthly · tap a month to open it'),
                const SizedBox(height: 14),
                MonthBarsChart(
                  key: RegionKeys.monthChart,
                  months: [
                    for (final m in monthSummaries)
                      MonthBar(
                        lived: m.livedCents,
                        invested: m.investedCents,
                        earned: m.earnedCents,
                      ),
                  ],
                  onMonthTap: (m) => _openMonth(context, m),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _Legend('Spent', c.lived),
                    _Legend('Invested', c.invested),
                    _Legend('Earned', c.earned),
                  ],
                ),
              ],
            ),
          ),
          const SectionHeader('Year in numbers'),
          AppCard(
            child: Column(
              children: [
                if (year$.hasIncome) ...[
                  // Where the income went: spent, invested, left in cash.
                  SegmentBar(
                    height: 10,
                    segments: [
                      (year$.livedCents / year$.earnedCents, c.lived),
                      (year$.investedCents / year$.earnedCents, c.invested),
                      (year$.cashCents / year$.earnedCents, c.muted),
                    ],
                  ),
                  const SizedBox(height: 14),
                ],
                _Row('Earned', money(year$.earnedCents), c.earned),
                _Row('Spent', money(year$.livedCents), c.lived),
                if (year$.hasIncome) ...[
                  _Row(
                    year$.savedShare > 0
                        ? 'Saved · ${(year$.savedShare * 100).round()}% of income'
                        : 'Saved',
                    money(year$.savedCents),
                    year$.savedCents < 0 ? c.warn : c.invested,
                  ),
                  _Row('Invested', money(year$.investedCents), null, indent: true),
                  _Row('Left in cash', money(year$.cashCents), null, indent: true),
                  if (year$.fromEarlierSavingsCents > 0)
                    _Row(
                      'Invested from earlier savings',
                      money(year$.fromEarlierSavingsCents),
                      null,
                      indent: true,
                    ),
                ] else
                  _Row('Invested', money(year$.investedCents), c.invested),
                const Divider(height: 20),
                if (activeMonths > 0)
                  _Row('Average spent / month', money(year$.livedCents ~/ activeMonths), null),
              ],
            ),
          ),
          if (topSpending.isNotEmpty) ...[
            const SectionHeader('Top spending'),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Column(
                children: [
                  for (final MapEntry(key: id, value: cents) in topSpending)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          CategoryAvatar(cats[id], size: 34),
                          const SizedBox(width: 12),
                          Expanded(child: Text(cats[id]?.name ?? 'Uncategorised')),
                          Text(money(cents), style: const TextStyle(fontFeatures: tabularFigures)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SectionHeader('Months'),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Column(
              children: [
                for (var m = lastMonth; m >= 1; m--) ...[
                  if (m != lastMonth) const Divider(indent: 12, endIndent: 12),
                  ListTile(
                    onTap: () => _openMonth(context, m),
                    title: Text(DateFormat.MMMM().format(DateTime(year, m))),
                    subtitle: Text(
                      monthSummaries[m - 1].entryCount == 0
                          ? 'No entries'
                          : _monthLine(monthSummaries[m - 1], money),
                      style: TextStyle(color: c.muted, fontSize: 12.5),
                    ),
                    trailing: Text(
                      money.whole(monthSummaries[m - 1].livedCents),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        fontFeatures: tabularFigures,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend(this.label, this.color);

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 14),
    child: Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 12, color: context.colors.muted)),
      ],
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, this.color, {this.indent = false});

  final String label;
  final String value;
  final Color? color;

  /// A part of the row above it, e.g. what was invested out of savings.
  final bool indent;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(indent ? 18 : 0, 4, 0, 4),
    child: Row(
      children: [
        if (color != null) ...[
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(label, style: indent ? TextStyle(color: context.colors.ink2) : null),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: indent ? FontWeight.w500 : FontWeight.w600,
            color: indent ? context.colors.ink2 : null,
            fontFeatures: tabularFigures,
          ),
        ),
      ],
    ),
  );
}
