import '../data/sync/sync_engine.dart';
import '../domain/social/social_backend.dart';

/// Deletes the signed-in account and everything stored for it online: the
/// backed-up entries and categories, then the username, profile,
/// connections, blocks and sign-in. What's on this device stays.
///
/// If a step fails after the backup was erased, it is pushed again, so a
/// failed deletion never leaves an account without its backup.
Future<void> deleteAccountAndData({required SyncEngine sync, required SocialBackend social}) async {
  var erased = false;
  try {
    await social.deleteAccount(
      eraseData: () async {
        erased = true;
        await sync.eraseRemote();
      },
    );
  } catch (_) {
    if (erased) await sync.resumeAfterErase(restore: true);
    rethrow;
  }
  if (erased) await sync.resumeAfterErase(restore: false);
}
