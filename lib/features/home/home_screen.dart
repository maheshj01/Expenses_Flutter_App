import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/year_month.dart';
import '../../data/sync/sync_status.dart';
import '../../domain/entities/category.dart';
import '../../domain/services/period_summary.dart';
import '../../shared/animations/animated_amount.dart';
import '../../shared/animations/fade_slide_in.dart';
import '../../shared/animations/motion.dart';
import '../../shared/money_format.dart';
import '../../shared/region_keys.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/category_avatar.dart';
import '../../shared/widgets/entry_tile.dart';
import '../data_io/import_screen.dart';
import '../entries/entry_editor_sheet.dart';
import '../settings/settings_screen.dart';
import 'budget_dialog.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, required this.onSeeAll});

  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final month = YearMonth.of(now);
    final summary = ref.watch(monthSummaryProvider(month));
    final entries = ref.watch(monthEntriesProvider(month)).value ?? const [];
    final cats = ref.watch(categoryMapProvider);
    final money = ref.watch(moneyFormatProvider);

    final spending = summary.ranked(cats, CategoryKind.spending);
    final name = ref.watch(settingsProvider.select((s) => s.name));

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 120),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('EEEE, MMM d').format(now),
                      style: TextStyle(color: context.colors.muted, fontSize: 13),
                    ),
                    Text(_greeting(now, name), style: Theme.of(context).textTheme.headlineMedium),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Settings',
                onPressed: () =>
                    Navigator.of(context)
                        .push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen())),
                icon: Icon(Icons.settings_outlined, color: context.colors.ink2),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FadeSlideIn(
            child: KeyedSubtree(
              key: RegionKeys.budgetHero,
              child: _BudgetHero(month: month, summary: summary, money: money),
            ),
          ),
          const _SyncBanner(),
          const SectionHeader('This month'),
          FadeSlideIn(
            index: 1,
            child: KeyedSubtree(
              key: RegionKeys.monthTiles,
              child: _FlowTiles(
                summary: summary,
                money: money,
                expectsIncome: ref.watch(settingsProvider.select((s) => s.hasIncome)),
              ),
            ),
          ),
          KeyedSubtree(
            key: RegionKeys.goalCard,
            child: _SavedCard(summary: summary, money: money),
          ),
          if (spending.isNotEmpty) ...[
            const SectionHeader('Where it went'),
            FadeSlideIn(
              index: 2,
              child: AppCard(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
                child: Column(
                  children: [
                    for (final MapEntry(key: id, value: cents) in spending.take(6))
                      _CategoryBar(
                        category: cats[id],
                        cents: cents,
                        max: spending.first.value,
                        money: money,
                      ),
                  ],
                ),
              ),
            ),
          ],
          SectionHeader('Recent', action: entries.isEmpty ? null : 'See all', onAction: onSeeAll),
          if (entries.isEmpty)
            AppCard(
              child: EmptyState(
                emoji: '✨',
                title: 'A fresh month',
                message: 'Tap + and type something like “kroger 18”.',
                // Nothing logged ever: offer to bring in an old spreadsheet.
                action: !ref.watch(hasEntriesProvider)
                    ? TextButton.icon(
                        onPressed: () => Navigator.of(context)
                            .push(MaterialPageRoute<void>(builder: (_) => const ImportScreen())),
                        icon: const Icon(Icons.upload_file_rounded, size: 18),
                        label: const Text('Import a spreadsheet'),
                      )
                    : null,
              ),
            )
          else
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              child: Column(
                children: [
                  for (final (i, e) in entries.take(5).indexed) ...[
                    if (i > 0) const Divider(),
                    EntryTile(e, onTap: () => showEntryEditor(context, entry: e)),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  static String _greeting(DateTime now, String name) {
    final hello = switch (now.hour) {
      < 12 => 'Good morning',
      < 17 => 'Good afternoon',
      _ => 'Good evening',
    };
    return name.isEmpty ? hello : '$hello, $name';
  }
}

class _BudgetHero extends ConsumerWidget {
  const _BudgetHero({required this.month, required this.summary, required this.money});

  final YearMonth month;
  final PeriodSummary summary;
  final MoneyFormat money;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final settings = ref.watch(settingsProvider);
    final lived = summary.livedCents;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Label('Spent · ${DateFormat.MMMM().format(month.firstDay)}'),
          const SizedBox(height: 6),
          AnimatedAmount(
            cents: lived,
            builder: (context, value) {
              // Split "$1,234.56" into "$1,234" and ".56" without rounding.
              final full = money(value);
              final dot = full.lastIndexOf('.');
              return Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: dot < 0 ? full : full.substring(0, dot)),
                    if (dot >= 0)
                      TextSpan(
                        text: full.substring(dot),
                        style: TextStyle(fontSize: 22, color: c.muted, fontWeight: FontWeight.w500),
                      ),
                  ],
                ),
                style: const TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -1.6,
                  fontFeatures: tabularFigures,
                ),
              );
            },
          ),
          if (!settings.hasBudget) ...[
            const SizedBox(height: 8),
            Text(
              'Set a monthly budget to see how much you can safely spend each day.',
              style: TextStyle(color: c.muted, fontSize: 13),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => showBudgetDialog(context, ref),
              child: const Text('Set budget'),
            ),
          ] else
            _BudgetDetails(settings.monthlyBudgetCents, lived, month, money),
        ],
      ),
    );
  }
}

