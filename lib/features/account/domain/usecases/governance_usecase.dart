import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';
import '../entities/audit_event.dart';
import '../repositories/account_repository.dart';

class GovernanceUseCase {
  const GovernanceUseCase(this._repository);

  final AccountRepository _repository;

  Stream<Either<Failure, List<AuditEvent>>> watchAudit(String tenantId) =>
      _repository.watchAuditEvents(tenantId);

  Future<Either<Failure, List<CampaignRecipient>>> eligibleRecipients(
    String tenantId,
  ) => _repository.getEligibleCampaignRecipients(tenantId);

  Future<Either<Failure, Map<String, int>>> sendCampaign({
    required String templateId,
    required String subject,
    required String body,
    required List<String> recipientIds,
  }) => _repository.sendCampaign(templateId, subject, body, recipientIds);

  Stream<Either<Failure, List<CampaignRecord>>> watchCampaigns(
    String tenantId,
  ) => _repository.watchCampaigns(tenantId);

  Stream<Either<Failure, List<CampaignDelivery>>> watchDeliveries(
    String tenantId,
  ) => _repository.watchCampaignDeliveries(tenantId);
}
