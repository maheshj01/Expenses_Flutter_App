import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:three_bucks/data/local/app_database.dart';
import 'package:three_bucks/data/local/drift_category_repository.dart';
import 'package:three_bucks/data/local/drift_entry_repository.dart';
import 'package:three_bucks/data/sync/local_sync_source.dart';
import 'package:three_bucks/data/sync/sync_engine.dart';
import 'package:three_bucks/data/sync/sync_status.dart';
import 'package:three_bucks/domain/entities/category.dart';
import 'package:three_bucks/domain/entities/ledger_entry.dart';

import '../support/fake_connectivity.dart';
import '../support/in_memory_remote_store.dart';

/// One phone: its own database, repositories and sync engine.
class Device {
  Device(InMemoryRemoteStore? remote, {required this.network, required DateTime Function() clock})
    : db = AppDatabase(NativeDatabase.memory()) {
    categories = DriftCategoryRepository(db, changes, clock: clock);
    entries = DriftEntryRepository(db, changes, clock: clock);
    engine = SyncEngine(
      remote: remote,
      sources: [categories, entries],
      cursors: db,
      connectivity: network,
      changes: changes,
      debounce: const Duration(milliseconds: 10),
      retryAfter: const Duration(hours: 1),
    );
  }

  final AppDatabase db;
  final FakeConnectivity network;
  final changes = LocalChanges();
  late final DriftCategoryRepository categories;
  late final DriftEntryRepository entries;
  late final SyncEngine engine;

  Future<List<LedgerEntry>> all() => entries.watchBetween(DateTime(2000), DateTime(2100)).first;

  Future<void> close() async {
    await engine.dispose();
    await db.close();
    await changes.dispose();
  }
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late InMemoryRemoteStore remote;
  late DateTime now;
  late Device phone;
  late Device tablet;

  DateTime clock() => now;

  setUp(() {
    remote = InMemoryRemoteStore(pageSize: 2);
    now = DateTime(2026, 11, 17, 9);
    phone = Device(remote, network: FakeConnectivity(), clock: clock);
    tablet = Device(remote, network: FakeConnectivity(), clock: clock);
  });

  tearDown(() async {
    await phone.close();
    await tablet.close();
  });

  LedgerEntry entry(String id, int cents) =>
      LedgerEntry(id: id, amountCents: cents, categoryId: 'food', date: DateTime(2026, 11, 17));

  void tick() => now = now.add(const Duration(seconds: 1));

  test('changes made on one device reach the other', () async {
    for (final id in ['a', 'b', 'c']) {
      await phone.entries.save(entry(id, 100));
    }
    await phone.categories.save(const Category(id: 'pets', name: 'Pets', emoji: '🐶', color: 1));
    await phone.engine.syncNow();
    await tablet.engine.syncNow();

    expect((await tablet.all()).map((e) => e.id).toSet(), {'a', 'b', 'c'});
    expect((await tablet.categories.getAll()).any((c) => c.id == 'pets'), isTrue);
    expect(phone.engine.status.phase, SyncPhase.idle);
    expect(phone.engine.status.pendingCount, 0);
  });

  test('edits and deletes propagate; the latest edit wins', () async {
    await phone.entries.save(entry('a', 100));
    await phone.engine.syncNow();
    await tablet.engine.syncNow();

    tick();
    await tablet.entries.save(entry('a', 250)); // tablet edits first
    tick();
    await phone.entries.save(entry('a', 300)); // phone edits later
    await tablet.engine.syncNow();
    await phone.engine.syncNow();
    await tablet.engine.syncNow();

    expect((await phone.all()).single.amountCents, 300);
    expect((await tablet.all()).single.amountCents, 300);

    tick();
    await tablet.entries.delete('a');
    await tablet.engine.syncNow();
    await phone.engine.syncNow();
    expect(await phone.all(), isEmpty);
  });

