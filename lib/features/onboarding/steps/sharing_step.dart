import 'package:flutter/material.dart';

import '../../../app/theme.dart';
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
                  child: TextFormField(
                    initialValue: draft.splitWith,
                    autofocus: draft.splitWith.isEmpty,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Who do you split with most?',
                      hintText: 'e.g. Alex',
                    ),
                    onChanged: (v) {
                      draft.splitWith = v;
                      onChanged();
                    },
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
        if (shares ?? false)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              'Tip: type “costco 46 split” and we’ll log your half.',
              style: TextStyle(color: c.muted, fontSize: 13),
            ),
          ),
      ],
    );
  }
}
