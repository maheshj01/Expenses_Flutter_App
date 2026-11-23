# Three Bucks

A simple, offline-first expense tracker built with Flutter.

- **Two-tap entry.** Type `costco 46 split` and the app fills in the amount, the split and the
  category it learned from your past notes.
- **Investing is not spending.** Every category is *spending*, *investing* or *income*, so months
  where you invest a lot don't look like overspending.
- **Split bills and money back.** Log the full bill and only your share counts. Name the people
  who aren't on the app once and they're offered next time (`pizza 30 split sam`). A roommate
  paying you back is logged as *money back*.
- **Split with people on the app.** Add friends by their exact username. A bill you split with them
  shows up in their app with their share; the People tab keeps a running balance, records
  settling up, and lets anyone flag a share that looks wrong.
- **Safe to spend today.** The rest of your monthly living budget divided by the days left.
- **Every year, every month.** History shows each year's totals and a monthly chart. Tap any month
  to see its entries.
- **Your own categories.** Add, edit, recolour, archive and restore them.
- **Works offline.** Everything is stored on the device first and synced when online.
- **Bring your spreadsheet.** Import .xlsx or .csv files: every tab with a Date and an Amount
  column is read, categories are matched by name, rows you already have are skipped, and the
  whole import can be undone. Importing the same file twice adds nothing.
- **Take it with you.** Export any year, or everything, as an .xlsx with every entry and a
  summary per year, and email it to yourself. Exports import back in unchanged.

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
[`lib/app/providers.dart`](lib/app/providers.dart) decide which implementation is used.

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

### Splitting bills with people

Sharing is optional and separate from personal sync:

- **Account.** You only sign in (Apple or Google) to share. Signing in links to the anonymous
  account, so the uid and everything already backed up stay the same.
- **Username.** Unique, picked once. People are found by exact username only; there is no search.
- **Connections.** You can only split with people who accepted your request.
- **Bills.** The payer creates and edits a bill (equal split, optional people not on the app).
  Every member's app copies *their share* into their own ledger (`BillProjector`), so totals,
  budgets and history treat it like any other entry.
- **Flags.** A member can flag their own share. While flagged it counts for nothing: not in
  balances, not in their spending. Editing the bill clears all flags; the flagger can also
  withdraw.
- **Settling up** records a payment made outside the app. No money moves through Three Bucks.

### Switching backends

Personal sync goes through [`RemoteStore`](lib/data/sync/remote_store.dart) and sharing through
[`SocialBackend`](lib/domain/social/social_backend.dart). A backend implements both:

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
   [`lib/app/backend.dart`](lib/app/backend.dart).

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
3. In the Firebase console, enable **Authentication → Sign-in method → Anonymous** and create a
   **Cloud Firestore** database.
4. Deploy the security rules in [`firestore.rules`](firestore.rules). Personal data is readable
   only by its owner; shared bills only by their members, and only the payer can edit one:
   ```bash
   firebase deploy --only firestore:rules
   ```

Personal data is stored at `users/{uid}/categories/{id}`, `users/{uid}/entries/{id}` and
`users/{uid}/entry_edits/{id}` (what each edit of an entry changed). Sharing uses `handles/`,
`profiles/`, `connections/`, `bills/` (with each bill's edit history in `bills/{id}/edits/`),
`settlements/`, `blocks/` and `reports/`. Pulls of personal data
always read from the server; Firestore's offline cache is on so sharing works offline too.

### Set up sign-in for sharing

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
shared-bill ledger projection, and end-to-end add / edit, onboarding and sharing flows.

### App icon

The icon (three fanned bills with a $) is drawn by a script, so every size comes from one
drawing. To change it, edit [`tool/generate_icons.py`](tool/generate_icons.py) and run:

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
- Universal links (`https://…`) for invites, push notifications
- Bank sync (Plaid / SimpleFIN) feeding a "to review" inbox
- Subscriptions view and price history from notes
