// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  const DefaultFirebaseOptions._();

  static FirebaseOptions get currentPlatform {
    throw UnsupportedError(
      'This app has no Firebase project configured.\n'
      '\n'
      'Either run it against the local emulator, which needs no account:\n'
      '  firebase emulators:start\n'
      '  flutter run -d chrome --dart-define=USE_FIREBASE_EMULATOR=true\n'
      '\n'
      'Or point it at a project of your own:\n'
      '  cd apps/manager && flutterfire configure --out lib/firebase_options.dart',
    );
  }
}
