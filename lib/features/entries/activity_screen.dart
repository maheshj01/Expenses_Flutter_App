import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/year_month.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/ledger_entry.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/entry_tile.dart';
import 'entry_editor_sheet.dart';

enum EntryFilter {
  all('All'),
  spending('Spending'),
  investing('Investing'),
  income('Income'),
  split('Split'),
  moneyBack('Money back');

  const EntryFilter(this.label);

  final String label;
}

/// Every entry of one month, searchable and filterable.
///
/// Used as a tab (current month) and pushed from History for any month.
class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key, this.initialMonth, this.standalone = false});

  final YearMonth? initialMonth;

  /// True when pushed as its own page (shows a back button).
  final bool standalone;

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  late YearMonth _month = widget.initialMonth ?? YearMonth.now();
  EntryFilter _filter = EntryFilter.all;
  String _query = '';

  bool _matches(LedgerEntry e, Map<String, Category> cats) {
    final kind = cats[e.categoryId]?.kind ?? CategoryKind.spending;
    final ok = switch (_filter) {
      EntryFilter.all => true,
      EntryFilter.spending => kind == CategoryKind.spending,
      EntryFilter.investing => kind == CategoryKind.investing,
      EntryFilter.income => kind == CategoryKind.income,
      EntryFilter.split => e.isSplit,
      EntryFilter.moneyBack => e.isMoneyBack,
    };
    if (!ok) return false;
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    final compare = RegExp(r'^([<>])\s*(\d+(?:\.\d+)?)$').firstMatch(q);
    if (compare != null) {
      final limit = (double.parse(compare.group(2)!) * 100).round();
      return compare.group(1) == '>' ? e.shareCents > limit : e.shareCents < limit;
    }
    return '${e.note} ${cats[e.categoryId]?.name ?? ''}'.toLowerCase().contains(q);
  }

  Future<void> _deleteWithUndo(LedgerEntry e) async {
    final repo = ref.read(entryRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    await repo.delete(e.id);
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Entry deleted'),
        action: SnackBarAction(label: 'Undo', onPressed: () => repo.save(e)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final money = ref.watch(moneyFormatProvider);
    final cats = ref.watch(categoryMapProvider);
    final entriesAsync = ref.watch(monthEntriesProvider(_month));
    final summary = ref.watch(monthSummaryProvider(_month));
    final isFuture = _month.next.firstDay.isAfter(DateTime.now().add(const Duration(days: 31)));

    final entries = (entriesAsync.value ?? const <LedgerEntry>[])
        .where((e) => _matches(e, cats))
        .toList();
    final byDay = <DateTime, List<LedgerEntry>>{};
    for (final e in entries) {
      byDay.putIfAbsent(e.date, () => []).add(e);
    }

    return Scaffold(
      appBar: widget.standalone ? AppBar() : null,
      body: SafeArea(
        top: !widget.standalone,
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 120),
          children: [
            Text('Activity', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 12),
            AppCard(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => setState(() => _month = _month.previous),
                        icon: const Icon(Icons.chevron_left_rounded),
                      ),
                      Expanded(
                        child: Text(
                          DateFormat.yMMMM().format(_month.firstDay),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                      ),
                      IconButton(
                        onPressed: isFuture ? null : () => setState(() => _month = _month.next),
                        icon: const Icon(Icons.chevron_right_rounded),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      _Total('Lived', money.whole(summary.livedCents), c.lived),
                      _Total('Invested', money.whole(summary.investedCents), c.invested),
                      _Total('Earned', money.whole(summary.earnedCents), c.earned),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Search notes, categories, “> 100”',
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final f in EntryFilter.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(f.label),
                        selected: _filter == f,
                        onSelected: (_) => setState(() => _filter = f),
                      ),
                    ),
                ],
              ),
            ),
            if (entriesAsync.isLoading && entries.isEmpty)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (entries.isEmpty)
              EmptyState(
                emoji: '🧾',
                title: _query.isEmpty && _filter == EntryFilter.all
                    ? 'Nothing logged this month'
                    : 'Nothing matches',
                message: _query.isEmpty && _filter == EntryFilter.all
                    ? 'Tap + to add an expense.'
                    : null,
              )
            else
              for (final MapEntry(key: day, value: list) in byDay.entries) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 18, 4, 6),
                  child: Text(
                    DateFormat('EEE, MMM d').format(day).toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.6,
                      color: c.muted,
                    ),
                  ),
                ),
                AppCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                  child: Column(
                    children: [
                      for (final (i, e) in list.indexed) ...[
                        if (i > 0) const Divider(),
                        Dismissible(
                          key: ValueKey(e.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 8),
                            child: Icon(Icons.delete_outline_rounded, color: c.warn),
                          ),
                          onDismissed: (_) => _deleteWithUndo(e),
                          child: EntryTile(
                            e,
                            showDate: false,
                            onTap: () => showEntryEditor(context, entry: e),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
          ],
        ),
      ),
    );
  }
}

class _Total extends StatelessWidget {
  const _Total(this.label, this.value, this.color);

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11.5, color: color, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              fontFeatures: tabularFigures,
            ),
          ),
        ],
      ),
    );
  }
}
