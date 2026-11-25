import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/account/account_deletion.dart';
import '../domain/social/account.dart';
import '../domain/social/social_backend.dart';
import 'notifications.dart';
import 'providers.dart';
import 'social_providers.dart';

/// The server side of deleting an account. Overridden in main(); local-only
/// mode has nothing off the phone to delete.
final accountDeletionProvider = Provider<AccountDeletion>((ref) => const NoAccountDeletion());

enum AccountFlowStatus {
  /// Nothing going on.
  idle,

  /// Asking the server to delete the account, then clearing this phone.
  deleting,

  /// Backing up what's left, then signing out and clearing this phone.
  signingOut,

  /// The signed-in account is set to be deleted and frozen until the person
  /// restores it or lets it go; see [AccountFlowState.purgeAfter].
  pendingDeletion,

  /// Cancelling a pending deletion.
  restoring,
}

class AccountFlowState {
  const AccountFlowState(this.status, {this.purgeAfter, this.duringSignIn = false, this.message});

  static const idle = AccountFlowState(AccountFlowStatus.idle);

  final AccountFlowStatus status;

  /// While [AccountFlowStatus.pendingDeletion]: when the account is purged.
  final DateTime? purgeAfter;

  /// While [AccountFlowStatus.pendingDeletion]: true when the person just
  /// signed in to it (asked in a dialog), false when this phone was already
  /// signed in (the whole app gives way to the choice).
  final bool duringSignIn;

  /// Why the last attempt failed, to show near the button that retries.
  final String? message;

  bool get busy =>
      status == AccountFlowStatus.deleting ||
      status == AccountFlowStatus.signingOut ||
      status == AccountFlowStatus.restoring;

  /// The whole app should show the pending-deletion screen.
  bool get frozen => status == AccountFlowStatus.pendingDeletion && !duringSignIn;
}

/// Deleting, restoring and letting go of an account, as Epoch does it.
class AccountFlowNotifier extends Notifier<AccountFlowState> {
  @override
  AccountFlowState build() {
    // Another phone may have asked for deletion while this one was signed
    // in; look again whenever the account changes and at launch.
    ref.listen(accountProvider.select((a) => a.value?.uid), (_, uid) {
      if (uid == null) {
        if (state.status == AccountFlowStatus.pendingDeletion) state = AccountFlowState.idle;
        return;
      }
      if (state.status == AccountFlowStatus.idle && !_signingIn) {
        unawaited(checkPendingDeletion());
      }
    });
    unawaited(Future.microtask(checkPendingDeletion));
    return AccountFlowState.idle;
  }

  AccountDeletion get _deletion => ref.read(accountDeletionProvider);

  /// Set while [signIn] runs, so the account change it causes is checked
  /// there (as a sign-in, asked in a dialog) rather than freezing the app.
  bool _signingIn = false;

  String? get _uid => ref.read(socialBackendProvider)?.currentAccount?.uid;

  /// Deletes the account and clears this phone.
  ///
  /// Signed in: the server freezes the account for
  /// [AccountDeletion.graceDays] days before purging it; signing in again
  /// before then offers to restore it. Not signed in: the server erases the
  /// backup at once.
  ///
  /// No fresh sign-in is asked for: the held button is the confirmation,
  /// and a signed-in deletion can be undone for [AccountDeletion.graceDays]
  /// days.
  ///
  /// Returns what happened, or null when the request failed and nothing
  /// changed ([AccountFlowState.message] says why).
  Future<DeletionOutcome?> deleteAccount() async {
    if (state.busy) return null;
    state = const AccountFlowState(AccountFlowStatus.deleting);
    final DeletionOutcome outcome;
    try {
      // Let queued changes land first, so none arrives after the erase and
      // brings a stray record back.
      try {
        await ref.read(syncEngineProvider).syncNow().timeout(const Duration(seconds: 10));
      } on Object catch (e) {
        debugPrint('Sync before deletion did not complete: $e');
      }
      outcome = await _deletion.request();
    } on Object catch (e) {
      debugPrint('Account deletion failed: $e');
      state = const AccountFlowState(
        AccountFlowStatus.idle,
        message: 'Couldn’t delete. Check your connection and try again.',
      );
      return null;
    }
    // The server has done its part; whatever happens here, the phone must
    // not keep showing an account that is gone.
    try {
      await clearDevice();
    } on Object catch (e) {
      debugPrint('Clearing the phone after deletion failed: $e');
      state = AccountFlowState.idle;
    }
    return outcome;
  }

