import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_bucks/app/account_flow.dart';
import 'package:three_bucks/app/app.dart';
import 'package:three_bucks/app/providers.dart';
import 'package:three_bucks/app/social_providers.dart';
import 'package:three_bucks/data/local/app_database.dart';
import 'package:three_bucks/domain/social/account.dart';
import 'package:three_bucks/features/account/deletion_pending_page.dart';
import 'package:three_bucks/features/account/goodbye_page.dart';
import 'package:three_bucks/features/account/hold_to_confirm.dart';
import 'package:three_bucks/features/onboarding/onboarding_flow.dart';

import '../support/fake_account_deletion.dart';
import '../support/fake_connectivity.dart';
import '../support/fake_social.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  Future<(FakeSocialServer, FakeAccountDeletion, AppDatabase)> pumpApp(
    WidgetTester tester, {
    void Function(FakeAccountDeletion)? before,
  }) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'onboarded': true, 'name': 'Maya Rao'});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase(NativeDatabase.memory());
    final server = FakeSocialServer();
    server.addPerson('maya', 'maya', 'Maya Rao');
    final maya = FakeSocialBackend(
      server,
      signInAs: const Account(uid: 'maya', method: SignInMethod.apple),
      signedIn: true,
    );
    final deletion = FakeAccountDeletion(
      server,
      currentUid: () => maya.currentAccount?.uid,
      clock: () => DateTime(2026, 11, 23),
    );
    before?.call(deletion);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          databaseProvider.overrideWithValue(db),
          connectivityProvider.overrideWithValue(FakeConnectivity()),
          socialBackendProvider.overrideWithValue(maya),
          accountDeletionProvider.overrideWithValue(deletion),
        ],
        child: const ThreeBucksApp(),
      ),
    );
    await tester.pumpAndSettle();
    return (server, deletion, db);
  }

  Future<void> tearDownApp(WidgetTester tester, FakeSocialServer server, AppDatabase db) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(db.close);
    await server.dispose();
  }

  testWidgets('hold to delete, say goodbye, start over', (tester) async {
    final (server, deletion, db) = await pumpApp(tester);

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.text('Delete account'),
      find.byType(ListView).first,
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    expect(find.text('Restorable for 30 days'), findsOneWidget);
    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();

    expect(find.text('Delete your account'), findsOneWidget);
    await tester.dragUntilVisible(
      find.text('30 days to change your mind'),
      find.byType(ListView).last,
      const Offset(0, -200),
    );
    expect(find.textContaining('@maya'), findsWidgets);

    // A tap does nothing: it has to be held.
    await tester.tap(find.byType(HoldToConfirm));
    await tester.pumpAndSettle();
    expect(deletion.purgeAfter, isEmpty);

    final hold = await tester.startGesture(tester.getCenter(find.byType(HoldToConfirm)));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Keep holding…'), findsWidgets);
    // The fill's clock starts on the first frame after the press, so hold
    // a little past the 1.6 s.
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump(const Duration(milliseconds: 1000));
    await hold.up();
    // The goodbye dot keeps breathing, so step time rather than settle.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }

    expect(deletion.purgeAfter['maya'], DateTime(2026, 12, 23));
    expect(find.byType(GoodbyePage), findsOneWidget);
    expect(find.text('Your account is set to go'), findsOneWidget);
    expect(find.textContaining('December 23, 2026'), findsOneWidget);

    await tester.tap(find.text('Start over'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.byType(OnboardingFlow), findsOneWidget);

    await tearDownApp(tester, server, db);
  });

  testWidgets('a phone signed in to a frozen account can restore it', (tester) async {
    final (server, deletion, db) = await pumpApp(
      tester,
      before: (d) => d.purgeAfter['maya'] = DateTime(2026, 11, 26, 12),
    );

    expect(find.byType(DeletionPendingPage), findsOneWidget);
    expect(find.text('Your account is set to be deleted'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'of 30 days left')), findsOneWidget);

    await tester.tap(find.text('Restore my account'));
    await tester.pumpAndSettle();
    expect(find.byType(DeletionPendingPage), findsNothing);
    expect(deletion.purgeAfter, isEmpty);

    await tearDownApp(tester, server, db);
  });
}
