// Firebase options loaded from compile-time defines so secrets stay out of git.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

const String _apiKey = String.fromEnvironment('FIREBASE_API_KEY');
const String _appId = String.fromEnvironment('FIREBASE_APP_ID');
const String _messagingSenderId =
    String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
const String _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
const String _storageBucket = String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
const String _androidClientId =
    String.fromEnvironment('FIREBASE_ANDROID_CLIENT_ID');
const String _iosClientId = String.fromEnvironment('FIREBASE_IOS_CLIENT_ID');
const String _iosBundleId = String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID');

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    _validate();

    if (kIsWeb) {
      throw UnsupportedError(
        'Firebase options are not configured for web. Use a local config file '
        'with --dart-define-from-file.',
      );
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return _options;
      case TargetPlatform.macOS:
        throw UnsupportedError('Firebase options are not configured for macOS.');
      case TargetPlatform.windows:
        throw UnsupportedError('Firebase options are not configured for Windows.');
      case TargetPlatform.linux:
        throw UnsupportedError('Firebase options are not configured for Linux.');
      default:
        throw UnsupportedError('Firebase options are not supported for this platform.');
    }
  }

  static FirebaseOptions get _options => FirebaseOptions(
        apiKey: _apiKey,
        appId: _appId,
        messagingSenderId: _messagingSenderId,
        projectId: _projectId,
        storageBucket: _storageBucket,
        androidClientId: _androidClientId,
        iosClientId: _iosClientId,
        iosBundleId: _iosBundleId,
      );
}

void _validate() {
  final missing = <String>[];
  if (_apiKey.isEmpty) missing.add('FIREBASE_API_KEY');
  if (_appId.isEmpty) missing.add('FIREBASE_APP_ID');
  if (_messagingSenderId.isEmpty) missing.add('FIREBASE_MESSAGING_SENDER_ID');
  if (_projectId.isEmpty) missing.add('FIREBASE_PROJECT_ID');
  if (_storageBucket.isEmpty) missing.add('FIREBASE_STORAGE_BUCKET');
  if (_androidClientId.isEmpty) missing.add('FIREBASE_ANDROID_CLIENT_ID');
  if (_iosClientId.isEmpty) missing.add('FIREBASE_IOS_CLIENT_ID');
  if (_iosBundleId.isEmpty) missing.add('FIREBASE_IOS_BUNDLE_ID');

  if (missing.isNotEmpty) {
    throw StateError(
      'Missing Firebase config values: ${missing.join(', ')}. '
      'Create a local config file and pass it with --dart-define-from-file.',
    );
  }
}