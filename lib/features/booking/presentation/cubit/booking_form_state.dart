import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/appointment_extraction.dart';

class BookingFormState extends Equatable {
  BookingFormState({
    this.customerLookup = '',
    this.customerName = '',
    this.staffName = '',
    this.serviceName = '',
    DateTime? date,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    this.notes = '',
    this.aiMode = false,
    this.aiScanning = false,
    this.aiError,
    this.extraction,
  }) : date = date ?? DateTime.now(),
       startTime = startTime ?? const TimeOfDay(hour: 9, minute: 0),
       endTime = endTime ?? const TimeOfDay(hour: 10, minute: 0);

  final String customerLookup;
  final String customerName;
  final String staffName;
  final String serviceName;
  final DateTime date;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final String notes;
  final bool aiMode;
  final bool aiScanning;
  final String? aiError;
  final AppointmentExtraction? extraction;

  BookingFormState copyWith({
    String? customerLookup,
    String? customerName,
    String? staffName,
    String? serviceName,
    DateTime? date,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    String? notes,
    bool? aiMode,
    bool? aiScanning,
    String? aiError,
    bool clearAiError = false,
    AppointmentExtraction? extraction,
  }) {
    return BookingFormState(
      customerLookup: customerLookup ?? this.customerLookup,
      customerName: customerName ?? this.customerName,
      staffName: staffName ?? this.staffName,
      serviceName: serviceName ?? this.serviceName,
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      notes: notes ?? this.notes,
      aiMode: aiMode ?? this.aiMode,
      aiScanning: aiScanning ?? this.aiScanning,
      aiError: clearAiError ? null : (aiError ?? this.aiError),
      extraction: extraction ?? this.extraction,
    );
  }

  bool get isValid {
    return customerName.trim().isNotEmpty &&
        staffName.trim().isNotEmpty &&
        serviceName.trim().isNotEmpty &&
        endDateTime.isAfter(startDateTime);
  }

  DateTime get startDateTime {
    return DateTime(
      date.year,
      date.month,
      date.day,
      startTime.hour,
      startTime.minute,
    );
  }

  DateTime get endDateTime {
    return DateTime(
      date.year,
      date.month,
      date.day,
      endTime.hour,
      endTime.minute,
    );
  }

  @override
  List<Object?> get props => [
    customerLookup,
    customerName,
    staffName,
    serviceName,
    date,
    startTime,
    endTime,
    notes,
    aiMode,
    aiScanning,
    aiError,
    extraction,
  ];
}
