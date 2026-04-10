// Aligne sur android/app/google-services.json et ios/Runner/GoogleService-Info.plist.
// Apres un nouvel export Firebase, mettre a jour les constantes ou lancer: flutterfire configure.
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
    apiKey: 'AIzaSyDt2Vnc9qKS-gBpZETnk-gTYXKgKUdDL28',
    appId: '1:510412530643:android:929c81b3eded825930c526',
    messagingSenderId: '510412530643',
    projectId: 'iristrezorlivraison',
    storageBucket: 'iristrezorlivraison.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCFR5_Eb9vBmmhKmOvpPE0oepBI9eeoSdQ',
    appId: '1:510412530643:ios:9e0c4d255e2bd47730c526',
    messagingSenderId: '510412530643',
    projectId: 'iristrezorlivraison',
    storageBucket: 'iristrezorlivraison.firebasestorage.app',
    iosBundleId: 'com.iris.trezorlivraison',
  );
}
