import 'package:equatable/equatable.dart';

enum ReportKind { bookings, payments, customers, campaigns, staff }

class ReportRecord extends Equatable {
  const ReportRecord({
    required this.id,
    required this.kind,
    required this.date,
    required this.title,
    this.subtitle = '',
    this.staffId = '',
    this.serviceId = '',
    this.status = '',
    this.paymentMethod = '',
    this.bookingId = '',
    this.amount = 0,
    this.reconciliationStatus = '',
  });

  final String id;
  final ReportKind kind;
  final DateTime date;
  final String title;
  final String subtitle;
  final String staffId;
  final String serviceId;
  final String status;
  final String paymentMethod;
  final String bookingId;
  final int amount;
  final String reconciliationStatus;

  @override
  List<Object> get props => [
    id,
    kind,
    date,
    title,
    subtitle,
    staffId,
    serviceId,
    status,
    paymentMethod,
    bookingId,
    amount,
    reconciliationStatus,
  ];
}
