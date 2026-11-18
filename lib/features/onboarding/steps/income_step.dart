import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../domain/entities/app_settings.dart';
import '../../../shared/animations/animated_amount.dart';
import '../../../shared/animations/motion.dart';
import '../../../shared/money_format.dart';
import '../../../shared/widgets/currency_picker.dart';
import '../onboarding_draft.dart';
import '../onboarding_widgets.dart';

class IncomeStep extends StatelessWidget {
  const IncomeStep({super.key, required this.draft, required this.onChanged});

  final OnboardingDraft draft;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final money = MoneyFormat(draft.currencyCode);
    final showMonthly = draft.incomeCents > 0 && draft.payFrequency != PayFrequency.monthly;

    return StepLayout(
      title: 'How much do you take home?',
      subtitle: 'Your pay after tax. If it changes, a typical paycheck is fine.',
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final f in PayFrequency.values)
              SuggestionPill(
                label: f.label,
                selected: draft.payFrequency == f,
                onTap: () {
                  draft.payFrequency = f;
                  onChanged();
                },
              ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: AmountInput(
                symbol: money.symbol,
                cents: draft.incomeCents,
                autofocus: true,
                onChanged: (v) {
                  draft.incomeCents = v;
                  onChanged();
                },
              ),
            ),
            TextButton(
              onPressed: () async {
                final code = await showCurrencyPicker(context, current: draft.currencyCode);
                if (code != null) {
                  draft.currencyCode = code;
                  onChanged();
                }
              },
              child: Text('${draft.currencyCode} ▾', style: TextStyle(color: c.ink2)),
            ),
          ],
        ),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(draft.payFrequency.per, style: TextStyle(color: c.muted)),
            // The monthly figure sits right under the amount so it stays
            // visible while the keyboard is open.
            AnimatedSize(
              duration: Motion.of(context, Motion.medium),
              curve: Motion.enter,
              child: showMonthly
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('  ·  ≈ ', style: TextStyle(color: c.earned)),
                        AnimatedAmount(
                          cents: draft.monthlyIncomeCents,
                          duration: Motion.medium,
                          builder: (context, v) => Text(
                            money.whole(v),
                            style: TextStyle(
                              color: c.earned,
                              fontWeight: FontWeight.w700,
                              fontFeatures: tabularFigures,
                            ),
                          ),
                        ),
                        Text(' a month', style: TextStyle(color: c.earned)),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ],
    );
  }
}
