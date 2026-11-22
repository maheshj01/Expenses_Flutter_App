import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:three_bucks/data/remote/firebase/firebase_social_backend.dart';
import 'package:three_bucks/domain/social/account.dart';

void main() {
  test('iOS offers Apple and Google', () {
    expect(signInMethodsFor(TargetPlatform.iOS, isWeb: false), [SignInMethod.apple, SignInMethod.google]);
  });

  test('Android and other platforms offer Google only', () {
    for (final platform in [TargetPlatform.android, TargetPlatform.macOS, TargetPlatform.windows]) {
      expect(signInMethodsFor(platform, isWeb: false), [SignInMethod.google], reason: '$platform');
    }
  });

  test('the web offers Google only, even on an iPhone browser', () {
    expect(signInMethodsFor(TargetPlatform.iOS, isWeb: true), [SignInMethod.google]);
  });
}
