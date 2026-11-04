import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter_test/flutter_test.dart';
import 'package:backbar_pos_core/backbar_pos_core.dart';

FirebaseException firestore(String code) =>
    FirebaseException(plugin: 'cloud_firestore', code: code);

void main() {
  test('names what to do, not the database error', () {
    expect(
      describeFailure(firestore('permission-denied')),
      contains('not allowed'),
    );
    expect(describeFailure(firestore('unavailable')), contains('connection'));
    expect(
      describeFailure(firestore('deadline-exceeded')),
      contains('connection'),
    );
    expect(describeFailure(firestore('not-found')), contains('no longer'));
    expect(
      describeFailure(firestore('unauthenticated')),
      contains('signed in'),
    );
  });

  test('never shows the raw message', () {
    final error = FirebaseException(
      plugin: 'cloud_firestore',
      code: 'permission-denied',
      message: 'Missing or insufficient permissions on venues/copper-kettle',
    );
    expect(describeFailure(error), isNot(contains('venues/')));
  });

  test('keeps an unfamiliar code so it can be reported', () {
    expect(describeFailure(firestore('aborted')), contains('aborted'));
  });

  test('anything else is a plain apology', () {
    expect(
      describeFailure(StateError('boom')),
      'Something went wrong. Try again.',
    );
  });
}