  /// Signs in, which turns on backup and sharing. If that account is set to
  /// be deleted, the person is asked whether to bring it back (see
  /// `listenForRestoreConfirmation`); otherwise this phone's entries start
  /// backing up to it. Throws what [SocialBackend.signIn] throws.
  Future<void> signIn(SignInMethod method) async {
    final backend = ref.read(socialBackendProvider);
    if (backend == null) return;
    _signingIn = true;
    try {
      await backend.signIn(method);
      await checkPendingDeletion(duringSignIn: true);
    } finally {
      _signingIn = false;
    }
    // A frozen account refuses the backup until it's restored, and
    // restoreAccount syncs then.
    if (state.status == AccountFlowStatus.idle) unawaited(ref.read(syncEngineProvider).syncNow());
  }

  /// Looks for a pending deletion on the signed-in account, from another
  /// phone or from before this launch. Offline, nothing changes: the rules
  /// still refuse writes to a frozen account.
  ///
  /// [duringSignIn] when the person just signed in to it: they're asked in a
  /// dialog instead of the whole app giving way.
  Future<void> checkPendingDeletion({bool duringSignIn = false}) async {
    final uid = _uid;
    if (uid == null || state.busy) return;
    try {
      final purgeAfter = await _deletion.pendingPurge(uid);
      if (purgeAfter == null || state.busy || _uid != uid) return;
      state = AccountFlowState(
        AccountFlowStatus.pendingDeletion,
        purgeAfter: purgeAfter,
        duringSignIn: duringSignIn,
      );
    } on Object catch (e) {
      debugPrint('Couldn’t check for a pending deletion: $e');
    }
  }

  /// Cancels the pending deletion; the backup syncs again.
  Future<void> restoreAccount() async {
    final pending = state;
    if (pending.status != AccountFlowStatus.pendingDeletion) return;
    state = const AccountFlowState(AccountFlowStatus.restoring);
    try {
      await _deletion.restore();
    } on Object catch (e) {
      debugPrint('Restoring the account failed: $e');
      state = AccountFlowState(
        AccountFlowStatus.pendingDeletion,
        purgeAfter: pending.purgeAfter,
        duringSignIn: pending.duringSignIn,
        message: 'Couldn’t restore. Check your connection and try again.',
      );
      return;
    }
    state = AccountFlowState.idle;
    // Changes refused while it was frozen are still waiting; send them now.
    unawaited(ref.read(syncEngineProvider).syncNow());
  }

  /// Leaves the pending deletion to run its course. Returns true when this
  /// phone was cleared and onboarding starts.
  ///
  /// Just after signing in, this phone's own entries never joined that
  /// account (the frozen backup refused them), so they stay on this phone,
  /// signed out and not backed up. A phone that was already signed in holds
  /// the account's data, so it is cleared.
  Future<bool> keepDeleting() async {
    if (state.status != AccountFlowStatus.pendingDeletion) return false;
    if (!state.duringSignIn) {
      state = const AccountFlowState(AccountFlowStatus.deleting);
      await clearDevice();
      return true;
    }
    await _leaveAccount();
    state = AccountFlowState.idle;
    unawaited(ref.read(syncEngineProvider).syncNow());
    return false;
  }

  /// Signs out and clears this phone. What you track lives in the account's
  /// backup, so it comes back when you sign in again, here or on another
  /// phone.
  ///
  /// Changes not backed up yet get one last try first; whatever still can't
  /// be sent (offline, say) is lost, so the screen warns before calling this
  /// (see `SyncStatus.pendingCount`).
  Future<void> signOut() async {
    if (state.busy) return;
    state = const AccountFlowState(AccountFlowStatus.signingOut);
    try {
      await ref.read(syncEngineProvider).syncNow().timeout(const Duration(seconds: 10));
    } on Object catch (e) {
      debugPrint('Sync before signing out did not complete: $e');
    }
    try {
      await clearDevice();
    } on Object catch (e) {
      debugPrint('Clearing the phone after signing out failed: $e');
      state = AccountFlowState.idle;
    }
  }

  /// Signs out of the account, first stopping this phone's notifications
  /// for it (only the signed-in account can do that). Leaves this phone's
  /// data alone.
  Future<void> _leaveAccount() async {
    await ref.read(notificationsProvider.notifier).beforeSignOut();
    await ref.read(socialBackendProvider)?.signOut();
  }

  /// Clears everything the app keeps on this phone and signs out, leaving a
  /// fresh start: onboarding and default categories, not backed up until
  /// someone signs in.
  Future<void> clearDevice() async {
    await _leaveAccount();
    await ref.read(databaseProvider).clearForNewUser();
    await ref.read(sharedPreferencesProvider).clear();
    ref
      ..invalidate(settingsProvider)
      ..invalidate(inboxSeenProvider)
      ..invalidate(shellTabProvider);
    state = AccountFlowState.idle;
    // Shows "not backed up" now rather than at the next edit.
    unawaited(ref.read(syncEngineProvider).syncNow());
  }
}

final accountFlowProvider = NotifierProvider<AccountFlowNotifier, AccountFlowState>(
  AccountFlowNotifier.new,
);
