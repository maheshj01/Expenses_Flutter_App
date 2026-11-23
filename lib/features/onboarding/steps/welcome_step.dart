import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../shared/animations/fade_slide_in.dart';
import '../onboarding_draft.dart';
import '../three_bucks_mark.dart';

class WelcomeStep extends StatelessWidget {
  const WelcomeStep({super.key, required this.draft, required this.onChanged});

  final OnboardingDraft draft;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 40, 22, 24),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        const Align(alignment: Alignment.centerLeft, child: ThreeBucksMark()),
        const SizedBox(height: 32),
        const FadeSlideIn(
          index: 3,
          child: Text(
            'Let’s make your money make sense.',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              letterSpacing: -1,
              height: 1.1,
            ),
          ),
        ),
        FadeSlideIn(
          index: 4,
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              'A few quick questions so Three Bucks can track what matters to you. '
              'It takes under a minute, and you can change anything later.',
              style: TextStyle(color: c.muted, fontSize: 15.5, height: 1.45),
            ),
          ),
        ),
        const SizedBox(height: 28),
        FadeSlideIn(
          index: 5,
          child: TextFormField(
            initialValue: draft.name,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'What should we call you?',
              hintText: 'Optional',
            ),
            onChanged: (v) {
              draft.name = v;
              onChanged();
            },
          ),
        ),
        const SizedBox(height: 20),
        FadeSlideIn(
          index: 6,
          child: Row(
            children: [
              for (final (label, color) in [
                ('Spent', c.lived),
                ('Saved', c.invested),
                ('Earned', c.earned),
              ]) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(label, style: TextStyle(fontSize: 12.5, color: c.muted)),
                const SizedBox(width: 14),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
