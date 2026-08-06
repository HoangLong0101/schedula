import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/app_notification.dart';

class AppNotificationModel extends AppNotification {
  const AppNotificationModel({
    required super.id,
    required super.type,
    required super.title,
    required super.message,
    required super.read,
    super.bookingId,
    super.sentAt,
  });

  factory AppNotificationModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};
    return AppNotificationModel(
      id: document.id,
      type: data['type'] as String? ?? '',
      title: data['title'] as String? ?? 'Thông báo',
      message: data['message'] as String? ?? '',
      read: data['read'] == true,
      bookingId: data['bookingId'] as String?,
      sentAt: (data['sentAt'] as Timestamp?)?.toDate(),
    );
  }
}
