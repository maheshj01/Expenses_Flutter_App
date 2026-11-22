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
import 'package:three_bucks/domain/social/settlement.dart';
import 'package:three_bucks/domain/social/shared_bill.dart';
import 'package:three_bucks/shared/region_keys.dart';

import '../support/fake_connectivity.dart';
import '../support/fake_social.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  testWidgets('sign in, add a friend, split a bill, get flagged, settle up', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({'onboarded': true, 'name': 'Maya Rao'});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase(NativeDatabase.memory());

    // Sam is already on the app and will answer from his phone.
    final server = FakeSocialServer();
    final sam = server.addPerson('sam', 'sam', 'Sam Lee');
    final samsPhone = FakeSocialBackend(
      server,
      signInAs: const Account(uid: 'sam', method: SignInMethod.google),
      signedIn: true,
    );
    final mine = FakeSocialBackend(
      server,
      signInAs: const Account(uid: 'maya', method: SignInMethod.apple),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          databaseProvider.overrideWithValue(db),
          connectivityProvider.overrideWithValue(FakeConnectivity()),
          socialBackendProvider.overrideWithValue(mine),
        ],
        child: Consumer(
          builder: (context, ref, child) {
            ref.watch(billProjectionProvider);
            return child!;
          },
          child: const ThreeBucksApp(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> tapTab(String label) async {
      await tester.tap(find.descendant(of: find.byType(BottomAppBar), matching: find.text(label)));
      await tester.pumpAndSettle();
    }

    // 1. Sign in and pick a username (pre-filled from the onboarding name).
    await tapTab('People');
    expect(find.text('Split bills with people'), findsOneWidget);
    await tester.tap(find.text('Continue with Apple'));
    await tester.pumpAndSettle();
    expect(find.text('Pick a username'), findsOneWidget);
    expect(find.text('Continue as @mayarao'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('handle')), 'maya');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue as @maya'));
    await tester.pumpAndSettle();
    expect(find.text('Add the people you split with'), findsOneWidget);

    // 2. Add Sam by exact username; he accepts.
    await tester.tap(find.byTooltip('Add people'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('find-handle')), '@Sam');
    await tester.tap(find.text('Find'));
    await tester.pumpAndSettle();
    expect(find.text('Sam Lee'), findsOneWidget);
    await tester.tap(find.text('Send request'));
    await tester.pumpAndSettle();
    expect(find.text('Request sent'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10)); // close the sheet
    await tester.pumpAndSettle();
    expect(find.text('Waiting for them'), findsOneWidget);

    await samsPhone.acceptConnection(server.connections.keys.single);
    await tester.pumpAndSettle();
    expect(find.text('Sam Lee'), findsOneWidget);
    expect(find.text('settled up'), findsOneWidget);

    // 3. Split a $60 dinner with Sam from the normal add sheet.
    await tester.tap(find.byTooltip('Add entry'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(RegionKeys.quickEntry), 'dinner 60');
    await tester.tap(find.text('🛒  Food'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Split bill'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'Sam Lee'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Split 2 ways · your share \$30.00'));
    await tester.pumpAndSettle();
    expect(find.text('Your share \$30.00 · Sam owes \$30.00'), findsOneWidget);
    await tester.tap(find.text('Share \$30.00 · Food'));
    await tester.pumpAndSettle();

    final bill = server.bills.values.single;
    expect(bill.members, ['maya', 'sam']);
    expect(bill.shareCents, 3000);
    final entry = (await tester.runAsync(() => db.select(db.entries).getSingle()))!;
    expect(entry.billId, bill.id);
    expect(find.textContaining('owes you \$30.00', findRichText: true), findsOneWidget);

    // 4. Sam flags his share: it stops counting and shows up in my inbox.
    await samsPhone.setFlag(
      bill.id,
      BillFlag(reason: FlagReason.wrongAmount, note: 'I skipped dessert', at: DateTime.now()),
    );
    await tester.pumpAndSettle();
    expect(find.text('settled up'), findsOneWidget);
    expect(find.text('1'), findsWidgets, reason: 'inbox badge');

    await tester.tap(find.byTooltip('Inbox'));
    await tester.pumpAndSettle();
    expect(find.text('Sam Lee flagged their share of “Dinner”'), findsOneWidget);
    expect(find.textContaining('I skipped dessert'), findsOneWidget);

    // Resolve by editing: $50 instead, which clears the flag.
    await tester.tap(find.text('Sam Lee flagged their share of “Dinner”'));
    await tester.pumpAndSettle();
    expect(find.text('Disputed'), findsOneWidget);
    await tester.tap(find.text('Edit to resolve'));
    await tester.pumpAndSettle();
    expect(find.text('Edit shared bill'), findsOneWidget);
    await tester.enterText(
      find.descendant(of: find.byKey(RegionKeys.entryAmount), matching: find.byType(TextField)),
      '50',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share \$25.00 · Food'));
    await tester.pumpAndSettle();
    expect(server.bills[bill.id]!.flags, isEmpty);
    expect(server.bills[bill.id]!.amountCents, 5000);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.textContaining('owes you \$25.00', findRichText: true), findsOneWidget);

    // 5. Sam pays me back outside the app and records it.
    await samsPhone.addSettlement(
      Settlement(
        id: 's1',
        from: 'sam',
        to: 'maya',
        amountCents: 2500,
        currencyCode: 'USD',
        date: DateTime.now(),
        createdBy: 'sam',
        createdAt: DateTime.now(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('settled up'), findsOneWidget);
    expect(sam.handle, 'sam');

    // Tear down streams before closing the database.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(db.close);
    await server.dispose();
  });
}
