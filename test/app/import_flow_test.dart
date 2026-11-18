import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_bucks/app/app.dart';
import 'package:three_bucks/app/providers.dart';
import 'package:three_bucks/data/local/app_database.dart';
import 'package:three_bucks/features/data_io/data_io_providers.dart';
import 'package:three_bucks/features/data_io/export_sheet.dart';

import '../support/fake_connectivity.dart';

class _RecordingDelivery extends ExportDelivery {
  ExportFile? emailed;
  String? to;

  @override
  Future<bool> email(ExportFile file, {String? to}) async {
    emailed = file;
    this.to = to;
    return true;
  }
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  testWidgets(
    'import a CSV from an empty Home, undo it, then export',
    timeout: const Timeout(Duration(minutes: 2)),
    (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      SharedPreferences.setMockInitialValues({'onboarded': true});
      final prefs = await SharedPreferences.getInstance();
      final db = AppDatabase(NativeDatabase.memory());
      final now = DateTime.now();
      String day(int d) =>
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
      final csv = [
        'Date,Amount,Category,Description',
        '${day(1)},1166,Housing,Rent',
        '${day(2)},17,food,Fruits',
        '${day(2)},9,Pets,Dog food',
        'later,5,Food,Oops',
      ].join('\n');
      final delivery = _RecordingDelivery();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            databaseProvider.overrideWithValue(db),
            connectivityProvider.overrideWithValue(FakeConnectivity()),
            spreadsheetPickerProvider.overrideWithValue(
              () async => (name: 'expenses.csv', bytes: Uint8List.fromList(utf8.encode(csv))),
            ),
            exportDeliveryProvider.overrideWithValue(delivery),
          ],
          child: const ThreeBucksApp(),
        ),
      );
      await tester.pumpAndSettle();

      /// Taps [label], then lets real async work (isolates, the database)
      /// run until [until] shows up.
      Future<void> tapAndWait(String label, Finder until) async {
        await tester.runAsync(() async {
          await tester.tap(find.text(label));
          for (var i = 0; i < 400 && until.evaluate().isEmpty; i++) {
            await Future<void>.delayed(const Duration(milliseconds: 30));
            await tester.pump();
          }
        });
        await tester.pumpAndSettle();
      }

      // Nothing logged yet, so Home offers an import.
      await tester.ensureVisible(find.text('Import a spreadsheet'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Import a spreadsheet'));
      await tester.pumpAndSettle();
      expect(find.text('Bring in your spreadsheet'), findsOneWidget);

      await tapAndWait('Choose file', find.text('Check your import'));

      expect(find.text('Check your import'), findsOneWidget);
      expect(find.text('3 entries'), findsOneWidget);
      expect(find.text('expenses'), findsOneWidget, reason: 'the CSV shows as one sheet');
      expect(find.text('Pets'), findsWidgets);
      expect(find.text('New'), findsOneWidget, reason: 'Pets is created');
      expect(find.textContaining('1 row couldn’t be read'), findsOneWidget);

      await tapAndWait('Import 3 entries', find.text('Imported 3 entries'));
      expect(find.text('Imported 3 entries'), findsOneWidget);
      expect(find.textContaining('Added 1 new category'), findsOneWidget);

      await tapAndWait('Undo import', find.text('Import undone'));
      expect(find.text('Import undone'), findsOneWidget);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text('Import a spreadsheet'), findsOneWidget, reason: 'back to empty');

      // Import again and keep it this time.
      await tester.ensureVisible(find.text('Import a spreadsheet'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Import a spreadsheet'));
      await tester.pumpAndSettle();
      await tapAndWait('Choose file', find.text('Check your import'));
      await tapAndWait('Import 3 entries', find.text('Imported 3 entries'));
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text('Rent'), findsOneWidget);

      // Export everything from Settings and email it.
      await tester.fling(find.byType(Scrollable).first, const Offset(0, 800), 2000);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Export to a spreadsheet'), 200);
      await tapAndWait('Export to a spreadsheet', find.text('3 entries'));
      expect(find.text('3 entries'), findsOneWidget);
      await tester.runAsync(() async {
        await tester.tap(find.text('Email it'));
        // Building the workbook runs in an isolate, which is slow to start in tests.
        for (var i = 0; i < 400 && delivery.emailed == null; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump();
        }
      });
      await tester.pumpAndSettle();
      expect(delivery.emailed?.name, 'three-bucks-all-years.xlsx');
      expect(delivery.emailed?.subject, 'Three Bucks export · All years');
      expect(delivery.emailed!.bytes.length, greaterThan(1000));
      expect(find.text('Export to a spreadsheet'), findsOneWidget, reason: 'sheet closed');

      await tester.pumpWidget(const SizedBox());
      // Let debounced work (sync, stream queries) finish before closing.
      await tester.pump(const Duration(seconds: 2));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        await db.close();
      });
    },
  );
}
