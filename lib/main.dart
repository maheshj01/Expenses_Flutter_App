import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'app/backend.dart';
import 'app/providers.dart';
import 'app/social_providers.dart';
import 'data/local/app_database.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final database = AppDatabase.open();
  // Local-only when Firebase is not configured.
  final backend = await createBackend(SyncBackend.configured);

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(database),
        remoteStoreProvider.overrideWithValue(backend.remote),
        socialBackendProvider.overrideWithValue(backend.social),
      ],
      child: const _SyncBootstrap(child: ThreeBucksApp()),
    ),
  );
}

/// Starts the sync engine as soon as the app is up.
class _SyncBootstrap extends ConsumerWidget {
  const _SyncBootstrap({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref
      ..watch(syncEngineProvider)
      ..watch(billProjectionProvider);
    return child;
  }
}
