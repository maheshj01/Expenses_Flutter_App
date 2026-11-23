// The account flow App Review asks to see, on a real device against the
// real Firebase project: launch, onboarding and a first entry, then
// creating an account (Sign in with Apple or Google, then a username),
// signing out and in again, deleting the account (held button, goodbye
// page) and, so the run leaves nothing behind, restoring it.
//
//   flutter test integration_test/account_flow_test.dart -d <iphone-udid> \
//     --dart-define=SIGN_IN=Apple        # or Google
//
// The system sign-in sheet needs a person: the test pauses at each one,
// prints `__ACTION__ …` and waits (up to SIGN_IN_TIMEOUT seconds) until
// sign-in finishes. Everything else is tapped by the test.
//
// What it touches: the account you sign in with gets a username (if it has
// none), is set to be deleted and is then restored. Entries live in an
// in-memory database and sync is off, so nothing is added to its backup.
// Any account this app install was signed in to is signed out first.

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_bucks/app/account_flow.dart';
import 'package:three_bucks/app/app.dart';
import 'package:three_bucks/app/backend.dart';
import 'package:three_bucks/app/providers.dart';
import 'package:three_bucks/app/social_providers.dart';
import 'package:three_bucks/data/local/app_database.dart';
import 'package:three_bucks/features/account/hold_to_confirm.dart';
import 'package:three_bucks/shared/region_keys.dart';

/// Which "Continue with …" button to use: Apple or Google.
const _signIn = String.fromEnvironment('SIGN_IN', defaultValue: 'Apple');

