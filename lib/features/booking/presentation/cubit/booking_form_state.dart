import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import '../../../catalog/domain/entities/service_item.dart';
import '../../../customer/domain/entities/customer.dart';
import '../../../staff/domain/entities/staff_member.dart';
import '../../domain/entities/booking.dart';
import '../../domain/entities/appointment_extraction.dart';

class BookingFormState extends Equatable {
  BookingFormState({
    this.customerLookup = '',
    this.customerId = '',
    this.customerName = '',
    this.staffId = '',
    this.staffName = '',
    this.serviceId = '',
    this.serviceName = '',
    this.serviceDuration = 60,
    this.services = const [],
    this.staff = const [],
    this.customers = const [],
    this.bookingsForDay = const [],
    this.customerBookings = const [],
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
  final String customerId;
  final String customerName;
  final String staffId;
  final String staffName;
  final String serviceId;
  final String serviceName;
  final int serviceDuration;
  final List<ServiceItem> services;
  final List<StaffMember> staff;
  final List<Customer> customers;
  final List<Booking> bookingsForDay;
  final List<Booking> customerBookings;
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
    String? customerId,
    String? customerName,
    String? staffId,
    String? staffName,
    String? serviceId,
    String? serviceName,
    int? serviceDuration,
    List<ServiceItem>? services,
    List<StaffMember>? staff,
    List<Customer>? customers,
    List<Booking>? bookingsForDay,
    List<Booking>? customerBookings,
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
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      staffId: staffId ?? this.staffId,
      staffName: staffName ?? this.staffName,
      serviceId: serviceId ?? this.serviceId,
      serviceName: serviceName ?? this.serviceName,
      serviceDuration: serviceDuration ?? this.serviceDuration,
      services: services ?? this.services,
      staff: staff ?? this.staff,
      customers: customers ?? this.customers,
      bookingsForDay: bookingsForDay ?? this.bookingsForDay,
      customerBookings: customerBookings ?? this.customerBookings,
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
    customerId,
    customerName,
    staffId,
    staffName,
    serviceId,
    serviceName,
    serviceDuration,
    services,
    staff,
    customers,
    bookingsForDay,
    customerBookings,
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
