// Aligné sur android/app/google-services.json et ios/Runner/GoogleService-Info.plist (projet iristrezor).
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Firebase non configuré pour le web.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'Firebase non configuré pour cette plateforme.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCT79oxdeOC03Y6_1kKVBpE7VJuE8-Uzmk',
    appId: '1:732494716857:android:ca27b3a44e449c93ed2068',
    messagingSenderId: '732494716857',
    projectId: 'iristrezor',
    storageBucket: 'iristrezor.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBMr729v3URZSGkBJ5CL69asHdmA8HaKss',
    appId: '1:732494716857:ios:85d453fa2684e259ed2068',
    messagingSenderId: '732494716857',
    projectId: 'iristrezor',
    storageBucket: 'iristrezor.firebasestorage.app',
    iosBundleId: 'com.iris.trezorlivraison',
  );
}
