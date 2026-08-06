import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';
import '../entities/app_notification.dart';

abstract class NotificationRepository {
  Stream<Either<Failure, List<AppNotification>>> watchNotifications({
    required String tenantId,
    required String userId,
    required bool staffOnly,
  });

  Future<Either<Failure, void>> markRead(String notificationId);

  Future<Either<Failure, void>> markAllRead({
    required String tenantId,
    required String userId,
    required bool staffOnly,
  });
}
