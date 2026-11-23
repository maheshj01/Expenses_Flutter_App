import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_bucks/app/account_flow.dart';
import 'package:three_bucks/app/providers.dart';
import 'package:three_bucks/app/social_providers.dart';
import 'package:three_bucks/data/local/app_database.dart';
import 'package:three_bucks/domain/account/account_deletion.dart';
import 'package:three_bucks/domain/entities/ledger_entry.dart';
import 'package:three_bucks/domain/social/account.dart';

import '../support/fake_account_deletion.dart';
import '../support/fake_connectivity.dart';
import '../support/fake_social.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late FakeSocialServer server;
  late FakeSocialBackend maya;
  late FakeSocialBackend sam;
  late FakeAccountDeletion deletion;
  late AppDatabase db;
  late ProviderContainer container;
  final now = DateTime(2026, 11, 23, 10);

  Future<void> setUpApp({required bool signedIn}) async {
    SharedPreferences.setMockInitialValues({'onboarded': true, 'name': 'Maya Rao'});
    final prefs = await SharedPreferences.getInstance();
    db = AppDatabase(NativeDatabase.memory());
    server = FakeSocialServer();
    final mayaProfile = server.addPerson('maya', 'maya', 'Maya Rao');
    final samProfile = server.addPerson('sam', 'sam', 'Sam Lee');
    server.connect(mayaProfile, samProfile);
    maya = FakeSocialBackend(
      server,
      signInAs: const Account(uid: 'maya', method: SignInMethod.apple),
      signedIn: signedIn,
    );
    sam = FakeSocialBackend(
      server,
      signInAs: const Account(uid: 'sam', method: SignInMethod.google),
      signedIn: true,
    );
    deletion = FakeAccountDeletion(
      server,
      currentUid: () => maya.currentAccount?.uid,
      clock: () => now,
    );
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(db),
        connectivityProvider.overrideWithValue(FakeConnectivity()),
        socialBackendProvider.overrideWithValue(maya),
        accountDeletionProvider.overrideWithValue(deletion),
      ],
    );
    container.listen(accountFlowProvider, (_, _) {});
    container.listen(accountProvider, (_, _) {});
    await container
        .read(entryRepositoryProvider)
        .save(
          LedgerEntry(
            id: 'e1',
            amountCents: 4200,
            categoryId: 'food',
            date: DateTime(2026, 11, 20),
          ),
        );
    await pumpEventQueue();
  }

  tearDown(() async {
    await pumpEventQueue(); // let the sync a restore kicks off finish
    container.dispose();
    await db.close();
    await server.dispose();
  });

  AccountFlowState flow() => container.read(accountFlowProvider);

  Future<int> entriesOnPhone() => container.read(entryRepositoryProvider).count();

  test('deleting a signed-in account freezes it for 30 days and clears the phone', () async {
    await setUpApp(signedIn: true);

    final outcome = await container.read(accountFlowProvider.notifier).deleteAccount();

    expect(outcome, isA<Scheduled>());
    expect((outcome! as Scheduled).purgeAfter, now.add(const Duration(days: 30)));
    expect(maya.currentAccount, isNull, reason: 'signed out');
    expect(await entriesOnPhone(), 0);
    expect(container.read(settingsProvider).onboarded, isFalse, reason: 'onboarding again');
    expect(
      (await container.read(categoryRepositoryProvider).watchAll().first).isNotEmpty,
      isTrue,
      reason: 'default categories back',
    );
    expect(await sam.findByHandle('maya'), isNull, reason: 'hidden while frozen');
    expect(flow().status, AccountFlowStatus.idle);
  });

  test('without signing in, the backup is erased at once', () async {
    await setUpApp(signedIn: false);
    final outcome = await container.read(accountFlowProvider.notifier).deleteAccount();
    expect(outcome, isA<Erased>());
    expect(deletion.erasedAnonymous, 1);
    expect(await entriesOnPhone(), 0);
  });

  test('a failed request changes nothing and says why', () async {
    await setUpApp(signedIn: true);
    deletion.failNext = true;
    final outcome = await container.read(accountFlowProvider.notifier).deleteAccount();
    expect(outcome, isNull);
    expect(flow().message, contains('Check your connection'));
    expect(await entriesOnPhone(), 1);
    expect(maya.currentAccount, isNotNull);
  });

  test('signing in to a frozen account asks; restoring brings it back', () async {
    await setUpApp(signedIn: false);
    deletion.purgeAfter['maya'] = now.add(const Duration(days: 12));
    server.frozen.add('maya');

    await container.read(accountFlowProvider.notifier).signIn(SignInMethod.apple);
    expect(flow().status, AccountFlowStatus.pendingDeletion);
    expect(flow().duringSignIn, isTrue, reason: 'asked in a dialog, not a frozen app');
    expect(flow().frozen, isFalse);

    await container.read(accountFlowProvider.notifier).restoreAccount();
    expect(flow().status, AccountFlowStatus.idle);
    expect(deletion.purgeAfter, isEmpty);
    expect(await sam.findByHandle('maya'), isNotNull);
  });

  test('keep deleting after signing in signs out and keeps this phone’s entries', () async {
    await setUpApp(signedIn: false);
    deletion.purgeAfter['maya'] = now.add(const Duration(days: 12));

    await container.read(accountFlowProvider.notifier).signIn(SignInMethod.apple);
    final cleared = await container.read(accountFlowProvider.notifier).keepDeleting();

    expect(cleared, isFalse);
    expect(maya.currentAccount, isNull);
    expect(await entriesOnPhone(), 1);
    expect(deletion.purgeAfter, contains('maya'), reason: 'still set to go');
  });

  test('a phone already signed in freezes; letting go clears it', () async {
    await setUpApp(signedIn: true);
    deletion.purgeAfter['maya'] = now.add(const Duration(days: 3));

    await container.read(accountFlowProvider.notifier).checkPendingDeletion();
    expect(flow().frozen, isTrue);
    expect(flow().purgeAfter, now.add(const Duration(days: 3)));

    final cleared = await container.read(accountFlowProvider.notifier).keepDeleting();
    expect(cleared, isTrue);
    expect(await entriesOnPhone(), 0);
    expect(maya.currentAccount, isNull);
  });

  test('after 30 days the account is gone for good', () async {
    await setUpApp(signedIn: true);
    await container.read(accountFlowProvider.notifier).deleteAccount();

    deletion.purgeDue(now.add(const Duration(days: 29)));
    expect(server.profiles['maya'], isNotNull);

    deletion.purgeDue(now.add(const Duration(days: 30)));
    expect(server.profiles['maya'], isNull);
    expect(server.connections, isEmpty);
    await expectLater(maya.signIn(SignInMethod.apple), throwsA(anything));
  });
}
