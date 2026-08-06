import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failure.dart';
import '../entities/app_notification.dart';
import '../repositories/notification_repository.dart';

@injectable
class WatchNotificationsUseCase {
  const WatchNotificationsUseCase(this._repository);

  final NotificationRepository _repository;

  Stream<Either<Failure, List<AppNotification>>> call({
    required String tenantId,
    required String userId,
    required bool staffOnly,
  }) {
    return _repository.watchNotifications(
      tenantId: tenantId,
      userId: userId,
      staffOnly: staffOnly,
    );
  }
}
