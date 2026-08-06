import 'dart:async';
import 'dart:typed_data';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failure.dart';
import '../../domain/entities/business_info.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/entities/audit_event.dart';
import '../../domain/repositories/account_repository.dart';
import '../datasources/account_datasource.dart';

@LazySingleton(as: AccountRepository)
class AccountRepositoryImpl implements AccountRepository {
  const AccountRepositoryImpl(this._dataSource);

  final AccountDataSource _dataSource;

  @override
  Stream<Either<Failure, BusinessInfo>> watchBusinessInfo(String tenantId) {
    return _dataSource
        .watchBusinessInfo(tenantId)
        .transform(
          StreamTransformer.fromHandlers(
            handleData: (data, sink) => sink.add(Right(data)),
            handleError: (_, _, sink) => sink.add(
              const Left(ServerFailure('Không thể tải thông tin cơ sở.')),
            ),
          ),
        );
  }

  @override
  Future<Either<Failure, void>> updateBusinessInfo(
    String tenantId,
    BusinessInfo info,
  ) async {
    try {
      await _dataSource.updateBusinessInfo(tenantId, info);
      return const Right(null);
    } catch (_) {
      return const Left(ServerFailure('Không thể cập nhật thông tin cơ sở.'));
    }
  }

  @override
  Stream<Either<Failure, UserProfile>> watchUserProfile(
    String userId,
    String defaultEmail,
  ) {
    return _dataSource
        .watchUserProfile(userId, defaultEmail)
        .transform(
          StreamTransformer.fromHandlers(
            handleData: (profile, sink) => sink.add(Right(profile)),
            handleError: (_, _, sink) => sink.add(
              const Left(ServerFailure('Không thể tải hồ sơ tài khoản.')),
            ),
          ),
        );
  }

  @override
  Future<Either<Failure, void>> updateUserProfile(
    String userId,
    UserProfile profile,
  ) async {
    try {
      await _dataSource.updateUserProfile(userId, profile);
      return const Right(null);
    } catch (_) {
      return const Left(ServerFailure('Không thể cập nhật hồ sơ.'));
    }
  }

  @override
  Future<Either<Failure, String>> uploadAvatar(
    String userId,
    Uint8List bytes,
    String contentType,
  ) async {
    try {
      return Right(await _dataSource.uploadAvatar(userId, bytes, contentType));
    } catch (_) {
      return const Left(ServerFailure('Không thể tải ảnh đại diện.'));
    }
  }

  @override
  Future<Either<Failure, void>> changePassword(
    String email,
    String currentPassword,
    String newPassword,
  ) async {
    try {
      await _dataSource.changePassword(email, currentPassword, newPassword);
      return const Right(null);
    } catch (_) {
      return const Left(
        ValidationFailure('Mật khẩu hiện tại không đúng hoặc đã hết hạn.'),
      );
    }
  }

  @override
  Stream<Either<Failure, List<AuditEvent>>> watchAuditEvents(String tenantId) {
    return _dataSource
        .watchAuditEvents(tenantId)
        .transform(
          StreamTransformer.fromHandlers(
            handleData: (events, sink) => sink.add(Right(events)),
            handleError: (_, _, sink) => sink.add(
              const Left(ServerFailure('Không thể tải lịch sử hoạt động.')),
            ),
          ),
        );
  }

  @override
  Future<Either<Failure, List<CampaignRecipient>>>
  getEligibleCampaignRecipients(String tenantId) async {
    try {
      return Right(await _dataSource.getEligibleCampaignRecipients(tenantId));
    } catch (_) {
      return const Left(ServerFailure('Không thể tải danh sách khách hàng.'));
    }
  }

  @override
  Future<Either<Failure, Map<String, int>>> sendCampaign(
    String templateId,
    String subject,
    String body,
    List<String> recipientIds,
  ) async {
    try {
      return Right(
        await _dataSource.sendCampaign(templateId, subject, body, recipientIds),
      );
    } on FirebaseFunctionsException catch (error) {
      if (error.code == 'failed-precondition') {
        return const Left(
          ServerFailure(
            'Email chưa được cấu hình. Hãy thiết lập RESEND_API_KEY và '
            'REMINDER_MAIL_FROM trên Firebase Functions.',
          ),
        );
      }
      return Left(
        ServerFailure(error.message ?? 'Không thể gửi chiến dịch email.'),
      );
    } catch (_) {
      return const Left(ServerFailure('Không thể gửi chiến dịch email.'));
    }
  }

  @override
  Stream<Either<Failure, List<CampaignRecord>>> watchCampaigns(
    String tenantId,
  ) {
    return _dataSource
        .watchCampaigns(tenantId)
        .transform(
          StreamTransformer.fromHandlers(
            handleData: (campaigns, sink) => sink.add(Right(campaigns)),
            handleError: (_, _, sink) => sink.add(
              const Left(ServerFailure('Không thể tải lịch sử chiến dịch.')),
            ),
          ),
        );
  }

  @override
  Stream<Either<Failure, List<CampaignDelivery>>> watchCampaignDeliveries(
    String tenantId,
  ) {
    return _dataSource
        .watchCampaignDeliveries(tenantId)
        .transform(
          StreamTransformer.fromHandlers(
            handleData: (deliveries, sink) => sink.add(Right(deliveries)),
            handleError: (_, _, sink) => sink.add(
              const Left(ServerFailure('Không thể tải lịch sử gửi email.')),
            ),
          ),
        );
  }
}
