# Developing Three Bucks

How the app is built, how to set up its backend, and the tools that come with it. For what
the app does, see the [README](../README.md).

## Architecture

```
lib/
├── core/            # small helpers: ids, dates, clock
├── domain/          # pure Dart: entities, repository interfaces, money logic
│   ├── entities/
│   ├── repositories/   (CategoryRepository, EntryRepository, SettingsRepository)
│   ├── services/       (PeriodSummary, BudgetPace, QuickEntryParser, CategorySuggester)
│   └── social/         (accounts, connections, shared bills, balances, inbox, SocialBackend)
├── data/
│   ├── local/       # Drift (SQLite) database = source of truth
│   ├── sync/        # backend-agnostic sync engine + RemoteStore contract
│   ├── social/      # BillProjector: your share of shared bills in your own ledger
│   └── remote/
│       └── firebase/   # Firestore implementations of RemoteStore and SocialBackend
├── app/             # providers (DI), theme, shell, backend selection
├── features/        # home, entries, history, categories, people, onboarding, settings
└── shared/          # widgets and formatting used across features
```

The UI depends only on the interfaces in `domain/`. Riverpod providers in
[`lib/app/providers.dart`](../lib/app/providers.dart) decide which implementation is used.

The first-run setup and its income branches are described in
[docs/onboarding.md](onboarding.md).

### Offline first

```
 UI ──► Repository ──► local SQLite (Drift) ──► SyncEngine ──► RemoteStore (Firebase, …)
          reads and writes                       pull, then push
          always local                           when online
```

- Every read and write goes to the local database, so the app works the same with or without a
  network.
- Each synced row has `updatedAt`, `deleted` (tombstone) and `dirty` (not yet pushed).
- `SyncEngine` runs on start, a couple of seconds after local edits and when the network comes
  back. Each run **pulls** remote changes, then **pushes** pending local ones. Conflicts are
  resolved per record: the most recent edit wins.
- When offline, changes queue up in the database. Home and Settings show how many are pending.
- **Backup needs a signed-in account** (Apple or Google). Signed out, everything works but stays
  on the phone; signing in sends it all to the account. Signing out backs up anything pending,
  then clears the phone, so the next person starts fresh and your data comes back when you sign in.

### Splitting bills with people

Sharing is optional and separate from personal sync:

- **Account.** The same Apple or Google sign-in that turns on backup. Installs from before
  sign-in was required may hold an anonymous account; signing in links to it, so the uid and
  its old backup stay the same.
- **Username.** Unique, picked once. People are found by exact username only; there is no search.
- **Connections.** You can only split with people who accepted your request.
- **Bills.** The payer creates and edits a bill (equal split, optional people not on the app).
  Every member's app copies *their share* into their own ledger (`BillProjector`), so totals,
  budgets and history treat it like any other entry.
- **Flags.** A member can flag their own share. While flagged it counts for nothing: not in
  balances, not in their spending. Editing the bill clears all flags; the flagger can also
  withdraw.
- **Settling up** records a payment made outside the app. No money moves through Three Bucks.
- **Notifications.** A push when someone sends you a request, accepts yours, adds you to a
  bill, or edits a bill you're on (only from people you're connected with). Edits are batched:
  the notice goes out 5 minutes after the first edit and covers every change since, e.g. "Sam
  changed the amount and title of “Team dinner”. Your share is now $30.00." The People tab offers them once; Settings turns
  them off. The in-app inbox shows the same news, so nothing is lost without them.

### Switching backends

Personal sync goes through [`RemoteStore`](../lib/data/sync/remote_store.dart) and sharing through
[`SocialBackend`](../lib/domain/social/social_backend.dart). A backend implements both:

```dart
abstract interface class RemoteStore {
  String get displayName;
  Future<void> connect();
  Future<void> push(String collection, List<SyncRecord> records);
  Future<PullResult> pull(String collection, {String? cursor});
}
```

To add, say, Supabase or your own API:

1. Create `lib/data/remote/<name>/` with classes implementing `RemoteStore` and `SocialBackend`.
2. Add a value to `SyncBackend` and a case in `createBackend` in
   [`lib/app/backend.dart`](../lib/app/backend.dart).

Nothing else changes: not the UI, the repositories or the local database. The tests run against
in-memory versions of both (`test/support/`), which are good templates.

## Getting started

```bash
flutter pub get
flutter run
```

Without Firebase configured the app runs in **local-only** mode: everything works and nothing is
synced. You can also force it with `--dart-define=SYNC_BACKEND=none`.

