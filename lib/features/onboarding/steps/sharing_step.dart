import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../shared/animations/fade_slide_in.dart';
import '../../../shared/animations/motion.dart';
import '../onboarding_draft.dart';
import '../onboarding_widgets.dart';

class SharingStep extends StatelessWidget {
  const SharingStep({super.key, required this.draft, required this.onChanged});

  final OnboardingDraft draft;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final shares = draft.sharesBills;
    return StepLayout(
      title: 'Do you split bills with anyone?',
      subtitle:
          'A roommate, partner or family. Log the full bill and only your share counts '
          'toward your budget.',
      children: [
        ChoiceCard(
          emoji: '🤝',
          title: 'Yes, I split some bills',
          subtitle: 'Rent, utilities, groceries…',
          selected: shares ?? false,
          onTap: () {
            draft.sharesBills = true;
            onChanged();
          },
        ),
        const SizedBox(height: 8),
        ChoiceCard(
          emoji: '🙋',
          title: 'No, it’s just me',
          selected: shares == false,
          onTap: () {
            draft.sharesBills = false;
            onChanged();
          },
        ),
        AnimatedSize(
          duration: Motion.of(context, Motion.medium),
          curve: Motion.enter,
          alignment: Alignment.topCenter,
          child: shares ?? false
              ? Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const FadeSlideIn(
                        index: 0,
                        child: _Hint(
                          emoji: '👥',
                          title: 'On Three Bucks?',
                          body:
                              'Add them on the People tab after setup. They see their share '
                              'and you see who owes what.',
                        ),
                      ),
                      const SizedBox(height: 8),
                      const FadeSlideIn(
                        index: 1,
                        child: _Hint(
                          emoji: '✍️',
                          title: 'Not on the app?',
                          body: 'Name them the first time you split a bill. We’ll remember them.',
                        ),
                      ),
                      FadeSlideIn(
                        index: 2,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            'Tip: type “costco 46 split” and we’ll log your half.',
                            style: TextStyle(color: c.muted, fontSize: 13),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.emoji, required this.title, required this.body});

  final String emoji;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: c.sunk, borderRadius: BorderRadius.circular(14)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(body, style: TextStyle(color: c.ink2, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
