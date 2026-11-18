import 'dart:async';

import 'package:three_bucks/data/sync/connectivity_monitor.dart';

class FakeConnectivity implements ConnectivityMonitor {
  FakeConnectivity({this.online = true});

  bool online;
  final _controller = StreamController<bool>.broadcast();

  void set(bool value) {
    online = value;
    _controller.add(value);
  }

  @override
  Future<bool> isOnline() async => online;

  @override
  Stream<bool> get onlineChanges => _controller.stream;
}
