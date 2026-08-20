import 'package:equatable/equatable.dart';

class AuditEvent extends Equatable {
  const AuditEvent({
    required this.id,
    required this.actorId,
    required this.entityType,
    required this.entityId,
    required this.action,
    required this.createdAt,
    this.status = 'succeeded',
    this.before,
    this.after,
  });

  final String id;
  final String actorId;
  final String entityType;
  final String entityId;
  final String action;
  final DateTime createdAt;
  final String status;
  final Map<String, dynamic>? before;
  final Map<String, dynamic>? after;

  @override
  List<Object?> get props => [
    id,
    actorId,
    entityType,
    entityId,
    action,
    createdAt,
    status,
    before,
    after,
  ];
}

class CampaignRecipient extends Equatable {
  const CampaignRecipient({
    required this.id,
    required this.name,
    required this.email,
    required this.reason,
  });

  final String id;
  final String name;
  final String email;
  final String reason;

  @override
  List<Object> get props => [id, name, email, reason];
}

class CampaignDelivery extends Equatable {
  const CampaignDelivery({
    required this.id,
    required this.campaignId,
    required this.email,
    required this.status,
    required this.createdAt,
    this.customerId = '',
    this.reason = '',
  });

  final String id;
  final String campaignId;
  final String customerId;
  final String email;
  final String status;
  final String reason;
  final DateTime createdAt;

  @override
  List<Object> get props => [
    id,
    campaignId,
    customerId,
    email,
    status,
    reason,
    createdAt,
  ];
}

class CampaignRecord extends Equatable {
  const CampaignRecord({
    required this.id,
    required this.templateId,
    required this.subject,
    required this.body,
    required this.status,
    required this.recipientCount,
    required this.sent,
    required this.failed,
    required this.createdAt,
  });

  final String id;
  final String templateId;
  final String subject;
  final String body;
  final String status;
  final int recipientCount;
  final int sent;
  final int failed;
  final DateTime createdAt;

  @override
  List<Object> get props => [
    id,
    templateId,
    subject,
    body,
    status,
    recipientCount,
    sent,
    failed,
    createdAt,
  ];
}
