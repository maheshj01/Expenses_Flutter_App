// Drives a brand-new user through onboarding and the main screens, then a
// tour of splitting bills with people, and doubles as the screenshot run for
// tool/capture_screens.sh:
//
//   make capture-screens DEVICE=<simulator-udid|adb-serial>
//
// Each `shot()` prints `__EPOCH_SHOT__ <name>` (the marker the capture script
// watches for) and holds the screen while the host grabs the framebuffer.
// Data lives in an in-memory database with sample entries, sync is off and
// sharing runs on an in-memory fake backend, so a run never touches Firebase
// or the device's real data.

import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_bucks/app/app.dart';
import 'package:three_bucks/app/providers.dart';
import 'package:three_bucks/app/social_providers.dart';
import 'package:three_bucks/data/local/app_database.dart';
import 'package:three_bucks/data/local/drift_entry_repository.dart';
import 'package:three_bucks/data/sync/local_sync_source.dart';
import 'package:three_bucks/domain/entities/ledger_entry.dart';
import 'package:three_bucks/domain/social/account.dart';
import 'package:three_bucks/domain/social/settlement.dart';
import 'package:three_bucks/domain/social/shared_bill.dart';
import 'package:three_bucks/features/data_io/data_io_providers.dart';
import 'package:three_bucks/features/data_io/export_sheet.dart';
import 'package:three_bucks/shared/region_keys.dart';

