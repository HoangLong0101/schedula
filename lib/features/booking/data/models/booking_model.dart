import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/booking.dart';
import '../../domain/entities/booking_status.dart';

class BookingModel extends Booking {
  const BookingModel({
    required super.id,
    required super.tenantId,
    required super.staffId,
    required super.customerId,
    required super.serviceId,
    required super.startTime,
    required super.endTime,
    required super.status,
    super.notes,
    super.createdBy,
    super.createdAt,
    super.updatedAt,
    super.reminder24Sent,
    super.reminder1hSent,
    super.customerName,
    super.staffName,
    super.serviceName,
    super.paymentStatus,
    super.paymentId,
    super.paymentAmount,
    super.paymentOrderCode,
    super.paymentCheckoutUrl,
    super.paymentPaidAt,
  });

  factory BookingModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return BookingModel(
      id: doc.id,
      tenantId: data['tenantId'] as String? ?? '',
      staffId: data['staffId'] as String? ?? '',
      customerId: data['customerId'] as String? ?? '',
      serviceId: data['serviceId'] as String? ?? '',
      startTime:
          (data['startTime'] as Timestamp?)?.toDate() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      endTime:
          (data['endTime'] as Timestamp?)?.toDate() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      status: bookingStatusFromString(data['status'] as String? ?? 'pending'),
      notes: data['notes'] as String?,
      createdBy: data['createdBy'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      reminder24Sent: data['reminder24Sent'] as bool?,
      reminder1hSent: data['reminder1hSent'] as bool?,
      customerName: data['customerName'] as String?,
      staffName: data['staffName'] as String?,
      serviceName: data['serviceName'] as String?,
      paymentStatus: data['paymentStatus'] as String?,
      paymentId: data['paymentId'] as String?,
      paymentAmount: (data['paymentAmount'] as num?)?.round(),
      paymentOrderCode: data['paymentOrderCode'] as int?,
      paymentCheckoutUrl: data['paymentCheckoutUrl'] as String?,
      paymentPaidAt: (data['paymentPaidAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => <String, dynamic>{
    'tenantId': tenantId,
    'staffId': staffId,
    'customerId': customerId,
    'serviceId': serviceId,
    'startTime': Timestamp.fromDate(startTime),
    'endTime': Timestamp.fromDate(endTime),
    'status': status.value,
    if (notes != null) 'notes': notes,
    if (createdBy != null) 'createdBy': createdBy,
    if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
    if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
    if (reminder24Sent != null) 'reminder24Sent': reminder24Sent,
    if (reminder1hSent != null) 'reminder1hSent': reminder1hSent,
    if (customerName != null) 'customerName': customerName,
    if (staffName != null) 'staffName': staffName,
    if (serviceName != null) 'serviceName': serviceName,
    if (paymentStatus != null) 'paymentStatus': paymentStatus,
    if (paymentId != null) 'paymentId': paymentId,
    if (paymentAmount != null) 'paymentAmount': paymentAmount,
    if (paymentOrderCode != null) 'paymentOrderCode': paymentOrderCode,
    if (paymentCheckoutUrl != null) 'paymentCheckoutUrl': paymentCheckoutUrl,
    if (paymentPaidAt != null)
      'paymentPaidAt': Timestamp.fromDate(paymentPaidAt!),
  };
}