### Set up Firebase sync

1. Create a Firebase project and install the CLI tools:
   ```bash
   dart pub global activate flutterfire_cli
   ```
2. From the project root, generate `lib/firebase_options.dart` (this replaces the placeholder):
   ```bash
   flutterfire configure
   ```
3. In the Firebase console, create a **Cloud Firestore** database and enable Apple and Google
   sign-in (see [Set up sign-in](#set-up-sign-in) below). Anonymous sign-in isn't used.
4. Deploy the security rules in [`firestore.rules`](../firestore.rules). Personal data is readable
   only by its owner; shared bills only by their members, and only the payer can edit one:
   ```bash
   firebase deploy --only firestore:rules
   ```

Personal data is stored at `users/{uid}/categories/{id}`, `users/{uid}/entries/{id}` and
`users/{uid}/entry_edits/{id}` (what each edit of an entry changed). Sharing uses `handles/`,
`profiles/`, `connections/`, `bills/` (with each bill's edit history in `bills/{id}/edits/`),
`settlements/`, `blocks/` and `reports/`. Pulls of personal data
always read from the server; Firestore's offline cache is on so sharing works offline too.

### Set up account deletion and the janitor

Deleting an account works like Epoch's and is done on the server
([`functions/src/accountDeletion.ts`](../functions/src/accountDeletion.ts)), so the grace period
can't be bent by a client:

- **Settings → Delete account** (or **Erase my data** without signing in) opens a page listing what
  goes, and asks you to *hold* the button. Signed in, the `requestAccountDeletion` function marks
  `users/{uid}.deletion` and the account is frozen for 30 days: the rules refuse writes to its
  backup, and nobody can look it up or ask to connect. Not signed in, there's no backup (an
  anonymous one left from older versions is erased at once).
  Either way the phone is cleared and a goodbye page leads back to onboarding.
- Signing in again within 30 days asks whether to restore it (`restoreAccount`). A phone still
  signed in to a frozen account shows a page with the days left, Restore, or Continue deleting.
- Emails go out when an account is paused and when it's restored, via Resend. The functions that
  make those changes send them; there's no Firestore trigger.

A nightly `janitor` function runs three chores in order, each on its own, so one failing never
stops the others:

1. `inactiveAccounts`: accounts unopened for two years. Anonymous ones are erased; signed-in ones
   are marked for deletion like a request (with a warning email), and opening the app cancels it.
2. `deletedAccounts`: accounts whose 30 days are up are deleted: the sign-in, profile, username,
   connections, blocks and everything under `users/{uid}`. Shared bills, settlements and reports
   stay.
3. `deletedRecords`: soft-deleted entries, categories and entry edits older than 90 days.

Two more functions send sharing notifications
([`functions/src/notifications.ts`](../functions/src/notifications.ts)): `notifyConnection` on
writes to `connections/{id}` (a new request, an accepted one) and `notifyBill` on writes to
`bills/{id}` (people newly added). An edit of a bill also queues an update notice: `notifyBill`
creates `billUpdates/{billId}` (the bill as it was before, server-only) in a transaction, only if
none is waiting, and schedules `sendBillUpdate` on Cloud Tasks 5 minutes later. More edits in
that time add nothing; `sendBillUpdate` takes the entry out, compares it with the bill now and
tells everyone still on it except the payer what changed (nothing, if the edits cancelled out).
Each phone that wants them keeps
`users/{uid}/devices/{deviceId}` with its FCM installation id (FID); devices FCM no longer knows
are forgotten when a send fails. What they say is in
[`functions/src/notices.ts`](../functions/src/notices.ts), tested in `functions/test/`.

There are six functions in all: the two callables, the janitor, the two notifiers and
`sendBillUpdate`. To keep
the bill near zero ([`functions/src/options.ts`](../functions/src/options.ts)), each runs in
`us-central1` (next to
Firestore) with 256 MiB, no warm instances and at most two instances (one for the janitor), and
container images are kept for a day. At Three Bucks' scale this stays inside the free tiers of
Cloud Functions, Cloud Scheduler (one job), Cloud Tasks (one queue), Secret Manager and Resend.

Functions need the **Blaze** (pay as you go) plan and a [Resend](https://resend.com) API key:

```bash
firebase functions:secrets:set RESEND_API_KEY
(cd functions && npm install && npm test)
firebase deploy --only firestore:rules,firestore:indexes,functions
```

### Set up notifications

1. **Apple:** in the Apple Developer account, create an APNs key (*Keys → + → Apple Push
   Notifications service*), then upload it in the Firebase console (*Project settings → Cloud
   Messaging → Apple app configuration*). `Runner.entitlements` already has `aps-environment`
   and `Info.plist` the `remote-notification` background mode; Xcode should show *Push
   Notifications* under *Signing & Capabilities*.
2. **Android:** nothing more. The status-bar icon is
   `android/app/src/main/res/drawable-*/ic_notification.png`
   (`python3 tool/generate_notification_icon.py`).
3. **Deploy the functions** (above). Until then the app registers devices but nothing is sent.
   The first deploy creates the `sendBillUpdate` Cloud Tasks queue. If edit notices never
   arrive and the logs show a permission error when queueing, give the functions' service
   account the *Cloud Tasks Enqueuer* role.

### Set up sign-in

1. **Firebase console → Authentication → Sign-in method:** enable **Apple** and **Google**.
2. **Apple (iOS):** in Xcode, *Runner → Signing & Capabilities → + Capability → Sign in with
   Apple*. This needs a paid Apple Developer team; a free Personal Team can't use it.
3. **Google (iOS):** nothing more. `Info.plist` already registers the Firebase encoded app id URL
   scheme the sign-in flow returns to.
4. **Google (Android):** add the app's SHA-1 and SHA-256 fingerprints in the Firebase console
   (*Project settings → Your apps*), then re-download `google-services.json`.

Invite links use the custom scheme `threebucks://add/<username>`, registered in `Info.plist` and
`AndroidManifest.xml`. Scanning the QR code with the phone's camera opens them.

## Development

```bash
dart run build_runner build -d   # after changing Drift tables
flutter analyze
flutter test
```

Tests cover the money logic, the quick-entry parser, the local repositories, two-device sync
(conflicts, deletes, offline queueing, failures, switching accounts), balances and the inbox, the
shared-bill ledger projection, edit history, account deletion, blocking and reporting, and
end-to-end add / edit, onboarding, sharing and settle-up flows.

### App icon

The icon (three fanned bills with a $) is drawn by a script, so every size comes from one
drawing. To change it, edit [`tool/generate_icons.py`](../tool/generate_icons.py) and run:

```bash
python3 tool/generate_icons.py   # needs Pillow; macOS for the SF Pro $
```

It writes the iOS and macOS icon sets, Android launcher icons (adaptive foreground, background
color and a monochrome layer for themed icons) and the store icons in `branding/`:
`app_store_icon_1024.png` (no alpha, as App Store Connect requires) and
`play_store_icon_512.png`.

Screenshots of onboarding, the main screens and sharing (on an in-memory backend):

```bash
make capture-screens DEVICE=<simulator-udid>
```

### Account flow on a real iPhone

The flow App Review asks to see, against the real Firebase project: launch, onboarding and a first
entry, then creating an account (sign-in and a username), signing out and in, deleting the account
(held button, goodbye page) and restoring it, so the account ends as it started:

```bash
flutter test integration_test/account_flow_test.dart -d <iphone-udid> --dart-define=SIGN_IN=Apple
```

Approve each Sign in with Apple sheet on the phone (three in all); the test taps everything else.
Use `SIGN_IN=Google` to pick a test Google account instead. Entries stay in memory and sync is off,
so nothing is added to the account's backup.

### Store screenshots

These targets capture the same flow straight into the storeshots projects (store screenshot
designs), ready to design with:

```bash
make store-shots-ios       # iPhone 17 Pro Max (1320×2868) -> store-assets/ios/
make store-shots-android   # a Pixel emulator              -> store-assets/android/
```

Each screen is written to `<project>/captures/<locale>/<name>.png` (no device frame), with
`<name>.json` beside it: a description, the feature, the theme, the size, the text on screen and
named `regions` (for example `entry-amount` or `import-summary`) in screenshot pixels. Names stay the
same between runs, so designs pick up new captures. The status bar is set to 9:41 with full
battery and signal, and restored afterwards. `LOCALE=de` writes to `captures/de/`. The iOS target
creates and boots the simulator if needed; the Android one uses a running emulator or starts the
first Pixel AVD. Nothing else in the project folders is touched.

## Roadmap

- Import past years from the existing Excel sheet
- Groups (a saved set of people), uneven splits, comments on bills
- Universal links (`https://…`) for invites
- Bank sync (Plaid / SimpleFIN) feeding a "to review" inbox
- Subscriptions view and price history from notes
