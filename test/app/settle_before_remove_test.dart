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
import 'package:three_bucks/domain/social/shared_bill.dart';

import '../support/fake_connectivity.dart';
import '../support/fake_social.dart';

SharedBill _bill(
  String id, {
  required Profile by,
  required List<Profile> with_,
  required int cents,
  String note = '',
}) {
  final people = [by, ...with_];
  return SharedBill(
    id: id,
    createdBy: by.uid,
    members: [for (final p in people) p.uid],
    people: {for (final p in people) p.uid: p},
    amountCents: cents,
    currencyCode: 'USD',
    date: DateTime(2026, 11, 18),
    note: note,
    categoryId: 'food',
    createdAt: DateTime(2026, 11, 18, 20),
    editedAt: DateTime(2026, 11, 18, 20),
  );
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  testWidgets('remove waits for settling up; blocked people stay listed until settled', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({'onboarded': true, 'name': 'Maya Rao'});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase(NativeDatabase.memory());

    final server = FakeSocialServer();
    final maya = server.addPerson('maya', 'maya', 'Maya Rao');
    final sam = server.addPerson('sam', 'sam', 'Sam Lee');
    final ana = server.addPerson('ana', 'ana.ruiz', 'Ana Ruiz');
    final zed = server.addPerson('zed', 'zed', 'Zed Stranger');
    server.connect(maya, sam);
    server.connect(maya, ana);
    final mine = FakeSocialBackend(
      server,
      signInAs: const Account(uid: 'maya', method: SignInMethod.apple),
      signedIn: true,
    );
    final anas = FakeSocialBackend(
      server,
      signInAs: const Account(uid: 'ana', method: SignInMethod.google),
      signedIn: true,
    );
    // Maya paid $40 for dinner with Sam, then corrected it to $46.
    final dinner = _bill('dinner', by: maya, with_: [sam], cents: 4000, note: 'Dinner');
    await mine.saveBill(dinner);
    await mine.saveBill(dinner.copyWith(amountCents: 4600, editedAt: DateTime(2026, 11, 19, 9)));
    // Ana paid $30 for a cab with Maya.
    await anas.saveBill(_bill('cab', by: ana, with_: [maya], cents: 3000, note: 'Cab'));
    // A stranger adds Maya to a bill; it counts for nothing.
    server.bills['spam'] = _bill('spam', by: zed, with_: [maya], cents: 99900);
    server.changed();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          databaseProvider.overrideWithValue(db),
          connectivityProvider.overrideWithValue(FakeConnectivity()),
          socialBackendProvider.overrideWithValue(mine),
        ],
        // As main() does: keeps shared bills in the ledger.
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
    await tester.tap(find.descendant(of: find.byType(BottomAppBar), matching: find.text('People')));
    await tester.pumpAndSettle();

    expect(find.text('\$23.00'), findsWidgets, reason: 'Sam owes half of \$46');
    expect(find.text('\$15.00'), findsWidgets, reason: 'Maya owes half of \$30');
    expect(find.textContaining('999'), findsNothing, reason: 'the stranger’s bill is ignored');

    // 1. Sam can't be removed while he owes Maya.
    await tester.tap(find.text('Sam Lee'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('More for Sam Lee'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove Sam Lee'));
    await tester.pumpAndSettle();
    expect(find.text('Settle up with Sam Lee first'), findsOneWidget);
    expect(find.textContaining('Sam Lee owes you \$23.00'), findsOneWidget);
    await tester.tap(
      find.descendant(of: find.byType(AlertDialog), matching: find.text('Settle up')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Record \$23.00'));
    await tester.pumpAndSettle();
    expect(find.text('You’re settled up'), findsOneWidget);

    // The dinner's history shows the correction.
    await tester.tap(find.text('Dinner'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edited once · See changes'));
    await tester.pumpAndSettle();
    expect(find.text('\$40.00 → \$46.00'), findsOneWidget);
    expect(find.textContaining('Created Nov 18, 2026 by You'), findsOneWidget);
    await tester.tapAt(const Offset(20, 40));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(20, 40));
    await tester.pumpAndSettle();

    // Settled, so now Sam can go.
    await tester.tap(find.byTooltip('More for Sam Lee'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove Sam Lee'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Remove'));
    await tester.pumpAndSettle();
    expect(server.connections.keys, isNot(contains('maya_sam')));
    expect(find.text('Sam Lee'), findsNothing);

    // 2. Blocking Ana works at once, and she stays under "Settle up".
    await tester.tap(find.text('Ana Ruiz'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('More for Ana Ruiz'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Block Ana Ruiz'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Block'));
    await tester.pumpAndSettle();
    expect(server.blocked('maya', 'ana'), isTrue);
    expect(find.text('Not connected · settle up to clear the balance'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Below the (now empty) "Split with" card.
    await tester.dragUntilVisible(
      find.text('@ana.ruiz · Blocked'),
      find.byType(ListView).first,
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    expect(find.text('Settle up'), findsOneWidget, reason: 'the section header');
    expect(find.text('@ana.ruiz · Blocked'), findsOneWidget);
    await tester.tap(find.text('Ana Ruiz'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Settle up'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Record \$15.00'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Ana Ruiz'), findsNothing, reason: 'settled, so off the list');

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(db.close);
    await server.dispose();
  });
}
