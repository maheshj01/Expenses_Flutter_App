import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/year_month.dart';
import '../data/local/app_database.dart';
import '../data/local/drift_category_repository.dart';
import '../data/local/drift_entry_repository.dart';
import '../data/local/prefs_settings_repository.dart';
import '../data/sync/connectivity_monitor.dart';
import '../data/sync/local_sync_source.dart';
import '../data/sync/remote_store.dart';
import '../data/sync/sync_engine.dart';
import '../data/sync/sync_status.dart';
import '../domain/entities/app_settings.dart';
import '../domain/entities/category.dart';
import '../domain/entities/ledger_entry.dart';
import '../domain/repositories/category_repository.dart';
import '../domain/repositories/entry_repository.dart';
import '../domain/repositories/settings_repository.dart';
import '../domain/services/period_summary.dart';
import '../domain/services/quick_entry_parser.dart';
import '../shared/money_format.dart';

// ---------------------------------------------------------------------------
// Infrastructure. Overridden in main() once async setup is done.
// ---------------------------------------------------------------------------

final databaseProvider = Provider<AppDatabase>((ref) => throw UnimplementedError('override'));

final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('override'),
);

/// The configured backend, or null for local-only mode.
final remoteStoreProvider = Provider<RemoteStore?>((ref) => null);

final connectivityProvider = Provider<ConnectivityMonitor>((ref) => PlusConnectivityMonitor());

final localChangesProvider = Provider<LocalChanges>((ref) {
  final changes = LocalChanges();
  ref.onDispose(changes.dispose);
  return changes;
});

final _driftCategories = Provider<DriftCategoryRepository>(
  (ref) => DriftCategoryRepository(ref.watch(databaseProvider), ref.watch(localChangesProvider)),
);

final _driftEntries = Provider<DriftEntryRepository>(
  (ref) => DriftEntryRepository(ref.watch(databaseProvider), ref.watch(localChangesProvider)),
);

// ---------------------------------------------------------------------------
// Repositories: the UI only sees the domain interfaces.
// ---------------------------------------------------------------------------

final categoryRepositoryProvider = Provider<CategoryRepository>(
  (ref) => ref.watch(_driftCategories),
);

final entryRepositoryProvider = Provider<EntryRepository>((ref) => ref.watch(_driftEntries));

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => PrefsSettingsRepository(ref.watch(sharedPreferencesProvider)),
);

// ---------------------------------------------------------------------------
// Sync
// ---------------------------------------------------------------------------

final syncEngineProvider = Provider<SyncEngine>((ref) {
  final engine = SyncEngine(
    remote: ref.watch(remoteStoreProvider),
    sources: [ref.watch(_driftCategories), ref.watch(_driftEntries)],
    cursors: ref.watch(databaseProvider),
    connectivity: ref.watch(connectivityProvider),
    changes: ref.watch(localChangesProvider),
  )..start();
  ref.onDispose(engine.dispose);
  return engine;
});

final syncStatusProvider = StreamProvider<SyncStatus>((ref) async* {
  final engine = ref.watch(syncEngineProvider);
  yield engine.status;
  yield* engine.statusChanges;
});

// ---------------------------------------------------------------------------
// Settings
// ---------------------------------------------------------------------------

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.watch(settingsRepositoryProvider).load();

  Future<void> update(AppSettings settings) async {
    state = settings;
    await ref.read(settingsRepositoryProvider).save(settings);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

final moneyFormatProvider = Provider<MoneyFormat>(
  (ref) => MoneyFormat(ref.watch(settingsProvider.select((s) => s.currencyCode))),
);

// ---------------------------------------------------------------------------
// Data for screens
// ---------------------------------------------------------------------------

/// All categories, archived ones included so old entries keep their names.
final categoriesProvider = StreamProvider<List<Category>>(
  (ref) => ref.watch(categoryRepositoryProvider).watchAll(includeArchived: true),
);

final activeCategoriesProvider = Provider<List<Category>>(
  (ref) => [...?ref.watch(categoriesProvider).value?.where((c) => !c.archived)],
);

final categoryMapProvider = Provider<Map<String, Category>>(
  (ref) => {for (final c in ref.watch(categoriesProvider).value ?? const <Category>[]) c.id: c},
);

final monthEntriesProvider = StreamProvider.family<List<LedgerEntry>, YearMonth>(
  (ref, month) => ref.watch(entryRepositoryProvider).watchBetween(month.firstDay, month.lastDay),
);

final yearEntriesProvider = StreamProvider.family<List<LedgerEntry>, int>(
  (ref, year) =>
      ref.watch(entryRepositoryProvider).watchBetween(DateTime(year), DateTime(year, 12, 31)),
);

final monthSummaryProvider = Provider.family<PeriodSummary, YearMonth>((ref, month) {
  final entries = ref.watch(monthEntriesProvider(month)).value ?? const [];
  return PeriodSummary.of(entries, ref.watch(categoryMapProvider));
});

final yearSummaryProvider = Provider.family<PeriodSummary, int>((ref, year) {
  final entries = ref.watch(yearEntriesProvider(year)).value ?? const [];
  return PeriodSummary.of(entries, ref.watch(categoryMapProvider));
});

/// Years with data, always including the current one, newest first.
final yearsProvider = Provider<List<int>>((ref) {
  final years = {DateTime.now().year, ...?ref.watch(_yearsStream).value};
  return years.toList()..sort((a, b) => b.compareTo(a));
});

final _yearsStream = StreamProvider<List<int>>(
  (ref) => ref.watch(entryRepositoryProvider).watchYears(),
);

/// Learns note -> category from recent history for quick entry.
final categorySuggesterProvider = FutureProvider.autoDispose<CategorySuggester>(
  (ref) async => CategorySuggester(await ref.watch(entryRepositoryProvider).recent()),
);

/// Selected bottom navigation tab.
class ShellTabNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void select(int index) => state = index;
}

final shellTabProvider = NotifierProvider<ShellTabNotifier, int>(ShellTabNotifier.new);
