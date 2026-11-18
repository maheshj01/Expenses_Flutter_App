import '../data/remote/firebase/firebase_remote_store.dart';
import '../data/sync/remote_store.dart';

/// Which remote backend the app syncs with.
///
/// To add another backend (Supabase, your own API, ...):
/// 1. implement [RemoteStore] in `lib/data/remote/<name>/`
/// 2. add a value here and a case in [createRemoteStore].
/// Nothing else in the app needs to change.
enum SyncBackend {
  /// Keep everything on this device.
  none,
  firebase;

  /// Chosen at build time: `flutter run --dart-define=SYNC_BACKEND=none`.
  static SyncBackend get configured => switch (const String.fromEnvironment('SYNC_BACKEND')) {
    'none' => SyncBackend.none,
    _ => SyncBackend.firebase,
  };
}

/// Returns null when the backend is disabled or not set up, in which case
/// the app runs in local-only mode.
Future<RemoteStore?> createRemoteStore(SyncBackend backend) async {
  return switch (backend) {
    SyncBackend.none => null,
    SyncBackend.firebase => FirebaseRemoteStore.initialize(),
  };
}
