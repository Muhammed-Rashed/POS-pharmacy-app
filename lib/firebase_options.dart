// File generated by FlutterFire CLI.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDZEhABEW7cE-krhx_E3LKijcKi7Jejpq4',
    appId: '1:563349392474:web:363fe305f3b9437507dc63',
    messagingSenderId: '563349392474',
    projectId: 'desktop-app-5839e',
    authDomain: 'desktop-app-5839e.firebaseapp.com',
    storageBucket: 'desktop-app-5839e.firebasestorage.app',
    measurementId: 'G-Z08EGGELKZ',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBjW0RP82btW3oAUSEyeHcGSsZ8BAcc_iw',
    appId: '1:563349392474:android:c5e9dcbdb27a630607dc63',
    messagingSenderId: '563349392474',
    projectId: 'desktop-app-5839e',
    storageBucket: 'desktop-app-5839e.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyA4iwnuYQ1L5Z7R3n1uBmr4Lhwq4aa8vdo',
    appId: '1:563349392474:ios:8e2ffa89628c04e307dc63',
    messagingSenderId: '563349392474',
    projectId: 'desktop-app-5839e',
    storageBucket: 'desktop-app-5839e.firebasestorage.app',
    iosBundleId: 'com.example.desktopApp',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyA4iwnuYQ1L5Z7R3n1uBmr4Lhwq4aa8vdo',
    appId: '1:563349392474:ios:8e2ffa89628c04e307dc63',
    messagingSenderId: '563349392474',
    projectId: 'desktop-app-5839e',
    storageBucket: 'desktop-app-5839e.firebasestorage.app',
    iosBundleId: 'com.example.desktopApp',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyDZEhABEW7cE-krhx_E3LKijcKi7Jejpq4',
    appId: '1:563349392474:web:b70a59cdf925a5a707dc63',
    messagingSenderId: '563349392474',
    projectId: 'desktop-app-5839e',
    authDomain: 'desktop-app-5839e.firebaseapp.com',
    storageBucket: 'desktop-app-5839e.firebasestorage.app',
    measurementId: 'G-1X2CV77H86',
  );
}
