import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/social/push.dart';
import 'providers.dart';
import 'social_providers.dart';

/// Push notifications, or null where the phone can't get them (local-only
/// mode, desktop). Overridden in main().
final pushServiceProvider = Provider<PushService?>((ref) => null);

/// Whether this phone gets sharing notifications, and what can be done
/// about it.
@immutable
class NotificationsState {
  const NotificationsState({required this.available, this.permission, this.wanted});

  static const unavailable = NotificationsState(available: false);

  /// False in local-only mode and on desktop.
  final bool available;

  /// Null until the phone has been asked.
  final PushPermission? permission;

  /// What you chose in the app: null until you choose. Stored on this phone.
  final bool? wanted;

  /// Notifications arrive.
  bool get on => available && permission == PushPermission.granted && wanted != false;

  /// Worth offering: never chosen, and the phone hasn't been asked yet.
  bool get canOffer => available && wanted == null && permission == PushPermission.notAsked;

  /// Refused in the system prompt; only the phone's Settings can undo it.
  bool get blocked => available && permission == PushPermission.denied;

  NotificationsState copyWith({PushPermission? permission, bool? wanted}) => NotificationsState(
    available: available,
    permission: permission ?? this.permission,
    wanted: wanted ?? this.wanted,
  );
}

/// Keeps this phone registered for notifications while you're signed in
/// and want them. A phone that already allows notifications (Android before
/// 13, or a reinstall) gets them without asking, until turned off.
class NotificationsNotifier extends Notifier<NotificationsState> {
  static const _key = 'notifications';

  PushService? get _push => ref.read(pushServiceProvider);
  String? get _uid => ref.read(accountProvider).value?.uid;

  @override
  NotificationsState build() {
    final push = ref.watch(pushServiceProvider);
    // Registers again for whoever is signed in.
    ref.watch(accountProvider.select((a) => a.value?.uid));
    if (push == null) return NotificationsState.unavailable;
    unawaited(Future.microtask(refresh));
    return NotificationsState(
      available: true,
      wanted: ref.read(sharedPreferencesProvider).getBool(_key),
    );
  }

  /// Reads the phone's permission again (it may have changed in Settings)
  /// and registers this phone if notifications are on.
  Future<void> refresh() async {
    final push = _push;
    if (push == null) return;
    final permission = await push.permission();
    if (!ref.mounted) return;
    state = state.copyWith(permission: permission);
    await _sync();
  }

  Future<void> _sync() async {
    final uid = _uid;
    if (uid != null && state.on) await _push?.register(uid);
  }

  /// Asks the phone (once) and turns notifications on.
  Future<void> turnOn() async {
    final push = _push;
    if (push == null) return;
    await _remember(true);
    final permission = await push.requestPermission();
    if (!ref.mounted) return;
    state = state.copyWith(permission: permission, wanted: true);
    await _sync();
  }

  /// Turns them off for this phone.
  Future<void> turnOff() async {
    await _remember(false);
    state = state.copyWith(wanted: false);
    final uid = _uid;
    if (uid != null) await _push?.unregister(uid);
  }

  /// Hides the offer without asking the phone.
  Future<void> notNow() async {
    await _remember(false);
    state = state.copyWith(wanted: false);
  }

  /// Stops notifications for the signed-in account on this phone. Called
  /// before signing out, while the account can still write.
  Future<void> beforeSignOut() async {
    final uid = _uid;
    if (uid != null) await _push?.unregister(uid);
  }

  Future<void> _remember(bool wanted) => ref.read(sharedPreferencesProvider).setBool(_key, wanted);
}

final notificationsProvider = NotifierProvider<NotificationsNotifier, NotificationsState>(
  NotificationsNotifier.new,
);
