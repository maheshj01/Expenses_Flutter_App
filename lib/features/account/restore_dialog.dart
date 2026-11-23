import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/account_flow.dart';
import '../../app/social_providers.dart';
import '../../app/theme.dart';

/// When someone signs in to an account that is set to be deleted, asks
/// whether to bring it back. Call from a build method that stays on screen
/// through sign-in (the app root) with its [ref].
void listenForRestoreConfirmation(WidgetRef ref, BuildContext context) {
  ref.listen<AccountFlowState>(accountFlowProvider, (previous, next) {
    if (next.status == AccountFlowStatus.pendingDeletion &&
        next.duringSignIn &&
        previous?.status != AccountFlowStatus.pendingDeletion) {
      _confirmUndelete(context, ref, next);
    }
  });
}

Future<void> _confirmUndelete(BuildContext context, WidgetRef ref, AccountFlowState pending) async {
  final handle = ref.read(myProfileProvider).value?.handle;
  final who = handle == null ? 'This account' : '@$handle';
  final when = pending.purgeAfter == null
      ? 'soon'
      : 'on ${DateFormat.yMMMMd().format(pending.purgeAfter!)}';
  final restore = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: const Text('Bring your account back?'),
      content: Text(
        '$who is set to be deleted $when. Restore it to cancel the deletion; '
        'what you track on this phone will be added to it.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          style: TextButton.styleFrom(foregroundColor: context.colors.muted),
          child: const Text('Keep deleting'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Restore', style: TextStyle(fontWeight: FontWeight.w600)),
        ),
      ],
    ),
  );
  final notifier = ref.read(accountFlowProvider.notifier);
  if (restore == true) {
    await notifier.restoreAccount();
    final failed = ref.read(accountFlowProvider);
    if (failed.message != null && context.mounted) {
      // Still pending: say why and ask again.
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failed.message!)));
      await _confirmUndelete(context, ref, failed);
    }
  } else {
    await notifier.keepDeleting();
  }
}
