// File generated manually based on real values extracted from
// android/app/google-services.json — NOT run through `flutterfire configure`.
//
// Android-only by deliberate choice: no iOS GoogleService-Info.plist or web
// config has been provided, so those platforms throw a clear error instead
// of silently using wrong/missing values.
//
// If you later need iOS or web support, run, from the project root, with
// the Firebase CLI + FlutterFire CLI installed:
//
//   flutterfire configure
//
// That regenerates this file correctly for whichever platforms you select,
// pulling real config for each from your Firebase project (aquagas-68f33).
//
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions has not been configured for iOS — only '
          'Android values were generated (no GoogleService-Info.plist was '
          'provided). Run `flutterfire configure` and select iOS to add '
          'real support for this platform.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions is only configured for Android right now. '
          'Run `flutterfire configure` to add support for '
          '${defaultTargetPlatform.name}.',
        );
    }
  }

  // Values below are extracted directly from
  // android/app/google-services.json, the "com.example.vendorapp" client
  // entry — these are real, not placeholders.
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBdKIA_M74PJ-ipJHdV52WRnSDrp6QhSoM',
    appId: '1:308509074128:android:779a7ab35876d28256f4d5',
    messagingSenderId: '308509074128',
    projectId: 'aquagas-68f33',
    storageBucket: 'aquagas-68f33.firebasestorage.app',
    // databaseURL is only needed if you use Firebase Realtime Database.
    // Nothing in this app uses it (notifications are all MySQL via
    // Sequelize), so it's included for completeness but unused.
    databaseURL: 'https://aquagas-68f33-default-rtdb.firebaseio.com',
  );
}
