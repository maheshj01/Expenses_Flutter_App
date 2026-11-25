import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../domain/account/account_deletion.dart';

/// [AccountDeletion] through the Cloud Functions in
/// `functions/src/accountDeletion.ts`. The pending marker is read straight
/// from `users/{uid}`, which the owner may read but never write.
class FirebaseAccountDeletion implements AccountDeletion {
  FirebaseAccountDeletion({FirebaseFunctions? functions, FirebaseFirestore? db, FirebaseAuth? auth})
    : _functions = functions ?? FirebaseFunctions.instance,
      _db = db ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFunctions _functions;
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  @override
  Future<DeletionOutcome> request() async {
    // Nobody signed in, not even an anonymous user left from versions that
    // backed up without signing in: nothing of theirs is on the server.
    if (_auth.currentUser == null) return const Erased();
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
