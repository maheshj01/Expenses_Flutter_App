import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_bucks/app/app.dart';
import 'package:three_bucks/app/providers.dart';
import 'package:three_bucks/app/social_providers.dart';
import 'package:three_bucks/data/local/app_database.dart';
import 'package:three_bucks/domain/social/account.dart';

import '../support/fake_connectivity.dart';
import '../support/fake_social.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  Future<(FakeSocialBackend, AppDatabase)> openPeople(
    WidgetTester tester, {
    List<SignInMethod>? methods,
  }) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({'onboarded': true, 'name': 'Maya Rao'});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase(NativeDatabase.memory());
    final backend = FakeSocialBackend(
      FakeSocialServer(),
      signInAs: const Account(uid: 'maya', method: SignInMethod.apple, email: 'maya@example.com'),
    )..emailAccountUses = SignInMethod.apple;
    if (methods != null) backend.methods = methods;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          databaseProvider.overrideWithValue(db),
          connectivityProvider.overrideWithValue(FakeConnectivity()),
          socialBackendProvider.overrideWithValue(backend),
        ],
        child: const ThreeBucksApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(BottomAppBar), matching: find.text('People')));
    await tester.pumpAndSettle();
    return (backend, db);
  }

  testWidgets('Google with an email that signs in with Apple joins that account', (tester) async {
    final (backend, db) = await openPeople(tester);

    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();
    expect(find.text('You already have an account'), findsOneWidget);
    expect(find.textContaining('maya@example.com already signs in with Apple'), findsOneWidget);

    await tester.tap(
      find.descendant(of: find.byType(AlertDialog), matching: find.text('Continue with Apple')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Pick a username'), findsOneWidget);
    expect(backend.currentAccount?.uid, 'maya');
    expect(backend.linkedMethods, {SignInMethod.google});

    // From now on Google opens the same account with no question.
    await backend.signOut();
    await backend.signIn(SignInMethod.google);
    expect(backend.currentAccount?.uid, 'maya');
    await tester.runAsync(db.close);
  });

  testWidgets('cancelling leaves you signed out', (tester) async {
    final (backend, db) = await openPeople(tester);

    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Split bills with people'), findsOneWidget);
    expect(backend.currentAccount, isNull);
    expect(backend.linkedMethods, isEmpty);
    await tester.runAsync(db.close);
  });

  testWidgets('without Apple on this phone, explains how to join from an iPhone', (tester) async {
    final (backend, db) = await openPeople(tester, methods: [SignInMethod.google]);

    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('On your iPhone, sign out and continue with Google'),
      findsOneWidget,
    );
    expect(
      find.descendant(of: find.byType(AlertDialog), matching: find.text('Continue with Apple')),
      findsNothing,
    );
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(backend.currentAccount, isNull);
    await tester.runAsync(db.close);
  });
}
