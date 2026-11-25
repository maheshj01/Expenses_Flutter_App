import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:three_bucks/data/remote/firebase/firebase_remote_store.dart';

void main() {
  String describe(Object e) => FirebaseRemoteStore.describe(e);

  test('anonymous sign-in turned off reads as backup not set up', () {
    final e = FirebaseAuthException(
      code: 'admin-restricted-operation',
      message: 'This operation is restricted to administrators only.',
    );
    expect(describe(e), 'Backup isn’t set up for this app yet.');
  });

  test('Firestore and network errors read in plain words', () {
    FirebaseException firestore(String code) =>
        FirebaseException(plugin: 'cloud_firestore', code: code);
    expect(describe(firestore('unavailable')), 'Can’t reach the backup server.');
    expect(
      describe(FirebaseAuthException(code: 'network-request-failed')),
      'Can’t reach the backup server.',
    );
    expect(
      describe(firestore('permission-denied')),
      'Backup isn’t allowed for this account right now.',
    );
    expect(describe(firestore('resource-exhausted')), 'The backup server is busy.');
  });

  test('anything else never shows the raw error', () {
    expect(describe(StateError('boom')), 'Backup ran into a problem.');
    expect(describe(FirebaseAuthException(code: 'something-new')), 'Backup ran into a problem.');
  });
}
