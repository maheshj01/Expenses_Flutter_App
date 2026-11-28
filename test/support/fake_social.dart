import 'dart:async';

import 'package:three_bucks/core/ids.dart';
import 'package:three_bucks/domain/history/edit.dart';
import 'package:three_bucks/domain/social/account.dart';
import 'package:three_bucks/domain/social/connection.dart';
import 'package:three_bucks/domain/social/safety.dart';
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

  /// Recorded edits per bill id, oldest first. Write-once, like the rules.
  final billEdits = <String, List<Edit>>{};

  /// Who blocked whom: blocker uid -> blocked uid -> person.
  final blocks = <String, Map<String, BlockedPerson>>{};

  /// Accounts frozen while waiting to be deleted (see `FakeAccountDeletion`):
  /// they can't be looked up or asked to connect.
  final frozen = <String>{};

  /// Accounts deleted for good: signing in to them fails.
  final deletedAccounts = <String>{};

  /// Reports sent, with the reporter's uid.
  final reports = <(String reporter, Report report)>[];
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

  bool blocked(String blocker, String other) => blocks[blocker]?.containsKey(other) ?? false;

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
  List<SignInMethod> get signInMethods => methods;

  /// What this device offers; every method unless a test narrows it.
  List<SignInMethod> methods = SignInMethod.values;

  /// Set when [signInAs]'s email already has an account made this way:
  /// signing in another way then throws [EmailHasAccount], like Firebase's
  /// one account per email.
  SignInMethod? emailAccountUses;

  /// Methods added to the account by signing in with [emailAccountUses]
  /// after [EmailHasAccount].
  final linkedMethods = <SignInMethod>{};
  SignInMethod? _pendingMethod;

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
    if (server.deletedAccounts.contains(signInAs.uid)) {
      throw const SocialError('This account was deleted');
    }
    final existing = emailAccountUses;
    if (existing != null && method != existing && !linkedMethods.contains(method)) {
      _pendingMethod = method;
      throw EmailHasAccount(attempted: method, existing: existing, email: signInAs.email);
    }
    if (method == existing && _pendingMethod != null) linkedMethods.add(_pendingMethod!);
    _pendingMethod = null;
    _account = signInAs;
    _accountChanges.add(_account);
  }

  @override
  Future<void> signOut() async {
    _account = null;
    _accountChanges.add(null);
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
    // Like the rules: hidden from people they blocked, and while waiting to
    // be deleted.
    if (uid == null || server.blocked(uid, _me) || server.frozen.contains(uid)) return null;
    return server.profiles[uid];
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
    // Like the rules: refused when either side blocked the other.
    if (server.blocked(me.uid, other.uid) || server.blocked(other.uid, me.uid)) return;
    if (server.frozen.contains(me.uid) || server.frozen.contains(other.uid)) return;
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
    if (existing != null) {
      final changes = billChanges(existing, bill);
      if (changes.isNotEmpty) {
        server.billEdits
            .putIfAbsent(bill.id, () => [])
            .add(
              Edit(id: newId(), subjectId: bill.id, at: DateTime.now(), by: me, changes: changes),
            );
      }
    }
    server.changed();
  }

  @override
  Stream<List<Edit>> watchBillEdits(String billId) => _watch(() {
    final me = _account?.uid;
    final bill = server.bills[billId];
    if (me == null || bill == null || !bill.members.contains(me)) return const <Edit>[];
    return [...?server.billEdits[billId]].reversed.toList();
  });

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

  @override
  Stream<List<BlockedPerson>> watchBlocked() => _watch(() {
    final me = _account?.uid;
    if (me == null) return const <BlockedPerson>[];
    return [...?server.blocks[me]?.values]..sort((a, b) => b.at.compareTo(a.at));
  });

  @override
  Future<void> block(Profile other) async {
    final me = _me;
    server.blocks.putIfAbsent(me, () => {})[other.uid] = BlockedPerson(
      profile: other,
      at: DateTime.now(),
    );
    server.connections.remove(Connection.pairId(me, other.uid));
    server.changed();
  }

  @override
  Future<void> unblock(String uid) async {
    server.blocks[_me]?.remove(uid);
    server.changed();
  }

  @override
  Future<void> report(Report report) async {
    if (report.note.length > Report.maxNote) throw const SocialError('permission-denied');
    server.reports.add((_me, report));
    server.changed();
  }
}
