import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:three_bucks/app/account_deletion.dart';
import 'package:three_bucks/data/local/app_database.dart';
import 'package:three_bucks/data/local/drift_category_repository.dart';
import 'package:three_bucks/data/local/drift_entry_repository.dart';
import 'package:three_bucks/data/sync/local_sync_source.dart';
import 'package:three_bucks/data/sync/sync_engine.dart';
import 'package:three_bucks/domain/entities/ledger_entry.dart';
import 'package:three_bucks/domain/social/account.dart';
import 'package:three_bucks/domain/social/social_backend.dart';

import '../support/fake_connectivity.dart';
import '../support/fake_social.dart';
import '../support/in_memory_remote_store.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late LocalChanges changes;
  late DriftEntryRepository entries;
  late InMemoryRemoteStore remote;
  late SyncEngine sync;
  late FakeSocialServer server;
  late FakeSocialBackend social;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    changes = LocalChanges();
    entries = DriftEntryRepository(db, changes);
    remote = InMemoryRemoteStore();
    sync = SyncEngine(
      remote: remote,
      sources: [DriftCategoryRepository(db, changes), entries],
      cursors: db,
      connectivity: FakeConnectivity(),
      changes: changes,
      debounce: const Duration(milliseconds: 10),
      retryAfter: const Duration(hours: 1),
    );
    server = FakeSocialServer();
    final maya = server.addPerson('maya', 'maya', 'Maya');
    final sam = server.addPerson('sam', 'sam', 'Sam');
    server.connect(maya, sam);
    social = FakeSocialBackend(
      server,
      signInAs: const Account(uid: 'maya', method: SignInMethod.apple),
      signedIn: true,
    );
    await social.block(server.addPerson('troll', 'troll', 'Troll'));

    await entries.save(
      LedgerEntry(id: 'a', amountCents: 500, categoryId: 'food', date: DateTime(2026, 11, 20)),
    );
    await sync.syncNow();
    expect(remote.count('entries'), 1);
  });

  tearDown(() async {
    await sync.syncNow(); // let the sync started after deleting finish
    await sync.dispose();
    await db.close();
    await changes.dispose();
    await server.dispose();
  });

  test('erases the backup, profile, connections and blocks; keeps local data', () async {
    await deleteAccountAndData(sync: sync, social: social);

    expect(remote.count('entries'), 0);
    expect(server.profiles.containsKey('maya'), isFalse);
    expect(server.handles.containsKey('maya'), isFalse);
    expect(server.connections, isEmpty);
    expect(server.blocks.containsKey('maya'), isFalse);
    expect(social.currentAccount, isNull);
    expect(await entries.byId('a'), isNotNull);
  });

  test('backing out of confirming deletes nothing', () async {
    social.cancelNextConfirm = true;

    await expectLater(
      deleteAccountAndData(sync: sync, social: social),
      throwsA(isA<SignInCancelled>()),
    );
    expect(remote.count('entries'), 1);
    expect(server.profiles.containsKey('maya'), isTrue);
    expect(social.currentAccount, isNotNull);
  });

  test('when erasing fails, the account and its backup stay', () async {
    remote.failNext = true;

    await expectLater(
      deleteAccountAndData(sync: sync, social: social),
      throwsA(isA<EraseFailed>()),
    );
    await sync.syncNow();
    expect(remote.count('entries'), 1);
    expect(server.profiles.containsKey('maya'), isTrue);
  });
}
