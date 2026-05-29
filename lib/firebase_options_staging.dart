// Placeholder Firebase options for the staging flavor.
// Replace these values with the generated output from FlutterFire CLI after
// creating the schedula-staging Firebase project.

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Staging Firebase options are not configured for web.');
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return const FirebaseOptions(
          apiKey: 'REPLACE_ME',
          appId: 'REPLACE_ME',
          messagingSenderId: 'REPLACE_ME',
          projectId: 'REPLACE_ME',
        );
      case TargetPlatform.iOS:
        return const FirebaseOptions(
          apiKey: 'REPLACE_ME',
          appId: 'REPLACE_ME',
          messagingSenderId: 'REPLACE_ME',
          projectId: 'REPLACE_ME',
          iosBundleId: 'REPLACE_ME',
        );
      default:
        throw UnsupportedError('Staging Firebase options are not configured for this platform.');
    }
  }
}