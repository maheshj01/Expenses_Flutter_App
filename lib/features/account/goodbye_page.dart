import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/app.dart';
import '../../app/theme.dart';
import '../../domain/account/account_deletion.dart';
import 'goodbye_dot.dart';

/// Replaces every screen with [page], fading in. For leaving an account,
/// where there's nothing to go back to.
void fadeToFresh(BuildContext context, Widget page) {
  Navigator.of(context).pushAndRemoveUntil(
    PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 500),
      pageBuilder: (_, _, _) => page,
      transitionsBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
    (_) => false,
  );
}

/// The last screen of a deletion, on the brand green: one dot that stops or
/// pauses ([GoodbyeDot]), what happened, the date a scheduled deletion
/// becomes final, and a way to start over.
class GoodbyePage extends StatelessWidget {
  const GoodbyePage({super.key, required this.outcome, this.signedInAs});

  final DeletionOutcome outcome;

  /// The account that was deleted (its username), to name it in the
  /// restore hint.
  final String? signedInAs;

  /// The brand green, in both themes: white text needs the dark one.
  static final background = AppColors.light.lived;

  @override
  Widget build(BuildContext context) {
    final (title, body) = switch (outcome) {
      Scheduled(:final purgeAfter) => (
        'Your account is set to go',
        'It will be deleted on ${DateFormat.yMMMMd().format(purgeAfter)}. '
            'Changed your mind? Sign in as ${signedInAs ?? 'the same account'} before then '
            'and everything comes back.',
      ),
      Erased() => (
        'Everything is erased',
        'Nothing you tracked remains on this phone or on our servers.',
      ),
    };

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(flex: 3),
                GoodbyeDot(erased: outcome is Erased),
                const SizedBox(height: 28),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w600,
                    height: 1.15,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  body,
                  style: const TextStyle(fontSize: 15.5, height: 1.5, color: Colors.white70),
                ),
                const Spacer(flex: 4),
                const Text(
                  'Thank you for keeping track with Three Bucks.',
                  style: TextStyle(fontSize: 13, color: Colors.white70),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => fadeToFresh(context, const AppRoot()),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white70),
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    child: const Text('Start over'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
