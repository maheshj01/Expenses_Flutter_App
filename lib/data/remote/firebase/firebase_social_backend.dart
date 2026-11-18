import 'dart:async';
import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../../core/day.dart';
import '../../../domain/social/account.dart';
import '../../../domain/social/connection.dart';
import '../../../domain/social/settlement.dart';
import '../../../domain/social/shared_bill.dart';
import '../../../domain/social/social_backend.dart';

/// [SocialBackend] on Firebase Auth + Cloud Firestore.
///
/// Layout (see `firestore.rules`):
/// - `handles/{handle}`: `{uid}`, makes usernames unique
/// - `profiles/{uid}`: `{handle, name}`
/// - `connections/{uidA_uidB}`: `{members, requestedBy, status, people}`
/// - `bills/{id}`: one shared bill, readable by its `members`
/// - `settlements/{id}`: readable by `from` and `to`
///
/// Writes are not awaited past the local cache: Firestore applies them
/// locally at once and sends them when online, which keeps sharing usable
/// offline.
class FirebaseSocialBackend implements SocialBackend {
  FirebaseSocialBackend({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _db = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  @override
  String get displayName => 'Firebase';

  @override
  List<SignInMethod> get signInMethods => [
    if (!kIsWeb && (Platform.isIOS || Platform.isMacOS)) SignInMethod.apple,
    SignInMethod.google,
  ];

  String get _uid {
    final account = currentAccount;
    if (account == null) throw const SocialError('Sign in to share bills');
    return account.uid;
  }

  // ---- account ----

  static Account? _toAccount(User? user) {
    if (user == null || user.isAnonymous) return null;
    final providers = user.providerData.map((p) => p.providerId);
    return Account(
      uid: user.uid,
      method: providers.contains('apple.com') ? SignInMethod.apple : SignInMethod.google,
      email: user.email,
      suggestedName: user.displayName ?? '',
    );
  }

  @override
  Account? get currentAccount => _toAccount(_auth.currentUser);

  @override
  Stream<Account?> watchAccount() => _auth.userChanges().map(_toAccount).distinct();

  AuthProvider _provider(SignInMethod method) => switch (method) {
    SignInMethod.apple => AppleAuthProvider()
      ..addScope('email')
      ..addScope('name'),
    SignInMethod.google => GoogleAuthProvider()..addScope('email'),
  };

  @override
  Future<void> signIn(SignInMethod method) async {
    final provider = _provider(method);
    final user = _auth.currentUser;
    try {
      if (user != null && user.isAnonymous) {
        // Keeps the uid, so data backed up so far stays with the account.
        await user.linkWithProvider(provider);
      } else {
        await _auth.signInWithProvider(provider);
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'credential-already-in-use' || e.code == 'email-already-in-use') {
        // This Apple / Google account was used before, e.g. on another
        // phone. Switch to it; sync then merges this device's data into it.
        final credential = e.credential;
        if (credential != null) {
          await _auth.signInWithCredential(credential);
        } else {
          await _auth.signInWithProvider(provider);
        }
      } else if (_isCancel(e)) {
        throw const SignInCancelled();
      } else {
        throw SocialError(e.message ?? 'Couldn’t sign in (${e.code})');
      }
    }
    await _auth.currentUser?.reload();
  }

  static bool _isCancel(FirebaseAuthException e) =>
      e.code.contains('cancel') || e.code == 'web-context-canceled' || e.code == '1001';

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final uid = user.uid;
    final profile = await _db.collection('profiles').doc(uid).get();
    final handle = profile.data()?['handle'] as String?;
    final connections = await _db
        .collection('connections')
        .where('members', arrayContains: uid)
        .get();
    final batch = _db.batch();
    for (final c in connections.docs) {
      batch.delete(c.reference);
    }
    if (handle != null) batch.delete(_db.collection('handles').doc(handle));
    batch.delete(profile.reference);
    await batch.commit();
    try {
      await user.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code != 'requires-recent-login') rethrow;
      final method = currentAccount?.method ?? SignInMethod.google;
      await user.reauthenticateWithProvider(_provider(method));
      await user.delete();
    }
  }

  // ---- profile ----

