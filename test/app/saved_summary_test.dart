import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_bucks/app/app.dart';
import 'package:three_bucks/app/providers.dart';
import 'package:three_bucks/core/day.dart';
import 'package:three_bucks/data/local/app_database.dart';
import 'package:three_bucks/domain/entities/ledger_entry.dart';
import 'package:three_bucks/domain/services/period_summary.dart';
import 'package:three_bucks/features/history/year_screen.dart';
import 'package:three_bucks/shared/money_format.dart';

import '../support/fake_connectivity.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  Future<AppDatabase> pumpHome(WidgetTester tester, List<(int, String)> entries) async {
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
    final container = ProviderScope.containerOf(tester.element(find.byType(ThreeBucksApp)));
    final today = dateOnly(DateTime.now());
    for (final (i, (cents, category)) in entries.indexed) {
      await container
          .read(entryRepositoryProvider)
          .save(LedgerEntry(id: 'e$i', amountCents: cents, categoryId: category, date: today));
    }
    await tester.pumpAndSettle();
    return db;
  }

  Future<void> tearDownDb(WidgetTester tester, AppDatabase db) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(db.close);
  }

  testWidgets('saved is earned minus spent, with investing shown as where it went', (tester) async {
    final db = await pumpHome(tester, [
      (500000, 'salary'),
      (300000, 'housing'),
      (50000, 'investment'),
    ]);

    expect(find.text('\$2,000'), findsWidgets, reason: 'Saved tile and card, not \$500');
    expect(find.text('Saved this month'), findsOneWidget);
    expect(find.text('40% of income'), findsOneWidget);
    expect(find.text('Invested \$500'), findsOneWidget);
    expect(find.text('Left in cash \$1,500'), findsOneWidget);

    await tearDownDb(tester, db);
  });

  testWidgets('investing more than you saved shows cash going negative', (tester) async {
    final db = await pumpHome(tester, [
      (721000, 'salary'),
      (191460, 'housing'),
      (610900, 'investment'),
    ]);

    expect(find.text('Invested \$6,109'), findsOneWidget);
    expect(find.text('Cash -\$814'), findsOneWidget);
    expect(find.text('invested more than you saved'), findsOneWidget);

    await tearDownDb(tester, db);
  });

  testWidgets('spending more than you earned shows a negative saved', (tester) async {
    final db = await pumpHome(tester, [(500000, 'salary'), (540000, 'housing')]);

    expect(find.text('over income'), findsOneWidget);
    expect(find.text('You spent \$400 more than you earned'), findsOneWidget);

    await tearDownDb(tester, db);
  });

  testWidgets('with no income, investing takes the place of saved', (tester) async {
    final db = await pumpHome(tester, [(215000, 'housing'), (30000, 'investment')]);

    expect(find.text('Invested'), findsOneWidget);
    expect(find.text('Invested this month'), findsOneWidget);
    expect(find.text('Saved'), findsNothing);
    expect(find.text('Earned'), findsNothing);

    await tearDownDb(tester, db);
  });

  test('the months list names the parts of what was saved', () {
    final money = MoneyFormat('USD');
    String line({int earned = 0, int spent = 0, int invested = 0}) => YearScreen.monthLine(
      PeriodSummary(earnedCents: earned, livedCents: spent, investedCents: invested, entryCount: 1),
      money,
    );

    expect(
      line(earned: 500000, spent: 300000, invested: 50000),
      '\$1,500 in cash · \$500 invested',
    );
    expect(line(earned: 500000, spent: 280000), '\$2,200 in cash');
    expect(
      line(earned: 500000, spent: 300000, invested: 250000),
      '-\$500 in cash · \$2,500 invested',
    );
    // September: earned 7,210, spent 1,914.60, invested 6,109.
    expect(
      line(earned: 721000, spent: 191460, invested: 610900),
      '-\$814 in cash · \$6,109 invested',
    );
    expect(line(earned: 500000, spent: 540000), '\$400 over income');
    expect(
      line(earned: 500000, spent: 540000, invested: 30000),
      '\$400 over income · \$300 invested',
    );
    expect(line(earned: 500000, spent: 500000), 'Nothing saved');
    expect(line(spent: 215000, invested: 30000), '\$300 invested');
    expect(line(spent: 215000), 'No income');
  });
}
