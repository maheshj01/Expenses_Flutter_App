import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../data/remote/firebase/firebase_remote_store.dart';
import '../data/remote/firebase/firebase_social_backend.dart';
import '../data/sync/remote_store.dart';
import '../domain/social/social_backend.dart';
import '../firebase_options.dart';

/// Which remote backend the app syncs with.
///
/// To add another backend (Supabase, your own API, ...):
/// 1. implement [RemoteStore] (personal sync) and [SocialBackend] (sharing)
///    in `lib/data/remote/<name>/`
/// 2. add a value here and a case in [createBackend].
/// Nothing else in the app needs to change.
enum SyncBackend {
  /// Keep everything on this device. Sharing is unavailable.
  none,
  firebase;

  /// Chosen at build time: `flutter run --dart-define=SYNC_BACKEND=none`.
  static SyncBackend get configured => switch (const String.fromEnvironment('SYNC_BACKEND')) {
    'none' => SyncBackend.none,
    _ => SyncBackend.firebase,
  };
}

/// The services a backend provides. Both are null in local-only mode.
class Backend {
  const Backend({this.remote, this.social});

  static const localOnly = Backend();

  final RemoteStore? remote;
  final SocialBackend? social;
}

/// Falls back to local-only mode when the backend is disabled or not set up.
Future<Backend> createBackend(SyncBackend backend) async {
  switch (backend) {
    case SyncBackend.none:
      return Backend.localOnly;
    case SyncBackend.firebase:
      try {
        if (Firebase.apps.isEmpty) {
          await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
        }
      } catch (e) {
        debugPrint('Firebase unavailable, running local-only: $e');
        return Backend.localOnly;
      }
      return Backend(remote: FirebaseRemoteStore.configure(), social: FirebaseSocialBackend());
  }
}
