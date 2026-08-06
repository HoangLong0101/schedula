import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failure.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/repositories/notification_repository.dart';
import '../datasources/notification_datasource.dart';

@LazySingleton(as: NotificationRepository)
class NotificationRepositoryImpl implements NotificationRepository {
  const NotificationRepositoryImpl(this._dataSource);

  final NotificationDataSource _dataSource;

  @override
  Stream<Either<Failure, List<AppNotification>>> watchNotifications({
    required String tenantId,
    required String userId,
    required bool staffOnly,
  }) {
    return _dataSource
        .watchNotifications(
          tenantId: tenantId,
          userId: userId,
          staffOnly: staffOnly,
        )
        .transform(
          StreamTransformer.fromHandlers(
            handleData: (items, sink) => sink.add(Right(items)),
            handleError: (_, _, sink) =>
                sink.add(const Left(ServerFailure('Không thể tải thông báo.'))),
          ),
        );
  }

  @override
  Future<Either<Failure, void>> markRead(String notificationId) async {
    try {
      await _dataSource.markRead(notificationId);
      return const Right(null);
    } catch (_) {
      return const Left(ServerFailure('Không thể cập nhật thông báo.'));
    }
  }

  @override
  Future<Either<Failure, void>> markAllRead({
    required String tenantId,
    required String userId,
    required bool staffOnly,
  }) async {
    try {
      await _dataSource.markAllRead(
        tenantId: tenantId,
        userId: userId,
        staffOnly: staffOnly,
      );
      return const Right(null);
    } catch (_) {
      return const Left(ServerFailure('Không thể cập nhật các thông báo.'));
    }
  }
}
