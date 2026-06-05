import 'package:equatable/equatable.dart';

import 'booking_status.dart';

class Booking extends Equatable {
  const Booking({
    required this.id,
    required this.tenantId,
    required this.staffId,
    required this.customerId,
    required this.serviceId,
    required this.startTime,
    required this.endTime,
    required this.status,
    this.notes,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
    this.reminder24Sent,
    this.reminder1hSent,
    this.customerName,
    this.staffName,
    this.serviceName,
  });

  final String id;
  final String tenantId;
  final String staffId;
  final String customerId;
  final String serviceId;
  final DateTime startTime;
  final DateTime endTime;
  final BookingStatus status;
  final String? notes;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool? reminder24Sent;
  final bool? reminder1hSent;

  // Denormalized fields for UI rendering before joins are wired.
  final String? customerName;
  final String? staffName;
  final String? serviceName;

  @override
  List<Object?> get props => [
        id,
        tenantId,
        staffId,
        customerId,
        serviceId,
        startTime,
        endTime,
        status,
        notes,
        createdBy,
        createdAt,
        updatedAt,
        reminder24Sent,
        reminder1hSent,
        customerName,
        staffName,
        serviceName,
      ];
}
