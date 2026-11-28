import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_bucks/app/app.dart';
import 'package:three_bucks/app/providers.dart';
import 'package:three_bucks/data/local/app_database.dart';

import '../support/fake_connectivity.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  testWidgets('set a budget from Home, then remove it', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({'onboarded': true});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(db),
        connectivityProvider.overrideWithValue(FakeConnectivity()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const ThreeBucksApp()),
    );
    await tester.pumpAndSettle();

    // Set: the dialog closes (running its exit animation) without errors.
    await tester.tap(find.text('Set budget'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '1350');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(container.read(settingsProvider).monthlyBudgetCents, 135000);

    // Remove it again from the budget line.
    await tester.tap(find.textContaining('budget ·'));
    await tester.pumpAndSettle();
    expect(find.text('Remove'), findsOneWidget);
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(container.read(settingsProvider).hasBudget, isFalse);
    expect(find.text('Set budget'), findsOneWidget);

    await tester.runAsync(db.close);
  });
}
