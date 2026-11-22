import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_bucks/app/app.dart';
import 'package:three_bucks/app/providers.dart';
import 'package:three_bucks/data/local/app_database.dart';
import 'package:three_bucks/shared/region_keys.dart';

import '../support/fake_connectivity.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  testWidgets('add an expense with quick entry, then edit it', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({'onboarded': true});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase(NativeDatabase.memory());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          databaseProvider.overrideWithValue(db),
          connectivityProvider.overrideWithValue(FakeConnectivity()),
        ],
        child: const ThreeBucksApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('A fresh month'), findsOneWidget);

    // Add: type everything on one line.
    await tester.tap(find.byTooltip('Add entry'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(RegionKeys.quickEntry), 'kroger 18 split');
    await tester.pumpAndSettle();
    expect(find.text('Your share \$9.00'), findsOneWidget);
    expect(_amountField(tester).controller!.text, '18', reason: 'quick entry fills the amount');

    await tester.tap(find.text('🛒  Food'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save \$9.00 · Food'));
    await tester.pumpAndSettle();

    // Shows on the dashboard with the split share.
    expect(find.text('Kroger'), findsOneWidget);
    expect(find.text('of \$18.00'), findsOneWidget);

    // Edit: switch off the split.
    await tester.tap(find.text('Kroger'));
    await tester.pumpAndSettle();
    expect(find.text('Edit entry'), findsOneWidget);
    await tester.tap(find.text('Split 2 ways'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Don’t split'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save \$18.00 · Food'));
    await tester.pumpAndSettle();
    expect(find.text('of \$18.00'), findsNothing);
    expect(find.text('\$18.00'), findsWidgets);

    // Tear down streams before closing the database.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(db.close);
  });

  testWidgets('type the amount on the phone\'s number pad', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({'onboarded': true});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase(NativeDatabase.memory());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          databaseProvider.overrideWithValue(db),
          connectivityProvider.overrideWithValue(FakeConnectivity()),
        ],
        child: const ThreeBucksApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Add entry'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.backspace_outlined), findsNothing, reason: 'no in-app keypad');

    // A new entry opens straight onto the amount, with the decimal number pad.
    final editable = tester.widget<EditableText>(
      find.descendant(of: find.byKey(RegionKeys.entryAmount), matching: find.byType(EditableText)),
    );
    expect(editable.focusNode.hasFocus, isTrue);
    expect(_amountField(tester).keyboardType, const TextInputType.numberWithOptions(decimal: true));
    expect(tester.testTextInput.isVisible, isTrue);

    // A comma decimal key counts as a point; a third decimal is ignored.
    final amount = find.descendant(
      of: find.byKey(RegionKeys.entryAmount),
      matching: find.byType(TextField),
    );
    await tester.enterText(amount, '12,5');
    await tester.pump();
    expect(_amountField(tester).controller!.text, '12.5');
    await tester.enterText(amount, '12.555');
    await tester.pump();
    expect(_amountField(tester).controller!.text, '12.5');

    // Picking a category puts the keyboard away.
    await tester.tap(find.text('🛒  Food'));
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, isFalse);
    await tester.tap(find.text('Save \$12.50 · Food'));
    await tester.pumpAndSettle();
    expect(find.text('\$12.50'), findsWidgets);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(db.close);
  });
}

TextField _amountField(WidgetTester tester) => tester.widget<TextField>(
  find.descendant(of: find.byKey(RegionKeys.entryAmount), matching: find.byType(TextField)),
);
