// Drives a brand-new user through onboarding and the main screens, and
// doubles as the screenshot run for tool/capture_screens.sh:
//
//   make capture-screens DEVICE=<simulator-udid|adb-serial>
//
// Each `shot()` prints `__EPOCH_SHOT__ <name>` (the marker the capture script
// watches for) and holds the screen while the host grabs the framebuffer.
// Data lives in an in-memory database with sample entries, and sync is off,
// so a run never touches Firebase or the device's real data.

import 'dart:convert';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_bucks/app/app.dart';
import 'package:three_bucks/app/providers.dart';
import 'package:three_bucks/data/local/app_database.dart';
import 'package:three_bucks/data/local/drift_entry_repository.dart';
import 'package:three_bucks/data/sync/local_sync_source.dart';
import 'package:three_bucks/domain/entities/ledger_entry.dart';

/// Set `--dart-define=CAPTURE_SHOTS=false` to run the flow without pauses.
const _captureShots = bool.fromEnvironment('CAPTURE_SHOTS', defaultValue: true);

/// Sample history so the dashboard, activity and history screens have
/// something to show: this month in detail, earlier months as totals.
Future<void> _seed(AppDatabase db) async {
  final repo = DriftEntryRepository(db, LocalChanges());
  final now = DateTime.now();
  var n = 0;
  Future<void> add(DateTime date, double amount, String category, String note, {int split = 1}) =>
      repo.save(
        LedgerEntry(
          id: 'seed-${n++}',
          amountCents: (amount * 100).round(),
          categoryId: category,
          date: date,
          note: note,
          splitWays: split,
        ),
      );

  DateTime day(int d) => DateTime(now.year, now.month, d.clamp(1, now.day));

  // This month
  await add(day(1), 1166, 'housing', 'Rent and water');
  await add(day(1), 3605, 'salary', 'Paycheck');
  await add(day(2), 40, 'productivity', 'Wifi');
  await add(day(3), 1250, 'investment', 'VOO and QQQ');
  await add(day(5), -500, 'housing', 'Rent share back');
  await add(day(6), 46.10, 'food', 'Costco', split: 2);
  await add(day(8), 33.67, 'electricity', 'Electricity');
  await add(day(9), 10.50, 'food', 'Dominos');
  await add(day(11), 41.20, 'car', 'Gas · 10 gal');
  await add(day(13), 18.42, 'food', 'Kroger');
  await add(day(14), 28, 'productivity', 'Verizon');
  await add(day(15), 14, 'entertainment', 'Movie');
  await add(day(16), 3605, 'salary', 'Paycheck');

  // Earlier months this year, and last year, as monthly totals.
  const lived = [1416, 1253, 1427, 1211, 1057, 1041, 1404, 1217, 1915, 1569, 1300, 1280];
  const invested = [305, 300, 2750, 3810, 944, 3788, 4226, 2789, 6109, 4944, 3000, 2500];
  for (var back = 1; back <= 14; back++) {
    final m = DateTime(now.year, now.month - back, 10);
    final i = (m.month - 1) % 12;
    await add(m, lived[i] * 0.55, 'housing', 'Rent');
    await add(m, lived[i] * 0.30, 'food', 'Groceries');
    await add(m, lived[i] * 0.15, 'car', 'Gas');
    await add(m, invested[i].toDouble(), 'investment', 'Index funds');
    await add(m, 7210, 'salary', 'Paychecks');
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  /// Pumps frames for a while so entrance animations finish, without
  /// waiting on anything that never settles.
  Future<void> settle(WidgetTester tester, {int frames = 10}) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  void emitMeta(WidgetTester tester, String name, String description, String feature) {
    final texts = <String>{
      for (final e in find.byType(RichText).evaluate())
        (e.widget as RichText).text.toPlainText().trim(),
      for (final e in find.byType(EditableText).evaluate())
        (e.widget as EditableText).controller.text.trim(),
    }..removeWhere((t) => t.isEmpty);
    final size = tester.view.physicalSize;
    final app = find.byType(MaterialApp);
    final dark =
        app.evaluate().isNotEmpty &&
        Theme.of(tester.element(app.first)).brightness == Brightness.dark;
    final meta = {
      'description': description,
      'feature': feature,
      'theme': dark ? 'dark' : 'light',
      'size': {'w': size.width.round(), 'h': size.height.round()},
      'regions': <String, Object>{},
      'texts': texts.toList(),
    };
    debugPrint('__EPOCH_META__ $name ${base64Encode(utf8.encode(jsonEncode(meta)))}');
  }

  /// Marks the current screen for capture and holds it ~3s of real time.
  Future<void> shot(
    WidgetTester tester,
    String name, {
    required String description,
    required String feature,
  }) async {
    await settle(tester);
    if (!_captureShots) return;
    emitMeta(tester, name, description, feature);
    debugPrint('__EPOCH_SHOT__ $name');
    for (var i = 0; i < 24; i++) {
      await tester.pump(const Duration(milliseconds: 130));
    }
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    final f = find.text(text).last;
    await tester.ensureVisible(f);
    await settle(tester, frames: 3);
    await tester.tap(f);
    await settle(tester, frames: 4);
  }

  Future<void> next(WidgetTester tester, String label) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.tap(find.widgetWithText(FilledButton, label));
    await settle(tester, frames: 6);
  }

  testWidgets('new user: onboarding -> dashboard -> add -> activity -> history -> settings', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase(NativeDatabase.memory());
    await _seed(db);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          databaseProvider.overrideWithValue(db),
          remoteStoreProvider.overrideWithValue(null), // never sync from a test run
        ],
        child: const ThreeBucksApp(),
      ),
    );

    // Onboarding
    await shot(
      tester,
      '01_welcome',
      description: 'Welcome screen with the rising three-bar mark and an optional name field',
      feature: 'onboarding',
    );
    await tester.enterText(find.byType(TextField), 'Mahesh');
    await next(tester, 'Let’s go');

    await tapText(tester, 'Every 2 weeks');
    await tester.enterText(find.byType(TextField), '1800');
    await shot(
      tester,
      '02_income',
      description: 'Take-home pay with pay frequency and the monthly equivalent',
      feature: 'onboarding',
    );
    await next(tester, 'Continue');

    await tapText(tester, '60% · \$2,340');
    await shot(
      tester,
      '03_spending',
      description: 'Monthly spending with income-based suggestions and a split bar',
      feature: 'onboarding',
    );
    await next(tester, 'Continue');

    await tapText(tester, 'Invest more');
    await tapText(tester, 'Build an emergency fund');
    await shot(
      tester,
      '04_goals',
      description: 'Goal choices and the pre-filled monthly savings target',
      feature: 'onboarding',
    );
    await next(tester, 'Continue');

    await tapText(tester, 'Pets');
    await tester.drag(find.byType(Scrollable).last, const Offset(0, 600));
    await shot(
      tester,
      '05_categories',
      description: 'Spending categories with the common ones preselected',
      feature: 'onboarding',
    );
    await next(tester, 'Continue');

    await tapText(tester, 'Yes, I split some bills');
    await tester.enterText(find.byType(TextField), 'Alex');
    FocusManager.instance.primaryFocus?.unfocus();
    await shot(
      tester,
      '06_sharing',
      description: 'Bill sharing question with the partner name revealed',
      feature: 'onboarding',
    );
    await next(tester, 'Continue');

    await shot(
      tester,
      '07_plan',
      description: 'Monthly plan summary: income split into live on, set aside, unplanned',
      feature: 'onboarding',
    );
    await next(tester, 'Start tracking');
    await settle(tester, frames: 12);

    // The app
    await shot(
      tester,
      '08_home',
      description: 'Dashboard: living spend vs budget, safe to spend, buckets, savings goal',
      feature: 'home',
    );

    await tester.tap(find.byTooltip('Add entry'));
    await settle(tester);
    await tester.enterText(find.byType(TextField).last, 'costco 46 split');
    await shot(
      tester,
      '09_add_entry',
      description: 'Quick entry: "costco 46 split" fills the amount, split and category',
      feature: 'entries',
    );
    await tester.tap(find.textContaining('Save').last);
    await settle(tester);

    await tester.tap(find.text('Activity').last);
    await shot(
      tester,
      '10_activity',
      description: 'This month’s entries grouped by day with totals and filters',
      feature: 'activity',
    );

    await tester.tap(find.text('History').last);
    await shot(
      tester,
      '11_history',
      description: 'Every year with lived, invested and earned totals',
      feature: 'history',
    );

    await tester.tap(find.text('${DateTime.now().year}').first);
    await settle(tester, frames: 8);
    await shot(
      tester,
      '12_year',
      description: 'One year: monthly chart, totals and top categories',
      feature: 'history',
    );
    await tester.pageBack();
    await settle(tester);

    await tester.tap(find.text('Settings').last);
    await shot(
      tester,
      '13_settings',
      description: 'Settings: sync status, plan and goals, budget, currency, categories',
      feature: 'settings',
    );

    await tester.pumpWidget(const SizedBox());
    await settle(tester, frames: 4);
    await db.close();
  });
}
