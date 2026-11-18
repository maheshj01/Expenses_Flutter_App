# SpendWise

A simple, offline-first expense tracker built with Flutter.

- **Two-tap entry.** Type `costco 46 split` and the app fills in the amount, the split and the
  category it learned from your past notes.
- **Investing is not spending.** Every category is *spending*, *investing* or *income*, so months
  where you invest a lot don't look like overspending.
- **Split bills and money back.** Log the full bill and only your share counts. A roommate paying
  you back is logged as *money back*.
- **Safe to spend today.** The rest of your monthly living budget divided by the days left.
- **Every year, every month.** History shows each year's totals and a monthly chart. Tap any month
  to see its entries.
- **Your own categories.** Add, edit, recolour, archive and restore them.
- **Works offline.** Everything is stored on the device first and synced when online.

## Architecture

```
lib/
├── core/            # small helpers: ids, dates, clock
├── domain/          # pure Dart: entities, repository interfaces, money logic
│   ├── entities/
│   ├── repositories/   (CategoryRepository, EntryRepository, SettingsRepository)
│   └── services/       (PeriodSummary, BudgetPace, QuickEntryParser, CategorySuggester)
├── data/
│   ├── local/       # Drift (SQLite) database = source of truth
│   ├── sync/        # backend-agnostic sync engine + RemoteStore contract
│   └── remote/
│       └── firebase/   # Firestore implementation of RemoteStore
├── app/             # providers (DI), theme, shell, backend selection
├── features/        # home, entries, history, categories, settings
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

### Switching backends

A backend only has to implement [`RemoteStore`](lib/data/sync/remote_store.dart):

```dart
abstract interface class RemoteStore {
  String get displayName;
  Future<void> connect();
  Future<void> push(String collection, List<SyncRecord> records);
  Future<PullResult> pull(String collection, {String? cursor});
}
```

To add, say, Supabase or your own API:

1. Create `lib/data/remote/<name>/<name>_remote_store.dart` implementing `RemoteStore`.
2. Add a value to `SyncBackend` and a case in `createRemoteStore` in
   [`lib/app/backend.dart`](lib/app/backend.dart).

Nothing else changes: not the UI, the repositories or the local database. The sync tests in
`test/sync/` run against an in-memory `RemoteStore`, which is a good template.

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
4. Deploy the security rules in [`firestore.rules`](firestore.rules). They let each user read and
   write only `users/{their uid}/…`:
   ```bash
   firebase deploy --only firestore:rules
   ```

Data is stored at `users/{uid}/categories/{id}` and `users/{uid}/entries/{id}`. Firestore's own
offline cache is turned off because the local database already provides offline support.

> Anonymous sign-in keeps data private without a login screen, but it is tied to one install.
> To use several devices, add Google / Apple sign-in and link the anonymous account.

## Development

```bash
dart run build_runner build -d   # after changing Drift tables
flutter analyze
flutter test
```

Tests cover the money logic, the quick-entry parser, the local repositories, two-device sync
(conflicts, deletes, offline queueing, failures) and an end-to-end add / edit flow.

## Roadmap

- Import past years from the existing Excel sheet
- Google / Apple sign-in for multi-device sync
- Bank sync (Plaid / SimpleFIN) feeding a "to review" inbox
- Subscriptions view and price history from notes
