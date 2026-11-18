import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/social/bill_projector.dart';
import '../domain/social/account.dart';
import '../domain/social/balances.dart';
import '../domain/social/connection.dart';
import '../domain/social/inbox.dart';
import '../domain/social/settlement.dart';
import '../domain/social/shared_bill.dart';
import '../domain/social/social_backend.dart';
import 'providers.dart';

/// The sharing backend, or null in local-only mode. Overridden in main().
final socialBackendProvider = Provider<SocialBackend?>((ref) => null);

/// The signed-in account; null when using the app without one.
final accountProvider = StreamProvider<Account?>((ref) {
  final backend = ref.watch(socialBackendProvider);
  return backend == null ? Stream.value(null) : backend.watchAccount();
});

/// Rebuilds dependants when a different account signs in.
String? _uid(Ref ref) => ref.watch(accountProvider.select((a) => a.value?.uid));

final myProfileProvider = StreamProvider<Profile?>((ref) {
  final backend = ref.watch(socialBackendProvider);
  if (backend == null || _uid(ref) == null) return Stream.value(null);
  return backend.watchMyProfile();
});

final connectionsProvider = StreamProvider<List<Connection>>((ref) {
  final backend = ref.watch(socialBackendProvider);
  if (backend == null || _uid(ref) == null) return Stream.value(const []);
  return backend.watchConnections();
});

/// People you can split bills with, by name.
final friendsProvider = Provider<List<Connection>>((ref) {
  final all = ref.watch(connectionsProvider).value ?? const [];
  return all.where((c) => c.isAccepted).toList()..sort(
    (a, b) => a.other.displayName.toLowerCase().compareTo(b.other.displayName.toLowerCase()),
  );
});

final billsProvider = StreamProvider<BillsSnapshot>((ref) {
  final backend = ref.watch(socialBackendProvider);
  if (backend == null || _uid(ref) == null) return Stream.value(BillsSnapshot.empty);
  return backend.watchBills();
});

final billMapProvider = Provider<Map<String, SharedBill>>((ref) {
  final bills = ref.watch(billsProvider).value?.bills ?? const [];
  return {for (final b in bills) b.id: b};
});

final settlementsProvider = StreamProvider<List<Settlement>>((ref) {
  final backend = ref.watch(socialBackendProvider);
  if (backend == null || _uid(ref) == null) return Stream.value(const []);
  return backend.watchSettlements();
});

final balancesProvider = Provider<Balances>((ref) {
  final me = _uid(ref);
  if (me == null) return Balances.empty;
  return Balances.of(
    me,
    ref.watch(billsProvider).value?.bills ?? const [],
    ref.watch(settlementsProvider).value ?? const [],
  );
});

/// Bills shared with one person, newest first.
final billsWithProvider = Provider.family<List<SharedBill>, String>((ref, uid) {
  final bills = ref.watch(billsProvider).value?.bills ?? const [];
  return bills.where((b) => !b.deleted && b.members.contains(uid)).toList()
    ..sort((a, b) => b.date.compareTo(a.date));
});

final settlementsWithProvider = Provider.family<List<Settlement>, String>((ref, uid) {
  final all = ref.watch(settlementsProvider).value ?? const [];
  return all.where((s) => s.members.contains(uid)).toList()
    ..sort((a, b) => b.date.compareTo(a.date));
});

// ---------------------------------------------------------------------------
// Inbox
// ---------------------------------------------------------------------------

final inboxProvider = Provider<Inbox>((ref) {
  final me = _uid(ref);
  if (me == null) return Inbox.empty;
  return Inbox.build(
    me: me,
    connections: ref.watch(connectionsProvider).value ?? const [],
    bills: ref.watch(billsProvider).value?.bills ?? const [],
    settlements: ref.watch(settlementsProvider).value ?? const [],
    now: DateTime.now(),
  );
});

/// When the inbox was last opened. Stored on this device.
class InboxSeenNotifier extends Notifier<DateTime> {
  static const _key = 'inboxSeenAt';

  @override
  DateTime build() =>
      DateTime.fromMillisecondsSinceEpoch(ref.watch(sharedPreferencesProvider).getInt(_key) ?? 0);

  Future<void> markSeen([DateTime? at]) async {
    state = at ?? DateTime.now();
    await ref.read(sharedPreferencesProvider).setInt(_key, state.millisecondsSinceEpoch);
  }
}

final inboxSeenProvider = NotifierProvider<InboxSeenNotifier, DateTime>(InboxSeenNotifier.new);

final inboxUnreadProvider = Provider<int>(
  (ref) => ref.watch(inboxProvider).unread(ref.watch(inboxSeenProvider)),
);

// ---------------------------------------------------------------------------
// Background work
// ---------------------------------------------------------------------------

/// Keeps your share of shared bills in your ledger. Watched at app start.
final billProjectionProvider = Provider<void>((ref) {
  final projector = BillProjector(ref.watch(entryRepositoryProvider));
  void run() {
    final me = ref.read(accountProvider).value?.uid;
    final bills = ref.read(billsProvider).value;
    final connections = ref.read(connectionsProvider).value;
    final categories = ref.read(categoriesProvider).value;
    if (me == null || bills == null || connections == null || categories == null) return;
    unawaited(
      projector.apply(
        me: me,
        snapshot: bills,
        connected: {for (final c in connections.where((c) => c.isAccepted)) c.other.uid},
        categoryIds: {for (final c in categories.where((c) => !c.archived)) c.id},
      ),
    );
  }

  ref.listen(billsProvider, (_, _) => run());
  ref.listen(connectionsProvider, (_, _) => run());
  ref.listen(categoriesProvider, (_, _) => run());
  run();
});

/// A username from an invite link, waiting to be shown on the People tab.
class PendingInviteNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? handle) => state = handle;
}

final pendingInviteProvider = NotifierProvider<PendingInviteNotifier, String?>(
  PendingInviteNotifier.new,
);
