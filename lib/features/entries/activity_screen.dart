import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../app/social_providers.dart';
import '../../app/theme.dart';
import '../../core/year_month.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/ledger_entry.dart';
import '../../domain/repositories/entry_repository.dart';
import '../../shared/animations/fade_slide_in.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/entry_tile.dart';
import '../people/bill_sheet.dart';
import 'edit_history_sheet.dart';
import 'entry_editor_sheet.dart';

enum EntryFilter {
  all('All'),
  spending('Spending'),
  investing('Saving'),
  income('Income'),
  split('Split'),
  moneyBack('Money back'),
  deleted('Deleted');

  const EntryFilter(this.label);

  final String label;
}

/// Every entry of one month, searchable and filterable. Entries you
/// deleted, and shared bills their payer deleted, stay listed (faded, not
/// counted) under All and Deleted.
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

  bool _matches(LedgerEntry e, Map<String, Category> cats, {bool deleted = false}) {
    final kind = cats[e.categoryId]?.kind ?? CategoryKind.spending;
    final ok = switch (_filter) {
      EntryFilter.all => true,
      EntryFilter.deleted => deleted,
      _ when deleted => false,
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
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Entry deleted'),
          action: SnackBarAction(label: 'Undo', onPressed: () => repo.save(e)),
        ),
      );
  }

  /// A deleted share of a bill opens the bill (who deleted it, when);
  /// your own entry opens its history, with Restore.
  Future<void> _openDeleted(DeletedEntry d) async {
    final e = d.entry;
    if (e.billId case final billId?) {
      await showBillSheet(context, billId);
      return;
    }
    final repo = ref.read(entryRepositoryProvider);
    final currency = ref.read(settingsProvider).currencyCode;
    final edits = await repo.watchEdits(e.id).first;
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    await showEditHistorySheet(
      context,
      edits: edits,
      currencyCode: currency,
      created: e.createdAt == null
          ? 'Created on this device'
          : 'Created ${DateFormat.yMMMd().format(e.createdAt!)}',
      onRestore: () async {
        await repo.save(e);
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('Entry restored')));
      },
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
    final deleted = ref
        .watch(monthDeletedProvider(_month))
        .where((d) => _matches(d.entry, cats, deleted: true))
        .toList();
    // Each day lists what counts first, then what was deleted.
    final byDay = <DateTime, List<_Row>>{};
    for (final e in entries) {
      byDay.putIfAbsent(e.date, () => []).add((entry: e, deleted: null));
    }
    for (final d in deleted) {
      byDay.putIfAbsent(d.entry.date, () => []).add((entry: d.entry, deleted: d));
    }
    final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
    final nothing = _query.isEmpty && _filter == EntryFilter.all;

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
                      _Total('Spent', money.whole(summary.livedCents), c.lived),
                      _Total('Saved', money.whole(summary.investedCents), c.invested),
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
            if (entriesAsync.isLoading && byDay.isEmpty)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (byDay.isEmpty)
              EmptyState(
                emoji: '🧾',
                title: nothing
                    ? 'Nothing logged this month'
                    : _filter == EntryFilter.deleted && _query.isEmpty
                    ? 'Nothing deleted this month'
                    : 'Nothing matches',
                message: nothing ? 'Tap + to add an expense.' : null,
              )
            else
              for (final day in days) ...[
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
                      for (final (i, (:entry, :deleted)) in byDay[day]!.indexed) ...[
                        if (i > 0) const Divider(),
                        if (deleted != null)
                          FadeSlideIn(
                            key: ValueKey('deleted ${entry.id}'),
                            offset: const Offset(0, 8),
                            child: EntryTile(
                              entry,
                              showDate: false,
                              deleted: true,
                              onTap: () => _openDeleted(deleted),
                            ),
                          )
                        else
                          Dismissible(
                            key: ValueKey(entry.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 8),
                              child: Icon(Icons.delete_outline_rounded, color: c.warn),
                            ),
                            onDismissed: (_) => _deleteWithUndo(entry),
                            child: EntryTile(
                              entry,
                              showDate: false,
                              onTap: () => showEntryEditor(context, entry: entry),
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

/// One line of a day: an entry, and how it was deleted if it was.
typedef _Row = ({LedgerEntry entry, DeletedEntry? deleted});

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
