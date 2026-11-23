import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_bucks/app/app.dart';
import 'package:three_bucks/app/providers.dart';
import 'package:three_bucks/data/local/app_database.dart';
import 'package:three_bucks/domain/entities/app_settings.dart';

import '../support/fake_connectivity.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  testWidgets('first run walks through setup and lands on a personal dashboard', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(db),
        connectivityProvider.overrideWithValue(FakeConnectivity()),
      ],
    );

    // Lets staggered entrance timers fire and animations finish.
    Future<void> settle() async {
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
    }

    Future<void> tapCta(String label) async {
      await tester.tap(find.widgetWithText(FilledButton, label));
      await settle();
    }

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const ThreeBucksApp()),
    );
    await settle();

    // Welcome
    expect(find.text('Let’s make your money make sense.'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Mahesh');
    await tapCta('Let’s go');

    // Income: biweekly pay converts to a monthly figure.
    expect(find.text('Does money come in regularly?'), findsOneWidget);
    await tester.tap(find.text('Yes, about the same each time'));
    await settle();
    await tester.tap(find.text('Every 2 weeks'));
    await tester.enterText(find.byType(TextField), '1800');
    await settle();
    expect(find.text('\$3,900'), findsOneWidget);
    await tapCta('Continue');

    // Spending: pick a suggestion.
    await tester.tap(find.text('60% · \$2,340'));
    await settle();
    expect(find.text('Left to save'), findsOneWidget);
    await tapCta('Continue');

    // Goals: savings target is pre-filled with what is left.
    await tester.tap(find.text('Save or invest more'));
    await settle();
    await tester.scrollUntilVisible(
      find.byType(TextField),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.byType(TextField));
    await settle();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '1560');
    await tapCta('Continue');

    // Categories: defaults are selected; add Pets.
    expect(find.text('What do you spend on?'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Pets'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Pets'));
    await settle();
    await tester.tap(find.text('Pets'));
    await settle();
    await tapCta('Continue');

    // Sharing
    await tester.tap(find.text('Yes, I split some bills'));
    await settle();
    expect(find.text('Not on the app?'), findsOneWidget);
    expect(find.byType(TextField), findsNothing, reason: 'names are added when splitting');
    await tapCta('Continue');

    // Plan summary
    expect(find.text('Here’s your plan, Mahesh'), findsOneWidget);
    expect(find.text('Spend'), findsOneWidget);
    await tapCta('Start tracking');
    await settle();

    // Landed in the app with everything applied.
    expect(find.textContaining('Mahesh'), findsWidgets);
    expect(find.text('Saved this month'), findsOneWidget);

    final s = container.read(settingsProvider);
    expect(s.onboarded, isTrue);
    expect(s.payFrequency, PayFrequency.biweekly);
    expect(s.incomeCents, 180000);
    expect(s.monthlyBudgetCents, 234000);
    expect(s.savingsGoalCents, 156000);
    expect(s.goals, {MoneyGoal.investMore});
    expect(s.splitsBills, isTrue);
    expect(s.savedGuests, isEmpty);

    final cats = await tester.runAsync(() => db.select(db.categories).get());
    bool active(String id) => cats!.any((c) => c.id == id && !c.archived && !c.deleted);
    expect(active('food'), isTrue);
    expect(active('pets'), isTrue, reason: 'picked extra is created');
    expect(active('travel'), isFalse, reason: 'unpicked starter is archived');
    expect(active('investment') && active('salary'), isTrue);

    await tester.pumpWidget(const SizedBox());
    container.dispose();
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(db.close);
  });

  testWidgets('people without an income set a spending budget instead', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(db),
        connectivityProvider.overrideWithValue(FakeConnectivity()),
      ],
    );

    Future<void> settle() async {
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
    }

    Future<void> tapCta(String label) async {
      await tester.tap(find.widgetWithText(FilledButton, label));
      await settle();
    }

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const ThreeBucksApp()),
    );
    await settle();
    await tapCta('Let’s go');

    // Income: no amount to enter, so there's nothing to skip.
    expect(find.widgetWithText(FilledButton, 'Skip for now'), findsOneWidget);
    await tester.tap(find.text('No regular income'));
    await settle();
    expect(find.byType(TextField), findsNothing);
    await tapCta('Continue');

    // Spending: a budget to aim for, with no share of income to compare.
    expect(find.text('How much do you want to spend a month?'), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
    await tester.enterText(find.byType(TextField), '800');
    await settle();
    await tapCta('Continue');

    // Goals: nothing pre-filled, since there's no income to save from.
    await tester.scrollUntilVisible(
      find.byType(TextField),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
    await tapCta('Continue');
    await tapCta('Continue'); // categories
    await tapCta('Skip'); // sharing

    expect(find.text('Coming in each month'), findsNothing);
    expect(find.text('Left unplanned'), findsNothing);
    await tapCta('Start tracking');
    await settle();

    final s = container.read(settingsProvider);
    expect(s.onboarded, isTrue);
    expect(s.incomeCents, 0);
    expect(s.monthlyBudgetCents, 80000);
    expect(s.savingsGoalCents, 0);

    await tester.pumpWidget(const SizedBox());
    container.dispose();
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(db.close);
  });

  testWidgets('setup can be skipped from the welcome screen', (tester) async {
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
        child: const ThreeBucksApp(),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Skip'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('A fresh month'), findsOneWidget);
    expect(prefs.getBool('onboarded'), isTrue);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(db.close);
  });
}
