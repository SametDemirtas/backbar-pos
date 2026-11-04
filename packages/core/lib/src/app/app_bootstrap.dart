import 'package:cloud_firestore/cloud_firestore.dart'
    show FirebaseFirestore, Settings, WebPersistentMultipleTabManager;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/pos_metrics.dart';
import '../theme/pos_palette.dart';
import '../theme/pos_type.dart';
import '../ui/pos_button.dart';
import '../ui/state_message.dart';

@immutable
class BootResult {
  const BootResult({required this.staffUid});

  final String staffUid;
}

class AppBootstrap extends StatefulWidget {
  const AppBootstrap({
    super.key,
    required this.productionOptions,
    required this.builder,
    this.useEmulator = emulatorRequested,
  });

  static const bool emulatorRequested = bool.fromEnvironment(
    'USE_FIREBASE_EMULATOR',
  );

  final FirebaseOptions Function() productionOptions;

  final bool useEmulator;

  final Widget Function(BuildContext context, BootResult boot) builder;

  static const FirebaseOptions emulatorOptions = FirebaseOptions(
    apiKey: 'emulator-does-not-check-this',
    appId: '1:000000000000:web:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'demo-backbar-pos',
  );

  static String get emulatorHost =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android
      ? '10.0.2.2'
      : '127.0.0.1';

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  static bool _emulatorsConnected = false;

  static bool _firestoreConfigured = false;

  late Future<BootResult> _boot = _start();

  Future<BootResult> _start() async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: widget.useEmulator
            ? AppBootstrap.emulatorOptions
            : widget.productionOptions(),
      );
    }

    if (kIsWeb && !_firestoreConfigured) {
      _firestoreConfigured = true;
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        webPersistentTabManager: WebPersistentMultipleTabManager(),
      );
    }

    if (widget.useEmulator && !_emulatorsConnected) {
      _emulatorsConnected = true;
      final host = AppBootstrap.emulatorHost;
      FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
      await FirebaseAuth.instance.useAuthEmulator(host, 9099);

      if (kIsWeb) {
        await FirebaseAuth.instance.setPersistence(Persistence.NONE);
      }
    }

    final auth = FirebaseAuth.instance;
    final restored = await auth.authStateChanges().first;
    final user = restored ?? (await auth.signInAnonymously()).user;
    if (user == null) {
      throw StateError('Signed in, but Firebase returned no user');
    }
    return BootResult(staffUid: user.uid);
  }

  void _retry() {
    setState(() => _boot = _start());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<BootResult>(
      future: _boot,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _BootFailure(error: snapshot.error!, onRetry: _retry);
        }
        if (!snapshot.hasData) {
          return const _BootSplash();
        }
        return widget.builder(context, snapshot.requireData);
      },
    );
  }
}

class _BootSplash extends StatelessWidget {
  const _BootSplash();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PosPalette.of(context).background,
      body: const StateLoading(),
    );
  }
}

class _BootFailure extends StatelessWidget {
  const _BootFailure({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = PosPalette.of(context);

    return Scaffold(
      backgroundColor: palette.background,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(PosSpace.x6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Cannot reach Firebase',
                  textAlign: TextAlign.center,
                  style: PosType.sheetTitle.copyWith(color: palette.emberInk),
                ),
                const SizedBox(height: PosSpace.x3),
                if (kDebugMode) ...[
                  Text(
                    '$error',
                    textAlign: TextAlign.center,
                    style: PosType.meta.copyWith(color: palette.textMuted),
                  ),
                  const SizedBox(height: PosSpace.x3),
                ],
                Text(
                  'Check that firebase_options.dart has been generated for this '
                  'app and that anonymous sign-in is enabled on the project.',
                  textAlign: TextAlign.center,
                  style: PosType.body.copyWith(color: palette.textSecondary),
                ),
                const SizedBox(height: PosSpace.x5),
                PosButton(
                  label: 'TRY AGAIN',
                  height: PosTouch.action,
                  onPressed: onRetry,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
