import 'package:firebase_core/firebase_core.dart' show FirebaseException;

import '../models/order.dart' show CheckTooLarge;

String describeFailure(Object error) {
  if (error is CheckTooLarge) {
    return 'This check is too big to send as one order. Send part of it '
        'first, then the rest.';
  }
  if (error is FirebaseException) {
    return switch (error.code) {
      'permission-denied' =>
        'This device is not allowed to do that. Check it is set up for this '
            'venue.',
      'unauthenticated' => 'This device is not signed in. Restart the app.',
      'unavailable' || 'deadline-exceeded' =>
        'Cannot reach the server. Check the connection and try again.',
      'not-found' => 'That item no longer exists. Someone may have deleted it.',
      _ => 'Something went wrong (${error.code}). Try again.',
    };
  }
  return 'Something went wrong. Try again.';
}
