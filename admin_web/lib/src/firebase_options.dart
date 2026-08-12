import 'package:firebase_core/firebase_core.dart';

const _apiKey = String.fromEnvironment('FIREBASE_API_KEY');
const _appId = String.fromEnvironment('FIREBASE_APP_ID');
const _webAppId = String.fromEnvironment('FIREBASE_WEB_APP_ID');
const _authDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
const _messagingSenderId = String.fromEnvironment(
  'FIREBASE_MESSAGING_SENDER_ID',
);
const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
const _storageBucket = String.fromEnvironment('FIREBASE_STORAGE_BUCKET');

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    final missing = <String>[
      if (_apiKey.isEmpty) 'FIREBASE_API_KEY',
      if (_appId.isEmpty && _webAppId.isEmpty)
        'FIREBASE_WEB_APP_ID hoặc FIREBASE_APP_ID',
      if (_messagingSenderId.isEmpty) 'FIREBASE_MESSAGING_SENDER_ID',
      if (_projectId.isEmpty) 'FIREBASE_PROJECT_ID',
      if (_storageBucket.isEmpty) 'FIREBASE_STORAGE_BUCKET',
    ];
    if (missing.isNotEmpty) {
      throw StateError('Thiếu cấu hình Firebase: ${missing.join(', ')}.');
    }
    return FirebaseOptions(
      apiKey: _apiKey,
      appId: _webAppId.isEmpty ? _appId : _webAppId,
      messagingSenderId: _messagingSenderId,
      projectId: _projectId,
      authDomain: _authDomain.isEmpty
          ? '$_projectId.firebaseapp.com'
          : _authDomain,
      storageBucket: _storageBucket,
    );
  }

  static String get projectId => _projectId;
}
