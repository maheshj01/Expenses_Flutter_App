import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/ids.dart';
import '../../../domain/social/push.dart';

/// [PushService] on Firebase Cloud Messaging.
///
/// Each device that wants notifications keeps
/// `users/{uid}/devices/{deviceId}`: `{fid, platform, updatedAt}`, where
/// `fid` is the app's Firebase Installation ID that FCM delivers to. The
/// `notifyConnection` and `notifyBill` functions read these to send
/// (`functions/src/notifications.ts`). The device id is made once per
/// install, so a new FID replaces the old one instead of adding a second
/// document.
class FirebasePushService implements PushService {
  FirebasePushService(this._prefs, {FirebaseMessaging? messaging, FirebaseFirestore? firestore})
    : _messaging = messaging ?? FirebaseMessaging.instance,
      _db = firestore ?? FirebaseFirestore.instance;

  final SharedPreferences _prefs;
  final FirebaseMessaging _messaging;
  final FirebaseFirestore _db;
  StreamSubscription<String>? _registered;

  static const _deviceIdKey = 'pushDeviceId';

  /// Calls that can hang offline give up after this; nothing waits on them.
  static const _patience = Duration(seconds: 5);

  String get _deviceId {
    final id = _prefs.getString(_deviceIdKey);
    if (id != null) return id;
    final made = newId();
    unawaited(_prefs.setString(_deviceIdKey, made));
    return made;
  }

  DocumentReference<Map<String, dynamic>> _device(String uid) =>
      _db.collection('users').doc(uid).collection('devices').doc(_deviceId);

  static PushPermission _permission(AuthorizationStatus status) => switch (status) {
    AuthorizationStatus.authorized || AuthorizationStatus.provisional => PushPermission.granted,
    AuthorizationStatus.denied || AuthorizationStatus.deniedPermanently => PushPermission.denied,
    AuthorizationStatus.notDetermined => PushPermission.notAsked,
  };

  @override
  Future<PushPermission> permission() async =>
      _permission((await _messaging.getNotificationSettings()).authorizationStatus);

  @override
  Future<PushPermission> requestPermission() async =>
      _permission((await _messaging.requestPermission()).authorizationStatus);

  @override
  Future<void> register(String uid) async {
    // The FID arrives on onRegistered once FCM has it (and again if it
    // changes), so listen before asking.
    await _registered?.cancel();
    _registered = _messaging.onRegistered.listen((fid) => unawaited(_save(uid, fid)));
    try {
      await _messaging.register();
    } catch (e) {
      debugPrint('Push register: $e');
    }
  }

  @override
  Future<void> unregister(String uid) async {
    await _registered?.cancel();
    _registered = null;
    try {
      await _device(uid).delete().timeout(_patience);
      await _messaging.unregister().timeout(_patience);
    } catch (e) {
      // Offline: the document goes when the write gets through, and the
      // server forgets an FID that FCM no longer knows the next time it
      // tries it.
      debugPrint('Push unregister: $e');
    }
  }

  Future<void> _save(String uid, String fid) async {
    try {
      await _device(uid).set({
        'fid': fid,
        'platform': defaultTargetPlatform.name,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      debugPrint('Push register: $e');
    }
  }

  static PushMessage? _message(RemoteMessage m) =>
      PushMessage.fromData(m.data, title: m.notification?.title, body: m.notification?.body);

  @override
  Stream<PushMessage> get received => FirebaseMessaging.onMessage.map(_message).whereType();

  @override
  Stream<PushMessage> get opened => FirebaseMessaging.onMessageOpenedApp.map(_message).whereType();

  @override
  Future<PushMessage?> launchMessage() async {
    final m = await _messaging.getInitialMessage();
    return m == null ? null : _message(m);
  }
}

extension<T> on Stream<T?> {
  Stream<S> whereType<S>() => where((e) => e is S).cast<S>();
}