class _BudgetDetails extends ConsumerWidget {
  const _BudgetDetails(this.budget, this.lived, this.month, this.money);

  final int budget;
  final int lived;
  final YearMonth month;
  final MoneyFormat money;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final pace = BudgetPace.forMonth(
      budgetCents: budget,
      livedCents: lived,
      today: DateTime.now(),
      daysInMonth: month.dayCount,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => showBudgetDialog(context, ref),
          child: Label('of ${money.whole(budget)} budget · ${pace.daysLeft} days left'),
        ),
        const SizedBox(height: 12),
        SegmentBar(segments: [(pace.usedFraction, pace.isOver ? c.warn : c.lived)]),
        const SizedBox(height: 12),
        Row(
          children: [
            _Stat(
              label: 'Safe to spend today',
              value: money(pace.safePerDayCents),
              color: pace.isOver ? c.warn : null,
            ),
            const SizedBox(width: 10),
            _Stat(
              label: pace.isOver ? 'Over budget' : 'Left this month',
              value: money.whole(pace.remainingCents.abs()),
              color: pace.isOver ? c.warn : null,
            ),
          ],
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: context.colors.sunk,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Label(label),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: color,
                fontFeatures: tabularFigures,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Spent, saved and earned this month. Saved is earned minus spent; with no
/// income logged it can't be worked out, so investing shows instead.
class _FlowTiles extends StatelessWidget {
  const _FlowTiles({required this.summary, required this.money, required this.expectsIncome});

  final PeriodSummary summary;
  final MoneyFormat money;

  /// The user said they have an income, so a month without any logged yet
  /// shows Saved as "not yet" rather than dropping it.
  final bool expectsIncome;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget tile(String label, int? cents, Color fg, Color bg, {String? note}) => Expanded(
      child: AnimatedContainer(
        duration: Motion.of(context, Motion.medium),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 12),
            ),
            const SizedBox(height: 4),
            FittedBox(
              child: cents == null
                  ? Text('—', style: TextStyle(fontSize: 17, color: c.muted))
                  : AnimatedAmount(
                      cents: cents,
                      builder: (context, value) => Text(
                        money.whole(value),
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: cents < 0 ? c.warn : null,
                          fontFeatures: tabularFigures,
                        ),
                      ),
                    ),
            ),
            if (note != null) Text(note, style: TextStyle(color: fg, fontSize: 11), maxLines: 1),
          ],
        ),
      ),
    );

    final saved = summary.savedCents;
    final Widget middle;
    if (summary.hasIncome) {
      middle = saved < 0
          ? tile('Saved', saved, c.warn, c.warnSoft, note: 'over income')
          : tile('Saved', saved, c.invested, c.investedSoft);
    } else if (expectsIncome) {
      middle = tile('Saved', null, c.muted, c.sunk, note: 'no income yet');
    } else {
      middle = tile('Invested', summary.investedCents, c.invested, c.investedSoft);
    }
    return Row(
      children: [
        tile('Spent', summary.livedCents, c.lived, c.livedSoft),
        const SizedBox(width: 8),
        middle,
        if (summary.hasIncome || expectsIncome) ...[
          const SizedBox(width: 8),
          tile('Earned', summary.earnedCents, c.earned, c.earnedSoft),
        ],
      ],
    );
  }
}

class _CategoryBar extends StatelessWidget {
  const _CategoryBar({
    required this.category,
    required this.cents,
    required this.max,
    required this.money,
  });

