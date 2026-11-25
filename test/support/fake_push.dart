import 'dart:async';

import 'package:three_bucks/domain/social/push.dart';

/// A [PushService] that records what the app asked for and lets a test
/// deliver or tap notifications.
class FakePush implements PushService {
  FakePush({this.status = PushPermission.notAsked, this.answer = PushPermission.granted});

  /// What the phone reports now.
  PushPermission status;

  /// What the system prompt will answer.
  PushPermission answer;

  int prompts = 0;

  /// The uid each register / unregister call was for, in order.
  final calls = <String>[];

  /// Uids this device is currently registered for.
  final registered = <String>{};

  PushMessage? launch;
  final _received = StreamController<PushMessage>.broadcast();
  final _opened = StreamController<PushMessage>.broadcast();

  void deliver(PushMessage m) => _received.add(m);

  void tap(PushMessage m) => _opened.add(m);

  @override
  Future<PushPermission> permission() async => status;

  @override
  Future<PushPermission> requestPermission() async {
    if (status != PushPermission.notAsked) return status;
    prompts++;
    return status = answer;
  }

  @override
  Future<void> register(String uid) async {
    calls.add('register $uid');
    registered.add(uid);
  }

  @override
  Future<void> unregister(String uid) async {
    calls.add('unregister $uid');
    registered.remove(uid);
  }

  @override
  Stream<PushMessage> get received => _received.stream;

  @override
  Stream<PushMessage> get opened => _opened.stream;

  @override
  Future<PushMessage?> launchMessage() async => launch;
}
