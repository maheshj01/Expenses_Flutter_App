import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../../domain/account/account_deletion.dart';

/// [AccountDeletion] through the Cloud Functions in
/// `functions/src/accountDeletion.ts`. The pending marker is read straight
/// from `users/{uid}`, which the owner may read but never write.
class FirebaseAccountDeletion implements AccountDeletion {
  FirebaseAccountDeletion({FirebaseFunctions? functions, FirebaseFirestore? db})
    : _functions = functions ?? FirebaseFunctions.instance,
      _db = db ?? FirebaseFirestore.instance;

  final FirebaseFunctions _functions;
  final FirebaseFirestore _db;

  @override
  Future<DeletionOutcome> request() async {
    final result = await _functions
        .httpsCallable(
          'requestAccountDeletion',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
        )
        .call<Map<Object?, Object?>>();
    final purgeAfter = result.data['purgeAfter'];
    if (purgeAfter is int) return Scheduled(DateTime.fromMillisecondsSinceEpoch(purgeAfter));
    return const Erased();
  }

  @override
  Future<void> restore() => _functions.httpsCallable('restoreAccount').call<void>();

  @override
  Future<DateTime?> pendingPurge(String uid) async {
    final doc = await _db.collection('users').doc(uid).get(const GetOptions(source: Source.server));
    final deletion = doc.data()?['deletion'];
    if (deletion is! Map) return null;
    final purgeAfter = deletion['purgeAfter'];
    if (purgeAfter is! Timestamp) return null;
    // Marked for being away too long, not by the person: coming back is the
    // answer, so cancel it without asking. If that fails (offline), say so:
    // the mark still freezes the backup, and the pending screen's Restore
    // retries.
    if (deletion['reason'] == 'inactive') {
      try {
        await restore();
        return null;
      } on Object {
        return purgeAfter.toDate();
      }
    }
    return purgeAfter.toDate();
  }
}
