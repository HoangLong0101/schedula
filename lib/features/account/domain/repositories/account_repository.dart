import 'dart:typed_data';

import 'package:dartz/dartz.dart';
import '../../../../core/errors/failure.dart';
import '../entities/business_info.dart';
import '../entities/user_profile.dart';
import '../entities/audit_event.dart';

abstract class AccountRepository {
  Stream<Either<Failure, BusinessInfo>> watchBusinessInfo(String tenantId);
  Future<Either<Failure, void>> updateBusinessInfo(
    String tenantId,
    BusinessInfo info,
  );
  Stream<Either<Failure, UserProfile>> watchUserProfile(
    String userId,
    String defaultEmail,
  );
  Future<Either<Failure, void>> updateUserProfile(
    String userId,
    UserProfile profile,
  );
  Future<Either<Failure, String>> uploadAvatar(
    String userId,
    Uint8List bytes,
    String contentType,
  );
  Future<Either<Failure, void>> changePassword(
    String email,
    String currentPassword,
    String newPassword,
  );
  Stream<Either<Failure, List<AuditEvent>>> watchAuditEvents(String tenantId);
  Future<Either<Failure, List<CampaignRecipient>>>
  getEligibleCampaignRecipients(String tenantId);
  Future<Either<Failure, Map<String, int>>> sendCampaign(
    String templateId,
    String subject,
    String body,
    List<String> recipientIds,
  );
  Stream<Either<Failure, List<CampaignRecord>>> watchCampaigns(String tenantId);
  Stream<Either<Failure, List<CampaignDelivery>>> watchCampaignDeliveries(
    String tenantId,
  );
}
