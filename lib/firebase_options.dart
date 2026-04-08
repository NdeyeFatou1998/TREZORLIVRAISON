// Aligné sur android/app/google-services.json et ios/Runner/GoogleService-Info.plist (projet trezorandroid).
// Après un nouvel export Firebase, mettre à jour les constantes ou lancer : flutterfire configure
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
    apiKey: 'AIzaSyD9GTW2arCohP5IOAt9ZSovTRqrf9Zvhsc',
    appId: '1:848735335993:android:68e3cc25fd8ac1b515ffe8',
    messagingSenderId: '848735335993',
    projectId: 'trezorandroid',
    storageBucket: 'trezorandroid.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBcQq95mhR8VfvBh_rgL3XgzzN1QiEmRbY',
    appId: '1:848735335993:ios:3c8ac82f8850957515ffe8',
    messagingSenderId: '848735335993',
    projectId: 'trezorandroid',
    storageBucket: 'trezorandroid.firebasestorage.app',
    iosBundleId: 'com.iris.trezorlivraison',
  );
}
