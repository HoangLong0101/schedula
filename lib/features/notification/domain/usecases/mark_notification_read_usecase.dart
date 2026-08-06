import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failure.dart';
import '../repositories/notification_repository.dart';

@injectable
class MarkNotificationReadUseCase {
  const MarkNotificationReadUseCase(this._repository);

  final NotificationRepository _repository;

  Future<Either<Failure, void>> call(String notificationId) {
    return _repository.markRead(notificationId);
  }
}
