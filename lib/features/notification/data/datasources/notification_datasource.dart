import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';

import '../models/app_notification_model.dart';

@lazySingleton
class NotificationDataSource {
  const NotificationDataSource(this._firestore);

  final FirebaseFirestore _firestore;

  Query<Map<String, dynamic>> _query({
    required String tenantId,
    required String userId,
    required bool staffOnly,
  }) {
    var query = _firestore
        .collection('notifications')
        .where('tenantId', isEqualTo: tenantId);
    if (staffOnly) {
      query = query.where('recipientUserId', isEqualTo: userId);
    }
    return query.orderBy('sentAt', descending: true).limit(50);
  }

  Stream<List<AppNotificationModel>> watchNotifications({
    required String tenantId,
    required String userId,
    required bool staffOnly,
  }) {
    return _query(
      tenantId: tenantId,
      userId: userId,
      staffOnly: staffOnly,
    ).snapshots().map(
      (snapshot) => snapshot.docs
          .map(AppNotificationModel.fromFirestore)
          .toList(growable: false),
    );
  }

  Future<void> markRead(String notificationId) {
    return _firestore.collection('notifications').doc(notificationId).update({
      'read': true,
      'readAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markAllRead({
    required String tenantId,
    required String userId,
    required bool staffOnly,
  }) async {
    final snapshot = await _query(
      tenantId: tenantId,
      userId: userId,
      staffOnly: staffOnly,
    ).get();
    final unread = snapshot.docs
        .where((document) => document.data()['read'] != true)
        .toList(growable: false);
    if (unread.isEmpty) return;
    final batch = _firestore.batch();
    for (final document in unread) {
      batch.update(document.reference, {
        'read': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }
}