  @override
  Stream<Profile?> watchMyProfile() {
    final account = currentAccount;
    if (account == null) return Stream.value(null);
    return _db
        .collection('profiles')
        .doc(account.uid)
        .snapshots()
        .map((s) => s.exists ? Profile.fromJson(s.id, s.data()!) : null);
  }

  @override
  Future<Profile> claimHandle(String handle, String name) async {
    final uid = _uid;
    final handleRef = _db.collection('handles').doc(handle);
    final profileRef = _db.collection('profiles').doc(uid);
    await _db.runTransaction((tx) async {
      final existing = await tx.get(handleRef);
      final owner = existing.data()?['uid'];
      if (existing.exists && owner != uid) throw HandleTaken(handle);
      tx.set(handleRef, {'uid': uid});
      tx.set(profileRef, {'handle': handle, 'name': name});
    });
    return Profile(uid: uid, handle: handle, name: name);
  }

  @override
  Future<Profile?> findByHandle(String handle) async {
    if (Handle.validate(handle) != null) return null;
    final owner = await _db.collection('handles').doc(handle).get();
    final uid = owner.data()?['uid'] as String?;
    if (uid == null) return null;
    final profile = await _db.collection('profiles').doc(uid).get();
    return profile.exists ? Profile.fromJson(uid, profile.data()!) : null;
  }

  // ---- connections ----

  CollectionReference<Map<String, dynamic>> get _connections => _db.collection('connections');

  @override
  Stream<List<Connection>> watchConnections() {
    final uid = currentAccount?.uid;
    if (uid == null) return Stream.value(const []);
    return _connections.where('members', arrayContains: uid).snapshots().map((s) {
      return [for (final doc in s.docs) ?_toConnection(uid, doc.id, doc.data())];
    });
  }

  static Connection? _toConnection(String me, String id, Map<String, dynamic> d) {
    final members = List<String>.from(d['members'] as List? ?? const []);
    final other = members.where((m) => m != me).firstOrNull;
    if (other == null) return null;
    final people = Map<String, dynamic>.from(d['people'] as Map? ?? const {});
    return Connection(
      id: id,
      other: Profile.fromJson(other, Map<String, Object?>.from(people[other] as Map? ?? const {})),
      status: d['status'] == 'accepted' ? ConnectionStatus.accepted : ConnectionStatus.pending,
      requestedByMe: d['requestedBy'] == me,
      createdAt: DateTime.fromMillisecondsSinceEpoch((d['createdAt'] as num?)?.toInt() ?? 0),
    );
  }

  @override
  Future<void> requestConnection(Profile me, Profile other) async {
    final id = Connection.pairId(me.uid, other.uid);
    final ref = _connections.doc(id);
    final existing = await ref.get();
    if (existing.exists) {
      final d = existing.data()!;
      if (d['status'] == 'pending' && d['requestedBy'] == other.uid) await acceptConnection(id);
      return;
    }
    final members = [me.uid, other.uid]..sort();
    _write(
      ref.set({
        'members': members,
        'requestedBy': me.uid,
        'status': 'pending',
        'people': {me.uid: me.toJson(), other.uid: other.toJson()},
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      }),
    );
  }

  @override
  Future<void> acceptConnection(String connectionId) async {
    _write(_connections.doc(connectionId).update({'status': 'accepted'}));
  }

  @override
  Future<void> removeConnection(String connectionId) async {
    _write(_connections.doc(connectionId).delete());
  }

  // ---- bills ----

  CollectionReference<Map<String, dynamic>> get _bills => _db.collection('bills');

  @override
  Stream<BillsSnapshot> watchBills() {
    final uid = currentAccount?.uid;
    if (uid == null) return Stream.value(BillsSnapshot.empty);
    return _bills
        .where('members', arrayContains: uid)
        .snapshots(includeMetadataChanges: true)
        .map(
          (s) => BillsSnapshot([
            for (final doc in s.docs) _toBill(doc.id, doc.data()),
          ], complete: !s.metadata.isFromCache),
        );
  }