  final Category? category;
  final int cents;
  final int max;
  final MoneyFormat money;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          CategoryAvatar(category),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        category?.name ?? 'Uncategorised',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    Text(money(cents), style: const TextStyle(fontFeatures: tabularFigures)),
                  ],
                ),
                const SizedBox(height: 7),
                SegmentBar(
                  height: 6,
                  segments: [(max <= 0 ? 0 : (cents / max).clamp(0, 1).toDouble(), c.lived)],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tells the user when changes are waiting to sync.
class _SyncBanner extends ConsumerWidget {
  const _SyncBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final status = ref.watch(syncStatusProvider).value;
    if (status == null) return const SizedBox.shrink();
    final (icon, text) = switch (status.phase) {
      SyncPhase.offline when status.pendingCount > 0 => (
        Icons.cloud_off_rounded,
        'Offline · ${status.pendingCount} change${status.pendingCount == 1 ? '' : 's'} '
            'will sync when you’re back online',
      ),
      SyncPhase.error => (
        Icons.sync_problem_rounded,
        '${status.message ?? 'Sync paused.'} Trying again shortly.',
      ),
      _ => (null, null),
    };
    if (icon == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: c.warnSoft, borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            Icon(icon, color: c.warn, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text!, style: TextStyle(color: c.ink2, fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }
}

/// What you saved this month (earned minus spent), where it went
/// (invested or left in cash), and progress toward the savings goal.
class _SavedCard extends ConsumerWidget {
  const _SavedCard({required this.summary, required this.money});

  final PeriodSummary summary;
  final MoneyFormat money;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final settings = ref.watch(settingsProvider);
    final income = summary.hasIncome;
    // Has an income but none logged yet this month: still about saving.
    final waitingForIncome = !income && settings.hasIncome;
    final invested = summary.investedCents;
    if (!income && invested == 0 && !settings.hasSavingsGoal) return const SizedBox.shrink();

    final amount = summary.towardGoalCents;
    final goal = settings.hasSavingsGoal ? settings.savingsGoalCents : 0;
    final reached = goal > 0 && amount >= goal;
    final cash = income ? summary.cashCents : 0;
    final earlier = income ? summary.fromEarlierSavingsCents : 0;
    final emojis = goal > 0 ? settings.goals.map((g) => g.emoji).take(3).join(' ') : '';
    final status = TextStyle(color: c.invested, fontWeight: FontWeight.w700);

    // One bar: invested, then cash, measured against the goal if there is
    // one, otherwise against everything set aside.
    final scale = goal > 0 ? goal : (invested + cash);
    final investedPart = scale <= 0 ? 0.0 : (invested / scale).clamp(0, 1).toDouble();
    final cashPart = scale <= 0 ? 0.0 : (cash / scale).clamp(0, 1 - investedPart).toDouble();

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: FadeSlideIn(
        index: 2,
        child: AppCard(
          color: reached ? c.investedSoft : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Label(
                      income || waitingForIncome ? 'Saved this month' : 'Invested this month',
                    ),
                  ),
                  if (income && summary.savedShare > 0)
                    _Pill('${(summary.savedShare * 100).round()}% of income'),
                  if (emojis.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Text(emojis, style: const TextStyle(fontSize: 14)),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  AnimatedAmount(
                    cents: amount,
                    builder: (context, v) => Text(
                      money.whole(v),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: amount < 0 ? c.warn : null,
                        fontFeatures: tabularFigures,
                      ),
                    ),
                  ),
                  if (goal > 0) Text(' of ${money.whole(goal)}', style: TextStyle(color: c.muted)),
                  const Spacer(),
                  if (goal > 0)
                    AnimatedSwitcher(
                      duration: Motion.of(context, Motion.medium),
                      transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
                      child: reached
                          ? Text('Goal reached 🎉', key: const ValueKey('done'), style: status)
                          : Text(
                              '${(amount.clamp(0, goal) * 100 ~/ goal)}%',
                              key: const ValueKey('pct'),
                              style: status,
                            ),
                    ),
                ],
              ),
              if (waitingForIncome)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    invested > 0
                        ? 'What you invested so far. Add this month’s income to see all you saved.'
                        : 'Add this month’s income to see what you saved.',
                    style: TextStyle(color: c.muted, fontSize: 12.5),
                  ),
                ),
              if (amount < 0)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    'You spent ${money.whole(-amount)} more than you earned',
                    style: TextStyle(color: c.warn, fontSize: 12.5),
                  ),
                ),
              const SizedBox(height: 10),
              SegmentBar(height: 8, segments: [(investedPart, c.invested), (cashPart, c.muted)]),
              if (income && (invested > 0 || cash > 0)) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 14,
                  runSpacing: 4,
                  children: [
                    if (invested > 0) _Dot('Invested ${money.whole(invested)}', c.invested),
                    if (cash > 0) _Dot('Left in cash ${money.whole(cash)}', c.muted),
                    if (earlier > 0)
                      Text(
                        '${money.whole(earlier)} of it from earlier savings',
                        style: TextStyle(fontSize: 12, color: c.muted),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: c.investedSoft, borderRadius: BorderRadius.circular(99)),
      child: Text(
        text,
        style: TextStyle(fontSize: 11.5, color: c.invested, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot(this.label, this.color);

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 5),
      Text(label, style: TextStyle(fontSize: 12, color: context.colors.ink2)),
    ],
  );
}
