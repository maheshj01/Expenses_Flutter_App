import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../domain/services/monthly_plan.dart';
import '../../../shared/animations/animated_amount.dart';
import '../../../shared/money_format.dart';
import '../../../shared/widgets/app_card.dart';
import '../onboarding_draft.dart';
import '../onboarding_widgets.dart';

class SpendingStep extends StatelessWidget {
  const SpendingStep({super.key, required this.draft, required this.onChanged});

  final OnboardingDraft draft;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final money = MoneyFormat(draft.currencyCode);
    final income = draft.monthlyIncomeCents;
    final spend = draft.spendingCents;

    return StepLayout(
      title: 'How much do you spend in a month?',
      subtitle:
          'Rent, food, bills, fun: everything except investing. '
          'A rough guess is fine. This becomes your monthly budget.',
      children: [
        AmountInput(
          symbol: money.symbol,
          cents: spend,
          autofocus: true,
          onChanged: (v) {
            draft.spendingCents = v;
            onChanged();
          },
        ),
        Text('a month', style: TextStyle(color: c.muted)),
        if (income > 0) ...[
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final share in const [0.5, 0.6, 0.7])
                Builder(
                  builder: (context) {
                    final cents = MonthlyPlan.suggestSpending(income, share);
                    return SuggestionPill(
                      label: '${(share * 100).round()}% · ${money.whole(cents)}',
                      selected: spend == cents,
                      onTap: () {
                        draft.spendingCents = cents;
                        onChanged();
                      },
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: 24),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Label('Of ${money.whole(income)} coming in each month'),
                const SizedBox(height: 12),
                SegmentBar(
                  height: 14,
                  segments: [
                    ((spend / income).clamp(0, 1).toDouble(), spend > income ? c.warn : c.lived),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _Figure('You live on', spend, c.lived, money)),
                    Expanded(
                      child: _Figure(
                        spend > income ? 'Over by' : 'Left to save',
                        (income - spend).abs(),
                        spend > income ? c.warn : c.invested,
                        money,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure(this.label, this.cents, this.color, this.money);

  final String label;
  final int cents;
  final Color color;
  final MoneyFormat money;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
      AnimatedAmount(
        cents: cents,
        builder: (context, v) => Text(
          money.whole(v),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            fontFeatures: tabularFigures,
          ),
        ),
      ),
    ],
  );
}
