import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failure.dart';
import '../repositories/notification_repository.dart';

@injectable
class MarkAllNotificationsReadUseCase {
  const MarkAllNotificationsReadUseCase(this._repository);

  final NotificationRepository _repository;

  Future<Either<Failure, void>> call({
    required String tenantId,
    required String userId,
    required bool staffOnly,
  }) {
    return _repository.markAllRead(
      tenantId: tenantId,
      userId: userId,
      staffOnly: staffOnly,
    );
  }
}