  test('offline changes are queued and pushed when the network returns', () async {
    phone.network.online = false;
    phone.engine.start();
    await phone.entries.save(entry('a', 100));
    await phone.engine.syncNow();

    expect(phone.engine.status.phase, SyncPhase.offline);
    expect(phone.engine.status.pendingCount, 1);
    expect(remote.get('entries', 'a'), isNull);

    phone.network.set(true);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await phone.engine.syncNow();

    expect(remote.get('entries', 'a'), isNotNull);
    expect(phone.engine.status.phase, SyncPhase.idle);
    expect(phone.engine.status.pendingCount, 0);
  });

  test('local writes trigger a debounced sync', () async {
    phone.engine.start();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await phone.entries.save(entry('a', 100));
    await phone.entries.save(entry('b', 100));
    await Future<void>.delayed(const Duration(milliseconds: 80));
    await phone.engine.syncNow();
    expect(remote.get('entries', 'a'), isNotNull);
    expect(remote.get('entries', 'b'), isNotNull);
  });

  test('a failed sync keeps changes pending and reports the error', () async {
    await phone.entries.save(entry('a', 100));
    remote.failNext = true;
    await phone.engine.syncNow();
    expect(phone.engine.status.phase, SyncPhase.error);
    expect(phone.engine.status.pendingCount, 1);

    await phone.engine.syncNow();
    expect(phone.engine.status.phase, SyncPhase.idle);
    expect(remote.get('entries', 'a'), isNotNull);
  });

  test('without a backend everything stays local', () async {
    final solo = Device(null, network: FakeConnectivity(), clock: clock);
    solo.engine.start();
    await solo.entries.save(entry('a', 100));
    await solo.engine.syncNow();
    expect(solo.engine.status.phase, SyncPhase.localOnly);
    expect((await solo.all()).single.id, 'a');
    await solo.close();
  });

  test('switching accounts merges this device into the new account', () async {
    await phone.entries.save(entry('a', 100));
    await phone.engine.syncNow();
    final pushesBefore = remote.pushCalls;
    expect(await phone.entries.pendingChanges(), isEmpty);

    remote.accountIdValue = 'user-2';
    await phone.engine.syncNow();

    expect(remote.pushCalls, greaterThan(pushesBefore), reason: 'everything pushed again');
    expect(await phone.entries.pendingChanges(), isEmpty);
    expect(await phone.db.readCursor(SyncEngine.accountKey), 'user-2');
  });

  group('erasing the backup', () {
    test('deletes every collection and pauses sync until resumed', () async {
      await phone.entries.save(entry('a', 100));
      await phone.categories.save(const Category(id: 'pets', name: 'Pets', emoji: '🐶', color: 1));
      await phone.engine.syncNow();
      expect(remote.count('entries'), 1);

      await phone.engine.eraseRemote();
      expect(remote.count('entries'), 0);
      expect(remote.count('categories'), 0);

      // Nothing goes back up while the account is being deleted.
      await phone.entries.save(entry('b', 100));
      await phone.engine.syncNow();
      expect(remote.count('entries'), 0);
      expect((await phone.all()).map((e) => e.id), containsAll(['a', 'b']), reason: 'local stays');

      await phone.engine.resumeAfterErase(restore: false);
      await phone.engine.syncNow();
      expect(remote.get('entries', 'b'), isNotNull, reason: 'new edits sync again');
      expect(remote.get('entries', 'a'), isNull, reason: 'erased records stay erased');
    });

    test('restoring pushes everything back', () async {
      await phone.entries.save(entry('a', 100));
      await phone.engine.syncNow();
      await phone.engine.eraseRemote();

      await phone.engine.resumeAfterErase(restore: true);
      await phone.engine.syncNow();
      expect(remote.get('entries', 'a'), isNotNull);
    });

    test('refuses while offline and erases nothing', () async {
      await phone.entries.save(entry('a', 100));
      await phone.engine.syncNow();
      phone.network.online = false;

      await expectLater(phone.engine.eraseRemote(), throwsA(isA<EraseFailed>()));
      expect(remote.get('entries', 'a'), isNotNull);
      await phone.engine.resumeAfterErase(restore: true);
    });
  });
}
