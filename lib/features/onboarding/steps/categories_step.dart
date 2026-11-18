import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme.dart';
import '../../../domain/entities/category.dart';
import '../../../shared/animations/fade_slide_in.dart';
import '../../../shared/animations/motion.dart';
import '../../../shared/animations/pressable_scale.dart';
import '../onboarding_draft.dart';
import '../onboarding_widgets.dart';

class CategoriesStep extends StatelessWidget {
  const CategoriesStep({
    super.key,
    required this.draft,
    required this.choices,
    required this.onChanged,
  });

  final OnboardingDraft draft;

  /// Spending categories to choose from, existing ones first.
  final List<Category> choices;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final selected = draft.categoryIds ?? const <String>{};
    return StepLayout(
      title: 'What do you spend on?',
      subtitle: 'We picked the usual ones. Tap to add or remove. You can change these any time.',
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (i, cat) in choices.indexed)
              FadeSlideIn(
                index: i ~/ 2,
                offset: const Offset(0, 10),
                child: _CategoryChip(
                  category: cat,
                  selected: selected.contains(cat.id),
                  onTap: () {
                    final ids = draft.categoryIds ??= {};
                    ids.contains(cat.id) ? ids.remove(cat.id) : ids.add(cat.id);
                    onChanged();
                  },
                ),
              ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          '📈 Investment and 💼 Salary are always included.',
          style: TextStyle(color: c.muted, fontSize: 13),
        ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.category, required this.selected, required this.onTap});

  final Category category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return PressableScale(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: Motion.of(context, Motion.fast),
        curve: Motion.enter,
        padding: const EdgeInsets.fromLTRB(10, 9, 14, 9),
        decoration: BoxDecoration(
          color: selected ? c.ink : c.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? c.ink : c.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(category.emoji, style: const TextStyle(fontSize: 17)),
            const SizedBox(width: 8),
            AnimatedDefaultTextStyle(
              duration: Motion.of(context, Motion.fast),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: selected ? c.background : c.ink2,
              ),
              child: Text(category.name),
            ),
          ],
        ),
      ),
    );
  }
}
