import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../domain/entities/app_settings.dart';
import '../../../domain/services/monthly_plan.dart';
import '../../../shared/money_format.dart';
import '../onboarding_draft.dart';
import '../onboarding_widgets.dart';

class GoalsStep extends StatefulWidget {
  const GoalsStep({super.key, required this.draft, required this.onChanged});

  final OnboardingDraft draft;
  final VoidCallback onChanged;

  @override
  State<GoalsStep> createState() => _GoalsStepState();
}

class _GoalsStepState extends State<GoalsStep> {
  OnboardingDraft get d => widget.draft;

  int get _suggestion => d.monthlyIncomeCents > 0
      ? MonthlyPlan.suggestSavings(d.monthlyIncomeCents, d.spendingCents)
      : 0;

  @override
  void initState() {
    super.initState();
    // Pre-fill once with what is left after spending, so most people can
    // just tap Continue.
    if (!d.savingsSuggested && d.savingsCents == 0 && _suggestion > 0) {
      d.savingsCents = _suggestion;
    }
    d.savingsSuggested = true;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final money = MoneyFormat(d.currencyCode);
    return StepLayout(
      title: 'What are you working towards?',
      subtitle: 'Pick as many as you like.',
      children: [
        for (final goal in MoneyGoal.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ChoiceCard(
              emoji: goal.emoji,
              title: goal.label,
              dense: true,
              selected: d.goals.contains(goal),
              onTap: () {
                d.goals.contains(goal) ? d.goals.remove(goal) : d.goals.add(goal);
                widget.onChanged();
              },
            ),
          ),
        const SizedBox(height: 16),
        const Text(
          'Set aside each month',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 8),
          child: Text(
            'Investing or saving, it all counts. We’ll show your progress on Home.',
            style: TextStyle(color: c.muted, fontSize: 13.5),
          ),
        ),
        AmountInput(
          symbol: money.symbol,
          cents: d.savingsCents,
          fontSize: 34,
          onChanged: (v) {
            d.savingsCents = v;
            widget.onChanged();
          },
        ),
        if (_suggestion > 0 && d.savingsCents != _suggestion)
          Align(
            alignment: Alignment.centerLeft,
            child: SuggestionPill(
              label: 'Use what’s left: ${money.whole(_suggestion)}',
              onTap: () {
                d.savingsCents = _suggestion;
                widget.onChanged();
              },
            ),
          ),
      ],
    );
  }
}
