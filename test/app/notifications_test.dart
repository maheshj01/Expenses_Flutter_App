import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_bucks/app/account_flow.dart';
import 'package:three_bucks/app/app.dart';
import 'package:three_bucks/app/notifications.dart';
import 'package:three_bucks/app/providers.dart';
import 'package:three_bucks/app/social_providers.dart';
import 'package:three_bucks/data/local/app_database.dart';
import 'package:three_bucks/domain/social/account.dart';
import 'package:three_bucks/domain/social/push.dart';
import 'package:three_bucks/domain/social/shared_bill.dart';

import '../support/fake_connectivity.dart';
import '../support/fake_push.dart';
import '../support/fake_social.dart';

const _maya = Account(uid: 'maya', method: SignInMethod.apple);

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('PushMessage.fromData', () {
    test('reads what the server sends', () {
      final m = PushMessage.fromData({'topic': 'newBill', 'id': 'b1'}, title: 'T', body: 'B');
      expect(m!.topic, PushTopic.newBill);
      expect(m.id, 'b1');
      expect((m.title, m.body), ('T', 'B'));
    });

    test('ignores topics this version does not know', () {
      expect(PushMessage.fromData({'topic': 'groupInvite', 'id': 'x'}), isNull);
      expect(PushMessage.fromData({}), isNull);
      expect(PushMessage.fromData({'topic': 'request', 'id': ''})!.id, isNull);
    });
  });

  group('NotificationsNotifier', () {
    late SharedPreferences prefs;
    late FakeSocialServer server;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      server = FakeSocialServer()..addPerson('maya', 'maya', 'Maya Rao');
    });

    Future<ProviderContainer> start(FakePush? push, {bool signedIn = true}) async {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          socialBackendProvider.overrideWithValue(
            FakeSocialBackend(server, signInAs: _maya, signedIn: signedIn),
          ),
          pushServiceProvider.overrideWithValue(push),
        ],
      );
      addTearDown(container.dispose);
      container.listen(notificationsProvider, (_, _) {});
      await container.read(accountProvider.future);
      await container.read(notificationsProvider.notifier).refresh();
      return container;
    }

    test('unavailable without a push service', () async {
      final c = await start(null);
      expect(c.read(notificationsProvider).available, isFalse);
      expect(c.read(notificationsProvider).canOffer, isFalse);
    });

    test('offered, not asked for, until you choose', () async {
      final push = FakePush();
      final c = await start(push);
      expect(c.read(notificationsProvider).canOffer, isTrue);
      expect(push.prompts, 0);
      expect(push.registered, isEmpty);
    });

    test('turning on asks the phone once and registers you', () async {
      final push = FakePush();
      final c = await start(push);
      await c.read(notificationsProvider.notifier).turnOn();
      expect(push.prompts, 1);
      expect(push.registered, {'maya'});
      expect(c.read(notificationsProvider).on, isTrue);
      expect(c.read(notificationsProvider).canOffer, isFalse);
      expect(prefs.getBool('notifications'), isTrue);
    });

    test('a phone that already allows them registers without asking', () async {
      final push = FakePush(status: PushPermission.granted);
      await start(push);
      expect(push.prompts, 0);
      expect(push.registered, {'maya'});
    });

    test('nobody is registered while signed out', () async {
      final push = FakePush(status: PushPermission.granted);
      await start(push, signedIn: false);
      expect(push.registered, isEmpty);
    });

    test('turning off unregisters and is remembered', () async {
      final push = FakePush(status: PushPermission.granted);
      final c = await start(push);
      await c.read(notificationsProvider.notifier).turnOff();
      expect(push.registered, isEmpty);
      expect(prefs.getBool('notifications'), isFalse);

      // Next launch: still off, even though the phone allows them.
      final again = FakePush(status: PushPermission.granted);
      final c2 = await start(again);
      expect(again.registered, isEmpty);
      expect(c2.read(notificationsProvider).on, isFalse);
    });

    test('not now hides the offer without asking', () async {
      final push = FakePush();
      final c = await start(push);
      await c.read(notificationsProvider.notifier).notNow();
      expect(c.read(notificationsProvider).canOffer, isFalse);
      expect(push.prompts, 0);
    });

    test('refused in the prompt: blocked, not registered', () async {
      final push = FakePush(answer: PushPermission.denied);
      final c = await start(push);
      await c.read(notificationsProvider.notifier).turnOn();
      expect(c.read(notificationsProvider).blocked, isTrue);
      expect(c.read(notificationsProvider).on, isFalse);
      expect(push.registered, isEmpty);
    });

    test('signing out unregisters first, while the account can still write', () async {
      final push = FakePush(status: PushPermission.granted);
      final c = await start(push);
      await c.read(accountFlowProvider.notifier).signOut();
      expect(push.calls.last, 'unregister maya');
      expect(push.registered, isEmpty);
    });
  });

  group('in the app', () {
    late FakeSocialServer server;
    late FakePush push;
    late AppDatabase db;

    Future<void> launch(
      WidgetTester tester, {
      PushPermission status = PushPermission.notAsked,
    }) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      SharedPreferences.setMockInitialValues({'onboarded': true, 'name': 'Maya Rao'});
      final prefs = await SharedPreferences.getInstance();
      db = AppDatabase(NativeDatabase.memory());
      server = FakeSocialServer();
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
          date: DateTime(2026, 11, 20),
          note: 'Dinner',
          categoryId: 'food',
          createdAt: DateTime(2026, 11, 20),
          editedAt: DateTime(2026, 11, 20),
        );
      push = FakePush(status: status);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            databaseProvider.overrideWithValue(db),
            connectivityProvider.overrideWithValue(FakeConnectivity()),
            socialBackendProvider.overrideWithValue(
              FakeSocialBackend(server, signInAs: _maya, signedIn: true),
            ),
            pushServiceProvider.overrideWithValue(push),
          ],
          child: const ThreeBucksApp(),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> tearDownApp(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      await tester.runAsync(db.close);
    }

    Future<void> tapTab(WidgetTester tester, String label) async {
      await tester.tap(find.descendant(of: find.byType(BottomAppBar), matching: find.text(label)));
      await tester.pumpAndSettle();
    }

    testWidgets('People offers notifications once, and Settings can turn them off', (tester) async {
      await launch(tester);
      await tapTab(tester, 'People');
      expect(find.text('Know when people reach out'), findsOneWidget);

      await tester.tap(find.text('Turn on'));
      await tester.pumpAndSettle();
      expect(push.prompts, 1);
      expect(push.registered, {'maya'});
      expect(find.text('Know when people reach out'), findsNothing);

      await tapTab(tester, 'Home');
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      final tile = find.widgetWithText(SwitchListTile, 'Notifications');
      await tester.scrollUntilVisible(tile, 300, scrollable: find.byType(Scrollable).first);
      expect(tester.widget<SwitchListTile>(tile).value, isTrue);
      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(tile).value, isFalse);
      expect(push.registered, isEmpty);

      await tearDownApp(tester);
    });

    testWidgets('a notice while the app is open shows a banner that opens the inbox', (
      tester,
    ) async {
      await launch(tester, status: PushPermission.granted);
      push.deliver(
        const PushMessage(
          topic: PushTopic.request,
          title: 'New request',
          body: 'Ana wants to split bills with you on Three Bucks.',
          id: 'ana_maya',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('New request'), findsOneWidget);
      expect(find.text('Ana wants to split bills with you on Three Bucks.'), findsOneWidget);

      await tester.tap(find.text('View'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Inbox'), findsOneWidget);

      await tearDownApp(tester);
    });

    testWidgets('tapping a new-bill notification opens that bill', (tester) async {
      await launch(tester, status: PushPermission.granted);
      push.tap(const PushMessage(topic: PushTopic.newBill, title: '', body: '', id: 'b1'));
      await tester.pumpAndSettle();
      expect(find.text('Dinner'), findsWidgets);
      expect(find.textContaining('Sam Lee'), findsWidgets);

      await tearDownApp(tester);
    });
  });
}