import '../test/support/fake_social.dart';

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

  /// Describes the current screen for the capture script: on-screen text,
  /// named regions, theme and size. Regions are in raw screenshot pixels
  /// (the status bar included, since the app draws under it), plus the same
  /// box as 0..1 fractions of the screen.
  void emitMeta(
    WidgetTester tester,
    String name,
    String description,
    String feature,
    Map<String, Finder> regions,
  ) {
    final texts = <String>{
      for (final e in find.byType(RichText).evaluate())
        (e.widget as RichText).text.toPlainText().trim(),
      for (final e in find.byType(EditableText).evaluate())
        (e.widget as EditableText).controller.text.trim(),
    }..removeWhere((t) => t.isEmpty);
    final size = tester.view.physicalSize;
    final dpr = tester.view.devicePixelRatio;
    final boxes = <String, Object>{};
    regions.forEach((key, finder) {
      if (finder.evaluate().isEmpty) {
        debugPrint('region $key not found on $name');
        return;
      }
      // Only the part that can be seen: clipped by every list it scrolls in
      // and by the screen edges.
      var r = tester.getRect(finder.first);
      for (final list
          in find.ancestor(of: finder.first, matching: find.byType(Scrollable)).evaluate()) {
        final box = list.renderObject! as RenderBox;
        r = r.intersect(box.localToGlobal(Offset.zero) & box.size);
      }
      r = r.intersect(Offset.zero & (size / dpr));
      if (r.width <= 0 || r.height <= 0) {
        debugPrint('region $key is off screen on $name');
        return;
      }
      final x = r.left * dpr, y = r.top * dpr, w = r.width * dpr, h = r.height * dpr;
      boxes[key] = {
        'x': x.round(),
        'y': y.round(),
        'w': w.round(),
        'h': h.round(),
        'nx': x / size.width,
        'ny': y / size.height,
        'nw': w / size.width,
        'nh': h / size.height,
      };
    });
    final app = find.byType(MaterialApp);
    final dark =
        app.evaluate().isNotEmpty &&
        Theme.of(tester.element(app.first)).brightness == Brightness.dark;
    final meta = {
      'description': description,
      'feature': feature,
      'theme': dark ? 'dark' : 'light',
      'size': {'w': size.width.round(), 'h': size.height.round()},
      'regions': boxes,
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
    Map<String, Key> regions = const {},
  }) async {
    await settle(tester);
    if (!_captureShots) return;
    emitMeta(tester, name, description, feature, {
      for (final MapEntry(:key, :value) in regions.entries) key: find.byKey(value),
    });
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
    await tester.enterText(find.byType(TextField), 'Maya');
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
      regions: {'goal-grid': RegionKeys.goalGrid},
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
    await shot(
      tester,
      '06_sharing',
      description: 'Bill sharing question with hints for people on and off the app',
      feature: 'onboarding',
    );
    await next(tester, 'Continue');

    await shot(
      tester,
      '07_plan',
      description: 'Monthly plan summary: income split into live on, set aside, unplanned',
      feature: 'onboarding',
      regions: {'plan-card': RegionKeys.planCard},
    );
    await next(tester, 'Start tracking');
    await settle(tester, frames: 12);

    // The app
    await shot(
      tester,
      '08_home',
      description: 'Dashboard: living spend vs budget, safe to spend, buckets, savings goal',
      feature: 'home',
      regions: {
        'budget-hero': RegionKeys.budgetHero,
        'month-tiles': RegionKeys.monthTiles,
        'goal-card': RegionKeys.goalCard,
      },
    );

    await tester.tap(find.byTooltip('Add entry'));
    await settle(tester);
    await tester.enterText(find.byType(TextField).last, 'costco 46 split');
    // Close the keyboard so the shot shows the app's own keypad.
    FocusManager.instance.primaryFocus?.unfocus();
    await shot(
      tester,
      '09_add_entry',
      description: 'Quick entry: "costco 46 split" fills the amount, split and category',
      feature: 'entries',
      regions: {
        'entry-amount': RegionKeys.entryAmount,
        'quick-entry': RegionKeys.quickEntry,
        'entry-categories': RegionKeys.entryCategories,
        'keypad': RegionKeys.keypad,
        'save-button': RegionKeys.saveButton,
      },
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
      regions: {'month-chart': RegionKeys.monthChart},
    );
    await tester.pageBack();
    await settle(tester);

    await tester.tap(find.text('Home').last);
    await settle(tester);
    await tester.tap(find.byTooltip('Settings'));
    await shot(
      tester,
      '13_settings',
      description: 'Settings: account, sync status, plan and goals, budget, currency, categories',
      feature: 'settings',
    );

    await tester.pumpWidget(const SizedBox());
    await settle(tester, frames: 4);
    await db.close();
  });

  testWidgets('sharing: sign in, people, bills, flags, settle up', (tester) async {
    SharedPreferences.setMockInitialValues({
      'onboarded': true,
      'name': 'Maya',
      'splitsBills': true,
      'savedGuests': ['Alex'],
      'monthlyBudgetCents': 240000,
    });
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase(NativeDatabase.memory());
    await _seed(db);
    final server = _seedPeople();
    final backend = FakeSocialBackend(
      server,
      signInAs: const Account(
        uid: 'maya',
        method: SignInMethod.apple,
        email: 'maya@privaterelay.example',
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          databaseProvider.overrideWithValue(db),
          remoteStoreProvider.overrideWithValue(null),
          socialBackendProvider.overrideWithValue(backend),
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
    await settle(tester);

    await tester.tap(find.text('People').last);
    await shot(
      tester,
      '14_people_sign_in',
      description: 'People tab before signing in: what sharing does, Apple / Google sign-in',
      feature: 'people',
    );
    await tester.tap(find.text('Continue with Apple'));
    await settle(tester);
    await shot(
      tester,
      '15_username',
      description: 'Picking a unique username, pre-filled from the name',
      feature: 'people',
    );
    await tester.tap(find.text('Continue as @maya'));
    await settle(tester, frames: 14);
    await shot(
      tester,
      '16_people',
      description: 'People: totals owed, a request to accept, balances per person',
      feature: 'people',
    );

    await tester.tap(find.byTooltip('Add people'));
    await settle(tester);
    await tester.enterText(find.byKey(const ValueKey('find-handle')), 'leo');
    await tester.tap(find.text('Find'));
    FocusManager.instance.primaryFocus?.unfocus();
    await shot(
      tester,
      '17_add_person',
      description: 'Add by exact username, plus your own invite QR code and share link',
      feature: 'people',
    );
    await tester.tap(find.text('Send request'));
    await settle(tester);
    await tester.tapAt(const Offset(20, 80));
    await settle(tester);

    await tester.tap(find.text('Sam Lee'));
    await settle(tester, frames: 12);
    await shot(
      tester,
      '18_person',
      description: 'One person: balance, settle up, and every bill and payment between you',
      feature: 'people',
    );

    await tester.tap(find.text('Dinner at Lupa'));
    await settle(tester);
    await shot(
      tester,
      '19_bill_disputed',
      description: 'A bill you paid with a disputed share: the flag reason and note',
      feature: 'people',
    );
    await tester.tapAt(const Offset(20, 80));
    await settle(tester);

    await tester.tap(find.text('Settle up'));
    await settle(tester);
    FocusManager.instance.primaryFocus?.unfocus();
    await shot(
      tester,
      '20_settle_up',
      description: 'Settle up records a payment made outside the app',
      feature: 'people',
    );
    await tester.tapAt(const Offset(20, 80));
    await settle(tester);
    await tester.pageBack();
    await settle(tester);

    await tester.tap(find.byTooltip('Inbox'));
    await settle(tester, frames: 12);
    await shot(
      tester,
      '21_inbox',
      description: 'Inbox: a flag to resolve, a request, a new bill and a payment',
      feature: 'people',
    );
    await tester.tap(find.textContaining('Concert tickets'));
    await settle(tester);
    await tester.tap(find.text('Flag my share'));
    await settle(tester);
    FocusManager.instance.primaryFocus?.unfocus();
    await shot(
      tester,
      '22_flag',
      description: 'Flagging your share: pick a reason and leave a note',
      feature: 'people',
    );
    await tester.tapAt(const Offset(20, 80));
    await settle(tester);
    await tester.tapAt(const Offset(20, 80));
    await settle(tester);
    await tester.pageBack();
    await settle(tester);

    await tester.tap(find.byTooltip('Add entry'));
    await settle(tester);
    await tester.enterText(find.byType(TextField).last, 'pizza night 84');
    await tester.tap(find.text('🛒  Food'));
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(tester);
    await tester.tap(find.text('Split bill'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilterChip, 'Sam Lee'));
    await tester.tap(find.widgetWithText(FilterChip, 'Ana Ruiz'));
    await tester.tap(find.widgetWithText(FilterChip, 'Alex'));
    await settle(tester);
    await tester.enterText(find.byType(TextField).last, 'I covered the tip');
    FocusManager.instance.primaryFocus?.unfocus();
    await shot(
      tester,
      '23_split_picker',
      description: 'Split picker: people on the app, people who aren’t, and a note for them',
      feature: 'people',
      regions: {'split-sheet': RegionKeys.splitSheet, 'split-button': RegionKeys.splitButton},
    );
    await tester.tap(find.textContaining('Split 4 ways'));
    await settle(tester);
    await shot(
      tester,
      '24_split_entry',
      description: 'The entry sheet shows your share and what the others owe',
      feature: 'people',
      regions: {
        'entry-amount': RegionKeys.entryAmount,
        'share-line': RegionKeys.shareLine,
        'save-button': RegionKeys.saveButton,
      },
    );

    await tester.pumpWidget(const SizedBox());
    await settle(tester, frames: 4);
    await db.close();
    await server.dispose();
  });

  testWidgets('import a spreadsheet, then export it', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarded': true, 'name': 'Maya'});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase(NativeDatabase.memory());
    final delivery = _NoMail();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          databaseProvider.overrideWithValue(db),
          remoteStoreProvider.overrideWithValue(null),
          spreadsheetPickerProvider.overrideWithValue(
            () async =>
                (name: 'Expenses-2026.csv', bytes: Uint8List.fromList(utf8.encode(_sampleCsv()))),
          ),
          exportDeliveryProvider.overrideWithValue(delivery),
        ],
        child: const ThreeBucksApp(),
      ),
    );
    await settle(tester);

    Future<void> waitFor(Finder finder) async {
      for (var i = 0; i < 100 && finder.evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await settle(tester);
    }

    await tester.ensureVisible(find.text('Import a spreadsheet'));
    await shot(
      tester,
      '25_import_offer',
      description: 'A brand-new Home offers to import an existing spreadsheet',
      feature: 'import',
    );
    await tapText(tester, 'Import a spreadsheet');
    await shot(
      tester,
      '26_import_pick',
      description: 'Import: what files work, before picking one',
      feature: 'import',
    );
    await tester.tap(find.text('Choose file'));
    await waitFor(find.text('Check your import'));
    await shot(
      tester,
      '27_import_review',
      description: 'Import review: entries found, sheets, and categories matched',
      feature: 'import',
      regions: {
        'import-summary': RegionKeys.importSummary,
        'import-categories': RegionKeys.importCategories,
      },
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -700));
    await shot(
      tester,
      '28_import_months',
      description: 'Import review: duplicates, unreadable rows and a month-by-month preview',
      feature: 'import',
      regions: {'month-preview': RegionKeys.monthPreview},
    );
    await tester.tap(find.textContaining(RegExp(r'^Import \d+ entries')));
    await waitFor(find.textContaining('Imported'));
    await shot(
      tester,
      '29_import_done',
      description: 'Import finished, with an undo',
      feature: 'import',
    );
    await tapText(tester, 'Done');

    await tester.fling(find.byType(Scrollable).first, const Offset(0, 800), 2000);
    await settle(tester);
    await tester.tap(find.byTooltip('Settings'));
    await settle(tester);
    await tester.scrollUntilVisible(find.text('Export to a spreadsheet'), 200);
    await tapText(tester, 'Export to a spreadsheet');
    await waitFor(find.textContaining(RegExp(r'^\d+ entries$')));
    await shot(
      tester,
      '30_export',
      description: 'Export to a spreadsheet: pick a year and email it',
      feature: 'export',
      regions: {'export-sheet': RegionKeys.exportSheet, 'email-button': RegionKeys.emailButton},
    );

    await tester.pumpWidget(const SizedBox());
    await settle(tester, frames: 4);
    await db.close();
  });
}

