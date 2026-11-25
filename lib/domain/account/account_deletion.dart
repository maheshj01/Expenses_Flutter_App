/// Deleting an account, decided and carried out by the server (see
/// `functions/src/accountDeletion.ts`) so the grace period and the purge
/// can't be bent by a client.
///
/// Without an account there is nothing on the server to delete. An
/// anonymous account (left from versions that backed up without signing in)
/// is erased at once: with no identity to sign back in with, a grace period
/// would only keep data nobody can reach. A signed-in account is frozen and
/// restorable for [graceDays] days, then purged.
abstract interface class AccountDeletion {
  static const int graceDays = 30;

  /// Deletes (anonymous) or schedules the deletion of (signed in) the
  /// current account.
  Future<DeletionOutcome> request();

  /// Cancels the current account's pending deletion.
  Future<void> restore();

  /// When [uid]'s pending deletion becomes final, or null when there is
  /// none. A deletion marked for inactivity (two years unopened) is
  /// cancelled here instead: opening the app is the person coming back.
  Future<DateTime?> pendingPurge(String uid);
}

sealed class DeletionOutcome {
  const DeletionOutcome();
}

/// Everything is gone already.
class Erased extends DeletionOutcome {
  const Erased();
}

/// The account is frozen until [purgeAfter]; signing in before then can
/// restore it.
class Scheduled extends DeletionOutcome {
  const Scheduled(this.purgeAfter);

  final DateTime purgeAfter;
}

/// Used in local-only mode: there is nothing off the phone to delete.
class NoAccountDeletion implements AccountDeletion {
  const NoAccountDeletion();

  @override
  Future<DeletionOutcome> request() async => const Erased();

  @override
  Future<void> restore() async {}

  @override
  Future<DateTime?> pendingPurge(String uid) async => null;
}
