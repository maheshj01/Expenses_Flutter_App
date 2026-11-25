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
import 'package:three_bucks/data/local/drift_entry_repository.dart';
import 'package:three_bucks/data/sync/local_sync_source.dart';
import 'package:three_bucks/domain/entities/ledger_entry.dart';
import 'package:three_bucks/domain/social/account.dart';
import 'package:three_bucks/domain/social/shared_bill.dart';
import 'package:three_bucks/shared/widgets/entry_tile.dart';

import '../support/fake_connectivity.dart';
import '../support/fake_social.dart';

const _maya = Account(uid: 'maya', method: SignInMethod.apple);

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  /// The "Deleted" tag on a row (the filter chip has the same words).
  final deletedTag = find.descendant(of: find.byType(EntryTile), matching: find.text('Deleted'));

  Future<void> launch(WidgetTester tester, {LedgerEntry? seed, FakeSocialServer? server}) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({'onboarded': true, 'name': 'Maya Rao'});
    final prefs = await SharedPreferences.getInstance();
    db = AppDatabase(NativeDatabase.memory());
    if (seed != null) {
      await tester.runAsync(() => DriftEntryRepository(db, LocalChanges()).save(seed));
    }
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          databaseProvider.overrideWithValue(db),
          connectivityProvider.overrideWithValue(FakeConnectivity()),
          if (server != null)
            socialBackendProvider.overrideWithValue(
              FakeSocialBackend(server, signInAs: _maya, signedIn: true),
            ),
        ],
        // As in main(): keeps shares of bills in the ledger.
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
    await tester.tap(
      find.descendant(of: find.byType(BottomAppBar), matching: find.text('Activity')),
    );
    await tester.pumpAndSettle();
  }

  /// Taps a filter chip, dragging the row of chips to its start (for the
  /// first two) or end first so the chip is on screen.
  Future<void> filter(WidgetTester tester, String label) async {
    final row = find.ancestor(of: find.byType(ChoiceChip).first, matching: find.byType(ListView));
    await tester.drag(row.first, Offset(label == 'All' || label == 'Spending' ? 600 : -600, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, label));
    await tester.pumpAndSettle();
  }

  /// Lets one-off database reads and writes finish; they need real time.
  Future<void> settleDb(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
  }

  Future<void> tearDownApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(db.close);
  }

  testWidgets('a deleted expense stays in Activity, and can be restored', (tester) async {
    await launch(
      tester,
      seed: LedgerEntry(
        id: 'e1',
        amountCents: 1800,
        categoryId: 'food',
        date: today,
        note: 'Kroger',
        createdAt: today,
      ),
    );
    expect(find.text('Kroger'), findsOneWidget);
    expect(deletedTag, findsNothing);

    await tester.drag(find.text('Kroger'), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(find.text('Entry deleted'), findsOneWidget);
    expect(find.text('Kroger'), findsOneWidget, reason: 'still listed, as deleted');
    expect(deletedTag, findsOneWidget);
    expect(find.text('\$0'), findsWidgets, reason: 'no longer counted');

    // Only deleted ones under Deleted; none under Spending.
    await filter(tester, 'Spending');
    expect(find.text('Kroger'), findsNothing);
    await filter(tester, 'Deleted');
    expect(find.text('Kroger'), findsOneWidget);

    // Its history says it was deleted, and offers to restore it.
    await tester.tap(find.text('Kroger'));
    await settleDb(tester);
    expect(find.widgetWithText(BottomSheet, 'History'), findsOneWidget);
    expect(find.text('Status'), findsOneWidget);
    await tester.tap(find.text('Restore'));
    await settleDb(tester);
    expect(find.text('Entry restored'), findsOneWidget);
    expect(find.text('Nothing deleted this month'), findsOneWidget);

    await filter(tester, 'All');
    expect(find.text('Kroger'), findsOneWidget);
    expect(deletedTag, findsNothing);

    await tearDownApp(tester);
  });

  testWidgets('a shared bill the payer deleted stays in Activity, read-only', (tester) async {
    final server = FakeSocialServer();
    final maya = server.addPerson('maya', 'maya', 'Maya Rao');
    final sam = server.addPerson('sam', 'sam', 'Sam Lee');
    server
      ..connect(sam, maya)
      ..bills['b1'] = SharedBill(
        id: 'b1',
        createdBy: 'sam',
        members: const ['sam', 'maya'],
        people: {'sam': sam, 'maya': maya},
        amountCents: 6000,
        currencyCode: 'USD',
        date: today,
        note: 'Dinner',
        categoryId: 'food',
        createdAt: today,
        editedAt: today.add(const Duration(hours: 9)),
        deleted: true,
      );

    // Maya's share was in her ledger before Sam deleted the bill.
    await launch(
      tester,
      server: server,
      seed: LedgerEntry(
        id: 'b1',
        amountCents: 6000,
        categoryId: 'food',
        date: today,
        note: 'Dinner',
        splitWays: 2,
        billId: 'b1',
        createdAt: today,
      ),
    );
    expect(find.text('Dinner'), findsOneWidget);
    expect(deletedTag, findsOneWidget);

    await tester.tap(find.text('Dinner'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Deleted by Sam Lee'), findsOneWidget);
    expect(find.text('Flag my share'), findsNothing);
    expect(find.text('Edit bill'), findsNothing);

    await tearDownApp(tester);
  });
}
