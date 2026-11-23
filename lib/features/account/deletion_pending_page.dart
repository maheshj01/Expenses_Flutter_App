import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/account_flow.dart';
import '../../app/social_providers.dart';
import '../../app/theme.dart';
import '../../domain/account/account_deletion.dart';
import '../../shared/widgets/app_card.dart';

/// Shown in place of the app when this phone is signed in to an account
/// that was set to be deleted (here earlier, or on another phone). The
/// account is frozen, so there are only two ways on: restore it, or let it
/// go and clear this phone.
class DeletionPendingPage extends ConsumerWidget {
  const DeletionPendingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final flow = ref.watch(accountFlowProvider);
    final notifier = ref.read(accountFlowProvider.notifier);
    final handle = ref.watch(myProfileProvider).value?.handle;
    final purgeAfter = flow.purgeAfter ?? DateTime.now();
    final busy = flow.busy;
    final daysLeft = daysUntilPurge(purgeAfter, DateTime.now());

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Label('ACCOUNT'),
              const SizedBox(height: 6),
              Text(
                'Your account is set to be deleted',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(height: 1.15),
              ),
              const SizedBox(height: 10),
              Text(
                '${handle == null ? 'This account' : '@$handle'} will be deleted on '
                '${DateFormat.yMMMMd().format(purgeAfter)}, along with its backup. '
                'Until then it is paused on every phone.',
                style: TextStyle(fontSize: 15, height: 1.45, color: c.muted),
              ),
              const SizedBox(height: 32),
              GraceDots(daysLeft: daysLeft),
              const SizedBox(height: 12),
              Text(
                daysLeft == 1
                    ? '1 day left to change your mind'
                    : '$daysLeft days left to change your mind',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              if (flow.message != null && !busy)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    flow.message!,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: c.warn),
                  ),
                ),
              FilledButton(
                onPressed: busy ? null : notifier.restoreAccount,
                style: FilledButton.styleFrom(
                  backgroundColor: c.ink,
                  foregroundColor: c.background,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                child: flow.status == AccountFlowStatus.restoring
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: c.background),
                      )
                    : const Text('Restore my account'),
              ),
              const SizedBox(height: 4),
              TextButton(
                // Clearing the phone makes it a new user again, and the app
                // root swaps to onboarding by itself.
                onPressed: busy ? null : notifier.keepDeleting,
                child: Text(
                  flow.status == AccountFlowStatus.deleting
                      ? 'Clearing this phone…'
                      : 'Continue deleting and clear this phone',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: c.muted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Whole days left before [purgeAfter], counting today while any of it
/// remains, capped to the grace period.
int daysUntilPurge(DateTime purgeAfter, DateTime now) {
  final hours = purgeAfter.difference(now).inHours;
  if (hours <= 0) return 0;
  return ((hours + 23) ~/ 24).clamp(0, AccountDeletion.graceDays);
}

/// The grace period as dots: one per day, filled for the days still left.
class GraceDots extends StatelessWidget {
  const GraceDots({super.key, required this.daysLeft});

  final int daysLeft;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    const total = AccountDeletion.graceDays;
    return Semantics(
      label: '$daysLeft of $total days left',
      excludeSemantics: true,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (var day = 0; day < total; day++)
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                // Elapsed days first, as hollow rings; the days left follow.
                color: day >= total - daysLeft ? c.lived : null,
                border: day >= total - daysLeft ? null : Border.all(color: c.line, width: 1.5),
              ),
            ),
        ],
      ),
    );
  }
}
