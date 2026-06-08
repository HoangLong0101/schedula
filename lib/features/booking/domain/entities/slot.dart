import 'package:equatable/equatable.dart';

class Slot extends Equatable {
  const Slot({
    required this.id,
    required this.tenantId,
    required this.staffId,
    required this.date,
    required this.intervals,
  });

  final String id;
  final String tenantId;
  final String staffId;
  final DateTime date;
  final List<SlotInterval> intervals;

  @override
  List<Object?> get props => [
        id,
        tenantId,
        staffId,
        date,
        intervals,
      ];
}

class SlotInterval extends Equatable {
  const SlotInterval({
    required this.startTime,
    required this.endTime,
    this.bookingId,
  });

  final DateTime startTime;
  final DateTime endTime;
  final String? bookingId;

  @override
  List<Object?> get props => [
        startTime,
        endTime,
        bookingId,
      ];
}
