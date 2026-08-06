import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../router/app_router.dart';
import '../../features/booking/presentation/pages/booking_page.dart';

@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  // Keep this lightweight. Background work should be delegated to the app or Cloud Functions.
}

class NotificationService {
  NotificationService({
    FirebaseMessaging? messaging,
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  }) : _messaging = messaging ?? FirebaseMessaging.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseMessaging _messaging;
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  String? _currentToken;
  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<User?>? _authStateSubscription;
  StreamSubscription<RemoteMessage>? _openedMessageSubscription;

  Future<void> initialize() async {
    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

    await _messaging.requestPermission(alert: true, badge: true, sound: true);
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

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

    FirebaseMessaging.onMessage.listen(_showForegroundMessage);
    _openedMessageSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      _openMessage,
    );
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _openMessage(initialMessage);
    }
  }

  /// Cancels any active subscriptions. Call on app shutdown to avoid leaks.
  Future<void> dispose() async {
    await _tokenRefreshSubscription?.cancel();
    await _authStateSubscription?.cancel();
    await _openedMessageSubscription?.cancel();
  }

  Future<void> _saveToken(String token) async {
    final user = _auth.currentUser;
    if (user == null) {
      return;
    }

    await _firestore.collection('users').doc(user.uid).set({
      'fcmToken': token,
      'fcmUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  void _showForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    final context = AppRouter.rootNavigatorKey.currentContext;
    final messenger = context == null
        ? null
        : ScaffoldMessenger.maybeOf(context);
    if (notification == null || messenger == null) {
      return;
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          [
            notification.title,
            notification.body,
          ].whereType<String>().where((value) => value.isNotEmpty).join('\n'),
        ),
        action: message.data['bookingId'] == null
            ? null
            : SnackBarAction(
                label: 'Mở',
                onPressed: () => _openMessage(message),
              ),
      ),
    );
  }

  void _openMessage(RemoteMessage message) {
    final bookingId = message.data['bookingId'];
    AppRouter.router.go(
      bookingId == null || bookingId.isEmpty
          ? BookingPage.routePath
          : '${BookingPage.routePath}?bookingId=$bookingId&action=view',
    );
  }
}
