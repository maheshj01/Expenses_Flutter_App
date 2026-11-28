import 'dart:async';
import 'dart:developer' show log;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/day.dart';
import '../../../core/ids.dart';
import '../../../domain/history/edit.dart';
import '../../../domain/social/account.dart';
import '../../../domain/social/connection.dart';
import '../../../domain/social/safety.dart';
import '../../../domain/social/settlement.dart';
import '../../../domain/social/shared_bill.dart';
import '../../../domain/social/social_backend.dart';

/// Sign in with Apple is offered on iOS only; Google on every platform.
@visibleForTesting
List<SignInMethod> signInMethodsFor(TargetPlatform platform, {bool isWeb = kIsWeb}) => [
  if (!isWeb && platform == TargetPlatform.iOS) SignInMethod.apple,
  SignInMethod.google,
];

/// [SocialBackend] on Firebase Auth + Cloud Firestore.
///
/// Layout (see `firestore.rules`):
/// - `handles/{handle}`: `{uid}`, makes usernames unique
/// - `profiles/{uid}`: `{handle, name}`
/// - `connections/{uidA_uidB}`: `{members, requestedBy, status, people}`
/// - `bills/{id}`: one shared bill, readable by its `members`
/// - `bills/{id}/edits/{editId}`: `{by, at, changes}`, what each edit changed; write-once
/// - `settlements/{id}`: readable by `from` and `to`
/// - `blocks/{blocker_blocked}`: `{blocker, blocked, profile, at}`
/// - `reports/{id}`: write-only, read by moderators in the Firebase console
/// - `users/{uid}/devices/{deviceId}`: `{fid, platform, updatedAt}`, where this
///   phone gets notifications (see `FirebasePushService`)
/// - `users/{uid}.deletion`: set by the account deletion functions, never by
///   the app (see `FirebaseAccountDeletion`)
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
  List<SignInMethod> get signInMethods => signInMethodsFor(defaultTargetPlatform);

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

  bool _googleReady = false;

  /// What the person last signed in with when its email turned out to be on
  /// an account that uses the other method. Added to that account when they
  /// sign in to it, which makes it one account.
  SignInMethod? _pendingMethod;
  AuthCredential? _pendingCredential;

  @override
  Future<void> signIn(SignInMethod method) async {
    AuthCredential? google;
    try {
      if (method == SignInMethod.google) {
        google = await _googleCredential();
        await _signInOrLink(credential: google);
      } else {
        await _signInOrLink(provider: _appleProvider());
      }
    } on FirebaseAuthException catch (e) {
      if (_isCancel(e)) throw const SignInCancelled();
      if (e.code == 'account-exists-with-different-credential') {
        _pendingMethod = method;
        _pendingCredential = e.credential ?? google;
        throw EmailHasAccount(attempted: method, existing: method.other, email: e.email);
      }
      throw SocialError(e.message ?? 'Couldn’t sign in (${e.code})');
    }
    await _addPending(method);
    await _auth.currentUser?.reload();
  }

  /// Links the sign-in to the anonymous user, which keeps the uid and the
  /// data backed up so far. If that Apple / Google account was used before,
  /// e.g. on another phone, switches to it; sync then merges this device's
  /// data into it.
  Future<void> _signInOrLink({AuthCredential? credential, AuthProvider? provider}) async {
    final user = _auth.currentUser;
    if (user != null && user.isAnonymous) {
      try {
        if (credential != null) {
          await user.linkWithCredential(credential);
        } else {
          await user.linkWithProvider(provider!);
        }
        return;
      } on FirebaseAuthException catch (e) {
        if (e.code != 'credential-already-in-use' && e.code != 'email-already-in-use') rethrow;
        credential ??= e.credential;
      }
    }
    if (credential != null) {
      await _auth.signInWithCredential(credential);
    } else {
      await _auth.signInWithProvider(provider!);
    }
  }

  /// Adds the method held since [EmailHasAccount] to the account just
  /// signed in to with [method]. The person is signed in either way, so a
  /// failure here only means being asked again next time.
  Future<void> _addPending(SignInMethod method) async {
    final pending = _pendingMethod;
    final credential = _pendingCredential;
    _pendingMethod = null;
    _pendingCredential = null;
    final user = _auth.currentUser;
    if (pending == null || pending == method || user == null) return;
    try {
      if (credential != null) {
        await user.linkWithCredential(credential);
      } else if (pending == SignInMethod.google) {
        await user.linkWithCredential(await _googleCredential());
      } else {
        await user.linkWithProvider(_appleProvider());
      }
    } on Object catch (e) {
      log('Couldn’t add ${pending.label} to the account: $e', name: 'Auth');
    }
  }

  /// Asks for the email and name: without the email Firebase can't tell the
  /// person already has an account under it and would make a second one.
  AuthProvider _appleProvider() => AppleAuthProvider()
    ..addScope('email')
    ..addScope('name');

  /// The native Google account picker.
  Future<AuthCredential> _googleCredential() async {
    try {
      if (!_googleReady) {
        await GoogleSignIn.instance.initialize();
        _googleReady = true;
      }
      final account = await GoogleSignIn.instance.authenticate(scopeHint: const ['email']);
      final idToken = account.authentication.idToken;
      if (idToken == null) throw const SocialError('Google didn’t return an ID token');
      return GoogleAuthProvider.credential(idToken: idToken);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) throw const SignInCancelled();
      throw SocialError(e.description ?? 'Couldn’t sign in with Google (${e.code.name})');
    }
  }

  static bool _isCancel(FirebaseAuthException e) =>
      e.code.contains('cancel') || e.code == 'web-context-canceled' || e.code == '1001';

  @override
  Future<void> signOut() async {
    _pendingMethod = null;
    _pendingCredential = null;
    // So the next Google sign-in shows the account picker again.
    if (_googleReady) await GoogleSignIn.instance.signOut();
    await _auth.signOut();
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
    try {
      final profile = await _db.collection('profiles').doc(uid).get();
      return profile.exists ? Profile.fromJson(uid, profile.data()!) : null;
    } on FirebaseException catch (e) {
      // They blocked you: to you, they don't exist.
      if (e.code == 'permission-denied') return null;
      rethrow;
    }
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
      guestNames: [
        for (final n in d['guestNames'] as List? ?? const [])
          if (n is String) n,
      ].take(ms('guests')).toList(),
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
    final me = _uid; // must be signed in
    final ref = _bills.doc(bill.id);
    // The version this device last saw, to record what changed. Bills you're
    // on are always in the cache (watchBills listens to them), so this works
    // offline too. A new bill has nothing to compare with.
    SharedBill? before;
    try {
      final cached = await ref.get(const GetOptions(source: Source.cache));
      if (cached.exists) before = _toBill(cached.id, cached.data()!);
    } on FirebaseException {
      before = null;
    }
    final batch = _db.batch()
      ..set(ref, {
        'createdBy': bill.createdBy,
        'members': bill.members,
        'people': {for (final p in bill.people.values) p.uid: p.toJson()},
        'guests': bill.guests,
        'guestNames': bill.guestNames,
        'amountCents': bill.amountCents,
        'currencyCode': bill.currencyCode,
        'day': DayKey.fromDate(bill.date),
        'note': bill.note,
        'memo': bill.memo,
        'categoryId': bill.categoryId,
        'flags': {for (final MapEntry(:key, :value) in bill.flags.entries) key: value.toJson()},
        'createdAt': bill.createdAt.millisecondsSinceEpoch,
        'editedAt': bill.editedAt.millisecondsSinceEpoch,
        'deleted': bill.deleted,
      });
    final changes = before == null ? const <EditField, FieldChange>{} : billChanges(before, bill);
    if (changes.isNotEmpty) {
      batch.set(ref.collection('edits').doc(newId()), {
        'by': me,
        'at': bill.editedAt.millisecondsSinceEpoch,
        'changes': Edit.changesToJson(changes),
      });
    }
    _write(batch.commit());
  }

  @override
  Stream<List<Edit>> watchBillEdits(String billId) {
    if (currentAccount == null) return Stream.value(const []);
    return _bills
        .doc(billId)
        .collection('edits')
        .orderBy('at', descending: true)
        .snapshots()
        .map(
          (s) => [
            for (final doc in s.docs)
              Edit(
                id: doc.id,
                subjectId: billId,
                at: DateTime.fromMillisecondsSinceEpoch((doc.data()['at'] as num?)?.toInt() ?? 0),
                by: doc.data()['by'] as String?,
                changes: Edit.changesFromJson(doc.data()['changes']),
              ),
          ],
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

  // ---- safety ----

  CollectionReference<Map<String, dynamic>> get _blocks => _db.collection('blocks');

  @override
  Stream<List<BlockedPerson>> watchBlocked() {
    final uid = currentAccount?.uid;
    if (uid == null) return Stream.value(const []);
    return _blocks.where('blocker', isEqualTo: uid).snapshots().map((s) {
      final people = [
        for (final doc in s.docs)
          BlockedPerson(
            profile: Profile.fromJson(
              doc['blocked'] as String,
              Map<String, Object?>.from(doc.data()['profile'] as Map? ?? const {}),
            ),
            at: DateTime.fromMillisecondsSinceEpoch((doc.data()['at'] as num?)?.toInt() ?? 0),
          ),
      ];
      return people..sort((a, b) => b.at.compareTo(a.at));
    });
  }

  @override
  Future<void> block(Profile other) async {
    final me = _uid;
    _write(
      _blocks.doc('${me}_${other.uid}').set({
        'blocker': me,
        'blocked': other.uid,
        'profile': other.toJson(),
        'at': DateTime.now().millisecondsSinceEpoch,
      }),
    );
    // The rules refuse deleting a connection that doesn't exist, so look
    // first (from the cache when offline).
    final connection = _connections.doc(Connection.pairId(me, other.uid));
    try {
      if ((await connection.get()).exists) _write(connection.delete());
    } on FirebaseException catch (e) {
      debugPrint('Couldn’t check the connection while blocking: $e');
    }
  }

  @override
  Future<void> unblock(String uid) async {
    _write(_blocks.doc('${_uid}_$uid').delete());
  }

  @override
  Future<void> report(Report report) async {
    final me = _uid;
    _write(
      _db.collection('reports').doc(report.id).set({
        'reporter': me,
        'reportedUid': report.reported.uid,
        'reported': report.reported.toJson(),
        'reason': report.reason.name,
        'note': report.note,
        'billId': report.billId,
        'at': report.at.millisecondsSinceEpoch,
        'createdAt': FieldValue.serverTimestamp(),
      }),
    );
  }

  /// Firestore applies writes to its local cache right away and completes
  /// the future only once the server confirms, which never happens while
  /// offline. So don't wait; just report failures.
  static void _write(Future<void> write) {
    unawaited(write.catchError((Object e) => debugPrint('Sharing write failed: $e')));
  }
}
