import 'dart:async';

import 'package:three_bucks/domain/social/account.dart';
import 'package:three_bucks/domain/social/connection.dart';
import 'package:three_bucks/domain/social/settlement.dart';
import 'package:three_bucks/domain/social/shared_bill.dart';
import 'package:three_bucks/domain/social/social_backend.dart';

/// The shared "server" several [FakeSocialBackend] clients talk to. It
/// enforces the same rules as `firestore.rules`.
class FakeSocialServer {
  final profiles = <String, Profile>{};
  final handles = <String, String>{};
  final connections = <String, FakeConnection>{};
  final bills = <String, SharedBill>{};
  final settlements = <String, Settlement>{};
  final _changes = StreamController<void>.broadcast();

  Stream<void> get changes => _changes.stream;

  void changed() => _changes.add(null);

  /// Seeds a profile, as if that person had signed up.
  Profile addPerson(String uid, String handle, String name) {
    final p = Profile(uid: uid, handle: handle, name: name);
    profiles[uid] = p;
    handles[handle] = uid;
    return p;
  }

  /// Seeds a connection between [a] and [b].
  void connect(Profile a, Profile b, {bool accepted = true, DateTime? at}) {
    connections[Connection.pairId(a.uid, b.uid)] = FakeConnection(
      members: [a.uid, b.uid],
      requestedBy: a.uid,
      accepted: accepted,
      people: {a.uid: a, b.uid: b},
      createdAt: at ?? DateTime(2026, 11, 1),
    );
    changed();
  }

  Future<void> dispose() => _changes.close();
}

class FakeConnection {
  FakeConnection({
    required this.members,
    required this.requestedBy,
    required this.accepted,
    required this.people,
    required this.createdAt,
  });

  final List<String> members;
  final String requestedBy;
  bool accepted;
  final Map<String, Profile> people;
  final DateTime createdAt;
}

/// One person's app talking to [FakeSocialServer].
class FakeSocialBackend implements SocialBackend {
  FakeSocialBackend(this.server, {required this.signInAs, bool signedIn = false})
    : _account = signedIn ? signInAs : null;

  final FakeSocialServer server;

  /// The account [signIn] signs in to.
  final Account signInAs;
  Account? _account;
  final _accountChanges = StreamController<Account?>.broadcast();

  /// Set to make the next sign-in look cancelled.
  bool cancelNextSignIn = false;

  @override
  String get displayName => 'Fake';

  @override
  List<SignInMethod> get signInMethods => SignInMethod.values;

  String get _me => _account?.uid ?? (throw const SocialError('Sign in to share bills'));

  Stream<T> _watch<T>(T Function() read) async* {
    yield read();
    await for (final _ in server.changes) {
      yield read();
    }
  }

  @override
  Account? get currentAccount => _account;

  @override
  Stream<Account?> watchAccount() async* {
    yield _account;
    yield* _accountChanges.stream;
  }

  @override
  Future<void> signIn(SignInMethod method) async {
    if (cancelNextSignIn) {
      cancelNextSignIn = false;
      throw const SignInCancelled();
    }
    _account = signInAs;
    _accountChanges.add(_account);
  }

  @override
  Future<void> signOut() async {
    _account = null;
    _accountChanges.add(null);
  }

  @override
  Future<void> deleteAccount() async {
    final me = _me;
    final profile = server.profiles.remove(me);
    if (profile != null) server.handles.remove(profile.handle);
    server.connections.removeWhere((_, c) => c.members.contains(me));
    server.changed();
    await signOut();
  }

  @override
  Stream<Profile?> watchMyProfile() => _watch(() => server.profiles[_account?.uid]);

  @override
  Future<Profile> claimHandle(String handle, String name) async {
    final me = _me;
    final owner = server.handles[handle];
    if (owner != null && owner != me) throw HandleTaken(handle);
    final old = server.profiles[me];
    if (old != null && old.handle != handle) server.handles.remove(old.handle);
    final profile = server.addPerson(me, handle, name);
    server.changed();
    return profile;
  }

  @override
  Future<Profile?> findByHandle(String handle) async {
    _me;
    final uid = server.handles[handle];
    return uid == null ? null : server.profiles[uid];
  }

  @override
  Stream<List<Connection>> watchConnections() => _watch(() {
    final me = _account?.uid;
    if (me == null) return const <Connection>[];
    return [
      for (final MapEntry(key: id, value: c) in server.connections.entries)
        if (c.members.contains(me))
          Connection(
            id: id,
            other: c.people[c.members.firstWhere((m) => m != me)]!,
            status: c.accepted ? ConnectionStatus.accepted : ConnectionStatus.pending,
            requestedByMe: c.requestedBy == me,
            createdAt: c.createdAt,
          ),
    ];
  });

  @override
  Future<void> requestConnection(Profile me, Profile other) async {
    final id = Connection.pairId(me.uid, other.uid);
    final existing = server.connections[id];
    if (existing != null) {
      if (!existing.accepted && existing.requestedBy == other.uid) await acceptConnection(id);
      return;
    }
    server.connections[id] = FakeConnection(
      members: [me.uid, other.uid],
      requestedBy: me.uid,
      accepted: false,
      people: {me.uid: me, other.uid: other},
      createdAt: DateTime.now(),
    );
    server.changed();
  }

  @override
  Future<void> acceptConnection(String connectionId) async {
    final c = server.connections[connectionId];
    if (c == null || !c.members.contains(_me) || c.requestedBy == _me) {
      throw const SocialError('permission-denied');
    }
    c.accepted = true;
    server.changed();
  }

  @override
  Future<void> removeConnection(String connectionId) async {
    final c = server.connections[connectionId];
    if (c == null) return;
    if (!c.members.contains(_me)) throw const SocialError('permission-denied');
    server.connections.remove(connectionId);
    server.changed();
  }

  @override
  Stream<BillsSnapshot> watchBills() => _watch(() {
    final me = _account?.uid;
    if (me == null) return BillsSnapshot.empty;
    return BillsSnapshot([
      for (final b in server.bills.values)
        if (b.members.contains(me)) b,
    ], complete: true);
  });

  @override
  Future<void> saveBill(SharedBill bill) async {
    final me = _me;
    final existing = server.bills[bill.id];
    if (bill.createdBy != me || !bill.members.contains(me)) {
      throw const SocialError('permission-denied');
    }
    if (existing != null && existing.createdBy != me) throw const SocialError('permission-denied');
    server.bills[bill.id] = bill;
    server.changed();
  }

  @override
  Future<void> setFlag(String billId, BillFlag? flag) async {
    final me = _me;
    final bill = server.bills[billId];
    if (bill == null || !bill.members.contains(me)) throw const SocialError('permission-denied');
    final flags = {...bill.flags}..remove(me);
    if (flag != null) flags[me] = flag;
    server.bills[billId] = bill.copyWith(flags: flags);
    server.changed();
  }

  @override
  Stream<List<Settlement>> watchSettlements() => _watch(() {
    final me = _account?.uid;
    if (me == null) return const <Settlement>[];
    return [
      for (final s in server.settlements.values)
        if (s.members.contains(me)) s,
    ];
  });

  @override
  Future<void> addSettlement(Settlement settlement) async {
    if (settlement.createdBy != _me || !settlement.members.contains(_me)) {
      throw const SocialError('permission-denied');
    }
    server.settlements[settlement.id] = settlement;
    server.changed();
  }

  @override
  Future<void> deleteSettlement(String id) async {
    final s = server.settlements[id];
    if (s == null) return;
    if (s.createdBy != _me) throw const SocialError('permission-denied');
    server.settlements.remove(id);
    server.changed();
  }
}