/// People to share with: Sam owes you, you owe Ana (and Ana disputes a
/// dinner), Jordan asked to connect, and Leo is on the app but not added.
FakeSocialServer _seedPeople() {
  final server = FakeSocialServer();
  final now = DateTime.now();
  DateTime day(int d) => DateTime(now.year, now.month, d.clamp(1, now.day));
  const me = Profile(uid: 'maya', handle: 'maya', name: 'Maya');
  final sam = server.addPerson('sam', 'samlee', 'Sam Lee');
  final ana = server.addPerson('ana', 'ana.ruiz', 'Ana Ruiz');
  final jordan = server.addPerson('jordan', 'jordanp', 'Jordan Park');
  server
    ..addPerson('leo', 'leo', 'Leo Martins')
    ..connect(me, sam, at: day(2))
    ..connect(me, ana, at: day(3))
    ..connect(jordan, me, accepted: false, at: now.subtract(const Duration(hours: 3)));

  SharedBill bill(
    String id,
    String by,
    List<Profile> people,
    double amount,
    String note,
    DateTime date, {
    String category = 'food',
    String memo = '',
    Map<String, BillFlag> flags = const {},
    DateTime? created,
  }) => SharedBill(
    id: id,
    createdBy: by,
    members: [for (final p in people) p.uid],
    people: {for (final p in people) p.uid: p},
    amountCents: (amount * 100).round(),
    currencyCode: 'USD',
    date: date,
    note: note,
    memo: memo,
    categoryId: category,
    flags: flags,
    createdAt: created ?? date,
    editedAt: created ?? date,
  );

  for (final b in [
    bill('b1', 'maya', [me, sam], 86.40, 'Costco', day(4)),
    bill(
      'b2',
      'maya',
      [me, sam, ana],
      126,
      'Dinner at Lupa',
      day(9),
      category: 'entertainment',
      flags: {
        'ana': BillFlag(
          reason: FlagReason.wrongAmount,
          note: 'I left before dessert',
          at: now.subtract(const Duration(minutes: 40)),
        ),
      },
    ),
    bill('b3', 'sam', [sam, me], 62, 'Utilities', day(6), category: 'electricity'),
    bill(
      'b4',
      'ana',
      [ana, me],
      180,
      'Concert tickets',
      day(12),
      category: 'entertainment',
      memo: 'Row F, see you there!',
      created: now.subtract(const Duration(hours: 1)),
    ),
  ]) {
    server.bills[b.id] = b;
  }
  server.settlements['s1'] = Settlement(
    id: 's1',
    from: 'sam',
    to: 'maya',
    amountCents: 4000,
    currencyCode: 'USD',
    date: day(10),
    createdBy: 'sam',
    createdAt: now.subtract(const Duration(hours: 5)),
  );
  return server;
}

