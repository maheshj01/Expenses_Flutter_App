import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../sync/remote_store.dart';
import '../../sync/sync_record.dart';

/// [RemoteStore] backed by Cloud Firestore.
///
/// Layout: `users/{uid}/{collection}/{recordId}`. Each document holds the
/// record's fields plus `updatedAt` (client edit time, for conflicts),
/// `deleted` (tombstone) and `serverUpdatedAt` (server write time, used as
/// the pull cursor so device clocks never matter for "what's new").
///
/// Pulls always read from the server: the app's local database is the
/// offline copy of personal data. Firestore's own cache is kept on for
/// shared bills, so they work offline too.
class FirebaseRemoteStore implements RemoteStore {
  FirebaseRemoteStore({FirebaseFirestore? firestore, FirebaseAuth? auth, this.pageSize = 300})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final int pageSize;

  /// Re-read this much history on each sync, to catch writes whose server
  /// timestamp landed just before the previous cursor.
  static const _safetyWindow = Duration(seconds: 5);
  static const _serverUpdatedAt = 'serverUpdatedAt';

  /// Configures Firestore once Firebase is initialized.
  static FirebaseRemoteStore configure() {
    final firestore = FirebaseFirestore.instance
      ..settings = const Settings(persistenceEnabled: true, cacheSizeBytes: 40 * 1024 * 1024);
    return FirebaseRemoteStore(firestore: firestore);
  }

  @override
  String get displayName => 'Firebase';

  /// Only an Apple or Google account backs up. Installs from before that
  /// may still hold an anonymous user: it doesn't sync, but signing in links
  /// to it and keeps its uid, so its old backup comes along.
  @override
  String? get accountId {
    final user = _auth.currentUser;
    return user == null || user.isAnonymous ? null : user.uid;
  }

  @override
  Future<void> connect() async {}

  CollectionReference<Map<String, dynamic>> _collection(String name) {
    final uid = accountId;
    if (uid == null) throw StateError('Not signed in');
    return _firestore.collection('users').doc(uid).collection(name);
  }

  @override
  Future<void> push(String collection, List<SyncRecord> records) async {
    final ref = _collection(collection);
    // Firestore batches are limited to 500 writes.
    for (var i = 0; i < records.length; i += 450) {
      final batch = _firestore.batch();
      for (final r in records.skip(i).take(450)) {
        batch.set(ref.doc(r.id), {
          ...r.data,
          'updatedAt': r.updatedAt,
          'deleted': r.deleted,
          _serverUpdatedAt: FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }
  }

  @override
  Future<PullResult> pull(String collection, {String? cursor}) async {
    final after = _Cursor.parse(cursor);
    Query<Map<String, dynamic>> query = _collection(collection)
        .orderBy(_serverUpdatedAt)
        .orderBy(FieldPath.documentId)
        .limit(pageSize);
    if (after != null) query = query.startAfter([after.timestamp, after.docId]);

    final snapshot = await query.get(const GetOptions(source: Source.server));
    final docs = snapshot.docs.where((d) => d.data()[_serverUpdatedAt] is Timestamp).toList();
    if (docs.isEmpty) return PullResult(records: const [], cursor: cursor);

    final records = docs.map(_toRecord).toList();
    final last = docs.last;
    final lastTs = last.data()[_serverUpdatedAt] as Timestamp;
    final hasMore = snapshot.docs.length == pageSize;
    final next = hasMore
        ? _Cursor(lastTs, last.id)
        : _Cursor(
            Timestamp.fromMicrosecondsSinceEpoch(
              lastTs.microsecondsSinceEpoch - _safetyWindow.inMicroseconds,
            ),
            '',
          );
    return PullResult(records: records, cursor: next.toString(), hasMore: hasMore);
  }

  @override
  String describeError(Object error) => describe(error);

  /// [describeError] without an instance, for tests.
  static String describe(Object error) {
    // Auth and Firestore errors are both FirebaseExceptions; their codes
    // don't overlap in ways that matter here.
    final code = error is FirebaseException ? error.code : null;
    return switch (code) {
      // A sign-in method is off in the Firebase console.
      'admin-restricted-operation' ||
      'operation-not-allowed' => 'Backup isn’t set up for this app yet.',
      'network-request-failed' ||
      'unavailable' ||
      'deadline-exceeded' => 'Can’t reach the backup server.',
      'too-many-requests' || 'resource-exhausted' => 'The backup server is busy.',
      'user-disabled' => 'This account has been turned off, so backup is paused.',
      'permission-denied' => 'Backup isn’t allowed for this account right now.',
      'unauthenticated' ||
      'user-token-expired' ||
      'invalid-user-token' => 'You were signed out of backup.',
      _ => 'Backup ran into a problem.',
    };
  }

  static SyncRecord _toRecord(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = Map<String, Object?>.of(doc.data());
    final updatedAt = (data.remove('updatedAt') as num?)?.toInt() ?? 0;
    final deleted = data.remove('deleted') as bool? ?? false;
    data.remove(_serverUpdatedAt);
    return SyncRecord(id: doc.id, data: data, updatedAt: updatedAt, deleted: deleted);
  }
}

/// Pull position: server timestamp plus document id to break ties.
class _Cursor {
  const _Cursor(this.timestamp, this.docId);

  final Timestamp timestamp;
  final String docId;

  static _Cursor? parse(String? value) {
    if (value == null || value.isEmpty) return null;
    final sep = value.indexOf('|');
    final micros = int.tryParse(sep < 0 ? value : value.substring(0, sep));
    if (micros == null) return null;
    return _Cursor(
      Timestamp.fromMicrosecondsSinceEpoch(micros),
      sep < 0 ? '' : value.substring(sep + 1),
    );
  }

  @override
  String toString() => '${timestamp.microsecondsSinceEpoch}|$docId';
}
