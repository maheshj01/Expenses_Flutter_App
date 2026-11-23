import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../domain/entities/app_settings.dart';
import '../../../shared/animations/animated_amount.dart';
import '../../../shared/animations/fade_slide_in.dart';
import '../../../shared/animations/motion.dart';
import '../../../shared/money_format.dart';
import '../../../shared/widgets/currency_picker.dart';
import '../onboarding_draft.dart';
import '../onboarding_widgets.dart';

/// Asks whether money comes in at all before asking how much, so people
/// without a salary (home makers, students, retirees) aren't stuck on a
/// paycheck question.
class IncomeStep extends StatelessWidget {
  const IncomeStep({super.key, required this.draft, required this.onChanged});

  final OnboardingDraft draft;
  final VoidCallback onChanged;

  void _pick(IncomeKind kind) {
    draft.incomeKind = kind;
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final kind = draft.incomeKind;

    return StepLayout(
      title: 'Does money come in regularly?',
      subtitle:
          'Salary, pension, allowance, freelance work. No income? '
          'That’s fine, you can still track every bit you spend.',
      children: [
        ChoiceCard(
          emoji: '💼',
          title: 'Yes, about the same each time',
          subtitle: 'Salary, pension, allowance…',
          selected: kind == IncomeKind.regular,
          onTap: () => _pick(IncomeKind.regular),
        ),
        const SizedBox(height: 8),
        ChoiceCard(
          emoji: '🌊',
          title: 'Yes, but it varies',
          subtitle: 'Freelance, commission, seasonal…',
          selected: kind == IncomeKind.varies,
          onTap: () => _pick(IncomeKind.varies),
        ),
        const SizedBox(height: 8),
        ChoiceCard(
          emoji: '🏠',
          title: 'No regular income',
          subtitle: 'I just want to track what I spend',
          selected: kind == IncomeKind.none,
          onTap: () => _pick(IncomeKind.none),
        ),
        AnimatedSize(
          duration: Motion.of(context, Motion.medium),
          curve: Motion.enter,
          alignment: Alignment.topCenter,
          child: switch (kind) {
            null => const SizedBox(width: double.infinity),
            IncomeKind.none => _CurrencyOnly(draft: draft, onChanged: onChanged),
            _ => _AmountFields(key: ValueKey(kind), draft: draft, onChanged: onChanged),
          },
        ),
      ],
    );
  }
}

class _AmountFields extends StatelessWidget {
  const _AmountFields({super.key, required this.draft, required this.onChanged});

  final OnboardingDraft draft;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final money = MoneyFormat(draft.currencyCode);
    final varies = draft.incomeKind == IncomeKind.varies;
    final showMonthly =
        !varies && draft.incomeCents > 0 && draft.payFrequency != PayFrequency.monthly;

    return FadeSlideIn(
      index: 0,
      child: Padding(
        padding: const EdgeInsets.only(top: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              varies ? 'In a typical month, after tax' : 'How much, after tax?',
              style: TextStyle(color: c.ink2, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            if (!varies) ...[
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
              const SizedBox(height: 16),
            ],
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
                _CurrencyButton(draft: draft, onChanged: onChanged),
              ],
            ),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(varies ? 'a month' : draft.payFrequency.per, style: TextStyle(color: c.muted)),
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
        ),
      ),
    );
  }
}

/// No income to enter, but amounts later still need a currency.
class _CurrencyOnly extends StatelessWidget {
  const _CurrencyOnly({required this.draft, required this.onChanged});

  final OnboardingDraft draft;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return FadeSlideIn(
      index: 0,
      child: Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Next, you’ll set how much you want to spend a month.',
                style: TextStyle(color: c.muted, fontSize: 13),
              ),
            ),
            _CurrencyButton(draft: draft, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

class _CurrencyButton extends StatelessWidget {
  const _CurrencyButton({required this.draft, required this.onChanged});

  final OnboardingDraft draft;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () async {
        final code = await showCurrencyPicker(context, current: draft.currencyCode);
        if (code != null) {
          draft.currencyCode = code;
          onChanged();
        }
      },
      child: Text('${draft.currencyCode} ▾', style: TextStyle(color: context.colors.ink2)),
    );
  }
}
