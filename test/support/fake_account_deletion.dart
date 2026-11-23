import 'package:three_bucks/domain/account/account_deletion.dart';

import 'fake_social.dart';

/// [AccountDeletion] against [FakeSocialServer], doing what
/// `functions/src/accountDeletion.ts` and the janitor do.
class FakeAccountDeletion implements AccountDeletion {
  FakeAccountDeletion(this.server, {required this.currentUid, DateTime Function()? clock})
    : clock = clock ?? DateTime.now;

  final FakeSocialServer server;

  /// The account the calls come from: the signed-in one, or null for an
  /// anonymous install.
  final String? Function() currentUid;
  final DateTime Function() clock;

  /// When each frozen account will be purged.
  final purgeAfter = <String, DateTime>{};

  /// Anonymous backups erased at once.
  int erasedAnonymous = 0;

  /// Set to make the next request fail, as if offline.
  bool failNext = false;

  @override
  Future<DeletionOutcome> request() async {
    if (failNext) {
      failNext = false;
      throw StateError('offline');
    }
    final uid = currentUid();
    if (uid == null) {
      erasedAnonymous++;
      return const Erased();
    }
    final at = purgeAfter[uid] ??= clock().add(const Duration(days: AccountDeletion.graceDays));
    server
      ..frozen.add(uid)
      ..changed();
    return Scheduled(at);
  }

  @override
  Future<void> restore() async {
    if (failNext) {
      failNext = false;
      throw StateError('offline');
    }
    final uid = currentUid();
    if (uid == null) return;
    purgeAfter.remove(uid);
    server
      ..frozen.remove(uid)
      ..changed();
  }

  @override
  Future<DateTime?> pendingPurge(String uid) async => purgeAfter[uid];

  /// The janitor's nightly purge.
  void purgeDue(DateTime now) {
    for (final MapEntry<String, DateTime>(key: uid, value: at) in [...purgeAfter.entries]) {
      if (now.isBefore(at)) continue;
      final profile = server.profiles.remove(uid);
      if (profile != null) server.handles.remove(profile.handle);
      server.connections.removeWhere((_, c) => c.members.contains(uid));
      server.blocks.remove(uid);
      for (final b in server.blocks.values) {
        b.remove(uid);
      }
      server.frozen.remove(uid);
      server.deletedAccounts.add(uid);
      purgeAfter.remove(uid);
    }
    server.changed();
  }
}
