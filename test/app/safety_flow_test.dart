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
import 'package:three_bucks/domain/social/safety.dart';

import '../support/fake_connectivity.dart';
import '../support/fake_social.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  testWidgets('report and block someone, then unblock them in Settings', (tester) async {
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
    server.connect(maya, sam);
    server.connect(ana, maya, accepted: false); // Ana asked Maya to connect
    final mine = FakeSocialBackend(
      server,
      signInAs: const Account(uid: 'maya', method: SignInMethod.apple),
      signedIn: true,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          databaseProvider.overrideWithValue(db),
          connectivityProvider.overrideWithValue(FakeConnectivity()),
          socialBackendProvider.overrideWithValue(mine),
        ],
        child: const ThreeBucksApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.descendant(of: find.byType(BottomAppBar), matching: find.text('People')));
    await tester.pumpAndSettle();

    // 1. Report Sam from his page; blocking is ticked by default.
    await tester.tap(find.text('Sam Lee'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('More for Sam Lee'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Report Sam Lee'));
    await tester.pumpAndSettle();
    expect(find.text('Reports go to the Three Bucks team, not to Sam Lee.'), findsOneWidget);
    await tester.tap(find.text('Harassment or bullying'));
    await tester.enterText(find.byType(TextField), 'Keeps sending fake bills');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send report'));
    await tester.pumpAndSettle();

    final (reporter, report) = server.reports.single;
    expect(reporter, 'maya');
    expect(report.reported, sam);
    expect(report.reason, ReportReason.harassment);
    expect(report.note, 'Keeps sending fake bills');
    expect(server.blocked('maya', 'sam'), isTrue);
    expect(server.connections.keys, isNot(contains('maya_sam')));
    expect(find.text('Sam Lee'), findsNothing, reason: 'back on People, Sam is gone');

    // 2. Block Ana straight from her request.
    await tester.tap(find.byTooltip('More for Ana Ruiz'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Block Ana Ruiz'));
    await tester.pumpAndSettle();
    expect(find.text('Block Ana Ruiz?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Block'));
    await tester.pumpAndSettle();
    expect(server.blocked('maya', 'ana'), isTrue);
    expect(server.connections, isEmpty);

    // 3. Both are listed in Settings; unblock Sam.
    await tester.tap(find.descendant(of: find.byType(BottomAppBar), matching: find.text('Home')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Blocked people'));
    await tester.pumpAndSettle();
    expect(find.text('Sam Lee'), findsOneWidget);
    expect(find.text('Ana Ruiz'), findsOneWidget);
    await tester.tap(
      find.descendant(of: find.widgetWithText(ListTile, 'Sam Lee'), matching: find.text('Unblock')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sam Lee'), findsNothing);
    expect(server.blocked('maya', 'sam'), isFalse);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(db.close);
    await server.dispose();
  });
}
