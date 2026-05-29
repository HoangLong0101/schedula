import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  // Keep this lightweight. Background work should be delegated to the app or Cloud Functions.
}

class NotificationService {
  NotificationService({
    FirebaseMessaging? messaging,
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _messaging = messaging ?? FirebaseMessaging.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseMessaging _messaging;
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  String? _currentToken;
  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<User?>? _authStateSubscription;

  Future<void> initialize() async {
    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    _currentToken = await _messaging.getToken();
    if (_currentToken != null) {
      await _saveToken(_currentToken!);
    }

    _tokenRefreshSubscription = _messaging.onTokenRefresh.listen((token) async {
      _currentToken = token;
      await _saveToken(token);
    });

    _authStateSubscription = _auth.authStateChanges().listen((user) async {
      if (user != null && _currentToken != null) {
        await _saveToken(_currentToken!);
      }
    });

    FirebaseMessaging.onMessage.listen((message) {
      // In-app presentation can be added here when the UI is ready.
    });
  }

  /// Cancels any active subscriptions. Call on app shutdown to avoid leaks.
  Future<void> dispose() async {
    await _tokenRefreshSubscription?.cancel();
    await _authStateSubscription?.cancel();
  }

  Future<void> _saveToken(String token) async {
    final user = _auth.currentUser;
    if (user == null) {
      return;
    }

    await _firestore.collection('users').doc(user.uid).set(
      {
        'fcmToken': token,
        'fcmUpdatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}