  static SharedBill _toBill(String id, Map<String, dynamic> d) {
    int ms(String key) => (d[key] as num?)?.toInt() ?? 0;
    final people = Map<String, dynamic>.from(d['people'] as Map? ?? const {});
    final flags = Map<String, dynamic>.from(d['flags'] as Map? ?? const {});
    return SharedBill(
      id: id,
      createdBy: d['createdBy'] as String? ?? '',
      members: List<String>.from(d['members'] as List? ?? const []),
      people: {
        for (final MapEntry(:key, :value) in people.entries)
          key: Profile.fromJson(key, Map<String, Object?>.from(value as Map)),
      },
      guests: ms('guests'),
      amountCents: ms('amountCents'),
      currencyCode: d['currencyCode'] as String? ?? 'USD',
      date: DayKey.toDate(ms('day')),
      note: d['note'] as String? ?? '',
      memo: d['memo'] as String? ?? '',
      categoryId: d['categoryId'] as String? ?? 'misc',
      flags: {
        for (final MapEntry(:key, :value) in flags.entries)
          if (value is Map) key: BillFlag.fromJson(Map<String, Object?>.from(value)),
      },
      createdAt: DateTime.fromMillisecondsSinceEpoch(ms('createdAt')),
      editedAt: DateTime.fromMillisecondsSinceEpoch(ms('editedAt')),
      deleted: d['deleted'] as bool? ?? false,
    );
  }

  @override
  Future<void> saveBill(SharedBill bill) async {
    _uid; // must be signed in
    _write(
      _bills.doc(bill.id).set({
        'createdBy': bill.createdBy,
        'members': bill.members,
        'people': {for (final p in bill.people.values) p.uid: p.toJson()},
        'guests': bill.guests,
        'amountCents': bill.amountCents,
        'currencyCode': bill.currencyCode,
        'day': DayKey.fromDate(bill.date),
        'note': bill.note,
        'memo': bill.memo,
        'categoryId': bill.categoryId,
        'flags': <String, Object?>{},
        'createdAt': bill.createdAt.millisecondsSinceEpoch,
        'editedAt': bill.editedAt.millisecondsSinceEpoch,
        'deleted': bill.deleted,
      }),
    );
  }

  @override
  Future<void> setFlag(String billId, BillFlag? flag) async {
    final uid = _uid;
    _write(
      _bills.doc(billId).update({
        FieldPath(['flags', uid]): flag?.toJson() ?? FieldValue.delete(),
      }),
    );
  }

  // ---- settlements ----

  CollectionReference<Map<String, dynamic>> get _settlements => _db.collection('settlements');

  @override
  Stream<List<Settlement>> watchSettlements() {
    final uid = currentAccount?.uid;
    if (uid == null) return Stream.value(const []);
    return _settlements.where('members', arrayContains: uid).snapshots().map((s) {
      return [
        for (final doc in s.docs)
          Settlement(
            id: doc.id,
            from: doc['from'] as String,
            to: doc['to'] as String,
            amountCents: (doc['amountCents'] as num).toInt(),
            currencyCode: doc['currencyCode'] as String? ?? 'USD',
            date: DayKey.toDate((doc['day'] as num).toInt()),
            createdBy: doc['createdBy'] as String,
            createdAt: DateTime.fromMillisecondsSinceEpoch((doc['createdAt'] as num).toInt()),
          ),
      ];
    });
  }

  @override
  Future<void> addSettlement(Settlement s) async {
    _uid;
    _write(
      _settlements.doc(s.id).set({
        'from': s.from,
        'to': s.to,
        'members': s.members,
        'amountCents': s.amountCents,
        'currencyCode': s.currencyCode,
        'day': DayKey.fromDate(s.date),
        'createdBy': s.createdBy,
        'createdAt': s.createdAt.millisecondsSinceEpoch,
      }),
    );
  }

  @override
  Future<void> deleteSettlement(String id) async {
    _write(_settlements.doc(id).delete());
  }

  /// Firestore applies writes to its local cache right away and completes
  /// the future only once the server confirms, which never happens while
  /// offline. So don't wait; just report failures.
  static void _write(Future<void> write) {
    unawaited(write.catchError((Object e) => debugPrint('Sharing write failed: $e')));
  }
}
