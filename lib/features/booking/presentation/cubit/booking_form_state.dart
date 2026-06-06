import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

class BookingFormState extends Equatable {
  const BookingFormState({
    this.customerId = '',
    this.staffId = '',
    this.serviceId = '',
    this.date,
    this.startTime,
    this.endTime,
    this.notes = '',
  });

  final String customerId;
  final String staffId;
  final String serviceId;
  final DateTime? date;
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;
  final String notes;

  BookingFormState copyWith({
    String? customerId,
    String? staffId,
    String? serviceId,
    DateTime? date,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    String? notes,
  }) {
    return BookingFormState(
      customerId: customerId ?? this.customerId,
      staffId: staffId ?? this.staffId,
      serviceId: serviceId ?? this.serviceId,
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      notes: notes ?? this.notes,
    );
  }

  bool get isValid {
    return customerId.isNotEmpty &&
        staffId.isNotEmpty &&
        serviceId.isNotEmpty &&
        date != null &&
        startTime != null &&
        endTime != null;
  }

  DateTime? get startDateTime {
    if (date == null || startTime == null) return null;
    return DateTime(
      date!.year,
      date!.month,
      date!.day,
      startTime!.hour,
      startTime!.minute,
    );
  }

  DateTime? get endDateTime {
    if (date == null || endTime == null) return null;
    return DateTime(
      date!.year,
      date!.month,
      date!.day,
      endTime!.hour,
      endTime!.minute,
    );
  }

  @override
  List<Object?> get props => [
        customerId,
        staffId,
        serviceId,
        date,
        startTime,
        endTime,
        notes,
      ];
}