/// Never opens a mail composer during a capture run.
class _NoMail extends ExportDelivery {
  @override
  Future<bool> email(ExportFile file, {String? to}) async => true;
}

/// A few months of made-up expenses in a typical layout, with one row
/// that can't be read and a couple matching what is already logged.
String _sampleCsv() {
  final now = DateTime.now();
  final rows = <String>['Date,Amount,Category,Description'];
  final items = [
    (1, 1166.0, 'Housing', 'Rent'),
    (2, 46.10, 'Groceries', 'Costco'),
    (3, 13.0, 'Productivity', 'Wifi'),
    (4, 600.0, 'Investments', 'VOO'),
    (6, 22.20, 'Car', 'Fuel'),
    (9, 18.40, 'Groceries', 'Kroger'),
    (12, 32.50, 'Entertainment', 'Zoo'),
    (15, 47.0, 'Electricity', 'Power bill'),
    (18, 9.99, 'Subscriptions', 'Music'),
    (21, -500.0, 'Housing', 'Rent from roommate'),
    (24, 64.0, 'Eating out', 'Dinner'),
  ];
  for (var back = 5; back >= 1; back--) {
    final m = DateTime(now.year, now.month - back);
    for (final (day, amount, cat, note) in items) {
      final d = '${m.year}-${m.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
      rows.add('$d,${amount + back},$cat,$note');
    }
  }
  rows.add('sometime,12,Groceries,Snacks');
  return rows.join('\n');
}