/// How long to wait for a person to finish a sign-in sheet.
const _signInTimeout = Duration(
  seconds: int.fromEnvironment('SIGN_IN_TIMEOUT', defaultValue: 180),
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  /// Pumps frames for a while so animations finish (real time on a device).
  Future<void> settle(WidgetTester tester, {int frames = 10}) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  /// Holds the current screen so a person watching (or a recording) can
  /// read it.
  Future<void> linger(WidgetTester tester, [Duration d = const Duration(seconds: 2)]) async {
    final steps = d.inMilliseconds ~/ 100;
    for (var i = 0; i < steps; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Pumps until one of [finders] shows up, and returns which.
  Future<Finder> waitFor(
    WidgetTester tester,
    List<Finder> finders, {
    Duration timeout = const Duration(seconds: 30),
    String? what,
  }) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 200));
      for (final f in finders) {
        if (f.evaluate().isNotEmpty) return f;
      }
    }
    fail('Timed out waiting for ${what ?? finders.map((f) => f.describeMatch(Plurality.one))}');
  }

  /// Tells the person at the phone what to do.
  void action(String message) => debugPrint('__ACTION__ $message');

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

  Future<void> tab(WidgetTester tester, String name) async {
    await tester.tap(find.descendant(of: find.byType(BottomAppBar), matching: find.text(name)));
    await settle(tester, frames: 6);
  }

  Future<void> openSettings(WidgetTester tester) async {
    await tab(tester, 'Home');
    await tester.tap(find.byTooltip('Settings'));
    await settle(tester, frames: 8);
  }

  Future<void> scrollTo(WidgetTester tester, Finder target) async {
    // The list on the page in front (Settings), not the screens behind it.
    final list = find.descendant(of: find.byType(Scaffold).last, matching: find.byType(Scrollable));
    await tester.scrollUntilVisible(target, 300, scrollable: list.first);
    await settle(tester, frames: 3);
  }

  /// A new user's onboarding, answered quickly.
  Future<void> onboard(WidgetTester tester, String name) async {
    await waitFor(tester, [find.text('Let’s go')], what: 'onboarding');
    await linger(tester);
    await tester.enterText(find.byType(TextField), name);
    await settle(tester, frames: 3);
    await next(tester, 'Let’s go');
    await tapText(tester, 'Yes, about the same each time');
    await tapText(tester, 'Every 2 weeks');
    await tester.enterText(find.byType(TextField), '2100');
    // The button turns from "Skip for now" into "Continue" on the next frames.
    await settle(tester, frames: 4);
    await next(tester, 'Continue');
    await tapText(tester, '60% · \$2,730');
    await next(tester, 'Continue');
    await tapText(tester, 'Build an emergency fund');
    await next(tester, 'Continue');
    await next(tester, 'Continue');
    await tapText(tester, 'Yes, I split some bills');
    await next(tester, 'Continue');
    await linger(tester);
    await next(tester, 'Start tracking');
    await settle(tester, frames: 12);
  }

  /// Taps "Continue with …" and waits for the person to finish the sheet.
  /// Returns once signed in, or once the "bring it back?" dialog is up.
  Future<Finder> signIn(WidgetTester tester) async {
    await tab(tester, 'People');
    final button = find.text('Continue with $_signIn');
    await waitFor(tester, [button], what: 'the sign-in buttons');
    await linger(tester, const Duration(seconds: 1));
    await tester.tap(button);
    action('Finish "Continue with $_signIn" on the phone.');
    return waitFor(
      tester,
      [
        find.text('Pick a username'),
        find.text('Bring your account back?'),
        find.text('Split with'),
      ],
      timeout: _signInTimeout,
      what: 'sign-in to finish',
    );
  }

  testWidgets('account: create, sign out and in, delete, restore', (tester) async {
    // Start signed out, as a new user would.
    final backend = await createBackend(SyncBackend.firebase);
    expect(backend.social, isNotNull, reason: 'Firebase must be configured for this test');
    await FirebaseAuth.instance.signOut();

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase(NativeDatabase.memory());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          databaseProvider.overrideWithValue(db),
          // Sync stays off: nothing from this run reaches the account's backup.
          remoteStoreProvider.overrideWithValue(null),
          socialBackendProvider.overrideWithValue(backend.social),
          accountDeletionProvider.overrideWithValue(backend.deletion),
        ],
        child: const ThreeBucksApp(),
      ),
    );

    // 1. Launch, onboarding, a first entry.
    await onboard(tester, 'Maya');
    await tester.tap(find.byTooltip('Add entry'));
    await settle(tester);
    await tester.enterText(find.byKey(RegionKeys.quickEntry), 'costco 46 split');
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(tester, frames: 4);
    // A new install has no history to guess the category from: pick one.
    await tester.tap(find.byType(ChoiceChip).first);
    await settle(tester, frames: 4);
    await linger(tester);
    await tester.tap(find.byKey(RegionKeys.saveButton));
    await settle(tester, frames: 8);
    expect(find.byKey(RegionKeys.saveButton), findsNothing, reason: 'the entry sheet closed');
    await linger(tester);

    // 2. Create an account: sign in, then pick a username.
    await signIn(tester);
    // An account left set to be deleted (say, by an earlier run) is asked
    // about a moment after sign-in: keep it.
    await linger(tester, const Duration(seconds: 3));
    if (find.text('Bring your account back?').evaluate().isNotEmpty) {
      await tapText(tester, 'Restore');
      await waitFor(tester, [find.text('Pick a username'), find.text('Split with')]);
    }
    if (find.text('Pick a username').evaluate().isNotEmpty) {
      final handle = 'review${DateTime.now().millisecondsSinceEpoch % 100000}';
      await tester.enterText(find.widgetWithText(TextField, 'Username'), handle);
      await settle(tester, frames: 4);
      await linger(tester);
      await tester.tap(find.textContaining('Continue as @'));
      await waitFor(tester, [find.text('Split with')], what: 'the People tab after the username');
    }
    await linger(tester);

    // 3. Log out, then log in again.
    await openSettings(tester);
    await scrollTo(tester, find.text('Sign out'));
    await linger(tester);
    await tapText(tester, 'Sign out');
    await settle(tester, frames: 6);
    await tester.pageBack();
    await settle(tester);
    await signIn(tester);
    await waitFor(tester, [find.text('Split with')], what: 'the People tab after signing in');
    await linger(tester);

    // 4. Delete the account: the page, a held press, the goodbye.
    await openSettings(tester);
    await scrollTo(tester, find.text('Delete account'));
    await linger(tester);
    await tapText(tester, 'Delete account');
    await waitFor(tester, [find.text('Delete your account')]);
    await linger(tester, const Duration(seconds: 3));
    final hold = await tester.startGesture(tester.getCenter(find.byType(HoldToConfirm)));
    await linger(tester, const Duration(milliseconds: 2400));
    await hold.up();
    await waitFor(
      tester,
      [find.text('Your account is set to go')],
      timeout: const Duration(seconds: 60),
      what: 'the goodbye page',
    );
    await linger(tester, const Duration(seconds: 6));
    expect(FirebaseAuth.instance.currentUser, isNull, reason: 'signed out after deleting');

    // 5. Start over and bring the account back, so the run leaves it as it was.
    await tapText(tester, 'Start over');
    await onboard(tester, 'Maya');
    await signIn(tester);
    await waitFor(
      tester,
      [find.text('Bring your account back?')],
      timeout: const Duration(seconds: 30),
      what: 'the offer to restore the account',
    );
    await linger(tester, const Duration(seconds: 3));
    await tapText(tester, 'Restore');
    // The restore goes to the server (a cold start can take a few seconds);
    // wait for it, not just for the People tab under the dialog.
    final container = ProviderScope.containerOf(tester.element(find.byType(ThreeBucksApp)));
    final end = DateTime.now().add(const Duration(seconds: 60));
    while (container.read(accountFlowProvider).status != AccountFlowStatus.idle &&
        DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(container.read(accountFlowProvider).status, AccountFlowStatus.idle, reason: 'restored');
    expect(container.read(accountFlowProvider).message, isNull);
    await waitFor(tester, [find.text('Split with')], what: 'the People tab, restored');
    await linger(tester, const Duration(seconds: 3));

    await tester.pumpWidget(const SizedBox());
    await settle(tester, frames: 4);
    await db.close();
  });
}
