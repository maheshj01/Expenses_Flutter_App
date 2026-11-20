import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../domain/services/monthly_plan.dart';
import '../../../shared/animations/animated_amount.dart';
import '../../../shared/animations/fade_slide_in.dart';
import '../../../shared/money_format.dart';
import '../../../shared/region_keys.dart';
import '../../../shared/widgets/app_card.dart';
import '../onboarding_draft.dart';
import '../onboarding_widgets.dart';

/// Summary of the answers as a monthly plan.
class PlanStep extends StatelessWidget {
  const PlanStep({super.key, required this.draft});

  final OnboardingDraft draft;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final money = MoneyFormat(draft.currencyCode);
    final plan = MonthlyPlan(
      incomeCents: draft.monthlyIncomeCents,
      spendingCents: draft.spendingCents,
      savingsCents: draft.savingsCents,
    );
    final name = draft.name.trim();
    final income = plan.incomeCents;

    Widget row(int i, String label, int cents, Color color) => FadeSlideIn(
      index: 3 + i,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 15))),
            AnimatedAmount(
              cents: cents,
              builder: (context, v) => Text(
                money.whole(v),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  fontFeatures: tabularFigures,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return StepLayout(
      title: name.isEmpty ? 'Here’s your plan' : 'Here’s your plan, $name',
      subtitle: 'Three buckets for every month: what you live on, what you build, what you earn.',
      children: [
        AppCard(
          key: RegionKeys.planCard,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (income > 0) ...[
                const Label('Coming in each month'),
                AnimatedAmount(
                  cents: income,
                  builder: (context, v) => Text(
                    money.whole(v),
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1.2,
                      fontFeatures: tabularFigures,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SegmentBar(
                  height: 14,
                  segments: [
                    ((plan.spendingCents / income).clamp(0, 1).toDouble(), c.lived),
                    ((plan.savingsCents / income).clamp(0, 1).toDouble(), c.invested),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              row(0, 'Live on', plan.spendingCents, c.lived),
              row(1, 'Set aside', plan.savingsCents, c.invested),
              if (income > 0)
                row(
                  2,
                  plan.isOverCommitted ? 'Over your income by' : 'Left unplanned',
                  plan.unplannedCents.abs(),
                  plan.isOverCommitted ? c.warn : c.earned,
                ),
            ],
          ),
        ),
        if (plan.isOverCommitted)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              'Your plan asks for more than comes in. That’s fine for a start. '
              'Tweak it any time in Settings.',
              style: TextStyle(color: c.warn, fontSize: 13),
            ),
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            if (plan.spendingCents > 0)
              Expanded(
                child: _Tile(
                  emoji: '☀️',
                  value: money.whole(plan.dailySpendCents),
                  label: 'to spend a day',
                ),
              ),
            if (plan.spendingCents > 0) const SizedBox(width: 8),
            Expanded(
              child: _Tile(
                emoji: '🗂️',
                value: '${draft.categoryIds?.length ?? 0}',
                label: 'categories',
              ),
            ),
            if (draft.goals.isNotEmpty) ...[
              const SizedBox(width: 8),
              Expanded(
                child: _Tile(
                  emoji: draft.goals.map((g) => g.emoji).take(3).join(),
                  value: '${draft.goals.length}',
                  label: draft.goals.length == 1 ? 'goal' : 'goals',
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.emoji, required this.value, required this.label});

  final String emoji;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: c.sunk, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              fontFeatures: tabularFigures,
            ),
          ),
          Text(label, style: TextStyle(color: c.muted, fontSize: 12)),
        ],
      ),
    );
  }
}
