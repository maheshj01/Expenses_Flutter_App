import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spendwise/app/app.dart';
import 'package:spendwise/app/providers.dart';
import 'package:spendwise/data/local/app_database.dart';

import '../support/fake_connectivity.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  testWidgets('add an expense with quick entry, then edit it', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase(NativeDatabase.memory());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          databaseProvider.overrideWithValue(db),
          connectivityProvider.overrideWithValue(FakeConnectivity()),
        ],
        child: const SpendWiseApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('A fresh month'), findsOneWidget);

    // Add: type everything on one line.
    await tester.tap(find.byTooltip('Add entry'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'kroger 18 split');
    await tester.pumpAndSettle();
    expect(find.text('Your share \$9.00'), findsOneWidget);

    await tester.tap(find.text('🛒  Food'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save \$9.00 · Food'));
    await tester.pumpAndSettle();

    // Shows on the dashboard with the split share.
    expect(find.text('Kroger'), findsOneWidget);
    expect(find.text('of \$18.00'), findsOneWidget);

    // Edit: switch off the split by cycling to 1 way.
    await tester.tap(find.text('Kroger'));
    await tester.pumpAndSettle();
    expect(find.text('Edit entry'), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.textContaining('Split'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Save \$18.00 · Food'));
    await tester.pumpAndSettle();
    expect(find.text('of \$18.00'), findsNothing);
    expect(find.text('\$18.00'), findsWidgets);

    // Tear down streams before closing the database.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(db.close);
  });
}
