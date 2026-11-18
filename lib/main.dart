import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'app/backend.dart';
import 'app/providers.dart';
import 'app/shell.dart';
import 'app/social_providers.dart';
import 'data/local/app_database.dart';
import 'features/people/people_widgets.dart';

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
      child: const _SyncBootstrap(child: _InviteLinks(child: ThreeBucksApp())),
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

/// Opens the People tab with the "add" sheet when an invite link
/// (`threebucks://add/<username>`) opens the app.
class _InviteLinks extends ConsumerStatefulWidget {
  const _InviteLinks({required this.child});

  final Widget child;

  @override
  ConsumerState<_InviteLinks> createState() => _InviteLinksState();
}

class _InviteLinksState extends ConsumerState<_InviteLinks> {
  StreamSubscription<Uri>? _links;

  @override
  void initState() {
    super.initState();
    try {
      _links = AppLinks().uriLinkStream.listen(_open);
    } catch (e) {
      debugPrint('Invite links unavailable: $e');
    }
  }

  void _open(Uri uri) {
    final handle = handleFromLink(uri);
    if (handle == null) return;
    ref.read(shellTabProvider.notifier).select(peopleTabIndex);
    ref.read(pendingInviteProvider.notifier).set(handle);
  }

  @override
  void dispose() {
    _links?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
