import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/utils/string_utils.dart';
import '../../../catalog/domain/entities/service_item.dart';
import '../../../catalog/domain/repositories/catalog_repository.dart';
import '../../../staff/domain/entities/staff_member.dart';
import '../../../staff/domain/usecases/watch_staff_usecase.dart';
import '../../domain/entities/appointment_extraction.dart';
import '../../domain/entities/booking.dart';
import '../../domain/entities/booking_status.dart';
import '../../domain/usecases/scan_appointment_image_usecase.dart';
import '../../domain/usecases/watch_bookings_usecase.dart';
import 'booking_form_state.dart';

class BookingFormCubit extends Cubit<BookingFormState> {
  BookingFormCubit(
    this._tenantId,
    this._scanAppointmentImage,
    this._watchStaff,
    this._watchBookings,
    this._catalogRepository,
  ) : super(BookingFormState()) {
    _watchOptions();
    _watchBookingsForSelectedDay();
  }

  final String _tenantId;
  final ScanAppointmentImageUseCase _scanAppointmentImage;
  final WatchStaffUseCase _watchStaff;
  final WatchBookingsUseCase _watchBookings;
  final CatalogRepository _catalogRepository;
  StreamSubscription<Either<Failure, List<StaffMember>>>? _staffSubscription;
  StreamSubscription<Either<Failure, List<ServiceItem>>>? _servicesSubscription;
  StreamSubscription<Either<Failure, List<Booking>>>? _bookingsSubscription;

  void updateCustomerLookup(String value) {
    emit(state.copyWith(customerLookup: value));
  }

  void updateCustomerName(String value) {
    emit(state.copyWith(customerName: value));
  }

  void updateStaffName(String value) {
    emit(state.copyWith(staffId: '', staffName: value));
  }

  void updateServiceName(String value) {
    emit(
      state.copyWith(
        serviceId: '',
        serviceName: value,
        staffId: '',
        staffName: '',
      ),
    );
  }

  void updateService(ServiceItem service) {
    emit(
      state.copyWith(
        serviceId: service.id,
        serviceName: service.name,
        serviceDuration: service.duration,
        staffId: '',
        staffName: '',
        endTime: _timeAfter(state.startTime, service.duration),
      ),
    );
  }

  void updateStaff(StaffMember staff) {
    emit(state.copyWith(staffId: staff.id, staffName: staff.name));
  }

  void updateDate(DateTime value) {
    emit(state.copyWith(date: value));
    _watchBookingsForSelectedDay();
  }

  void updateStartTime(TimeOfDay value) {
    emit(
      state.copyWith(
        startTime: value,
        endTime: _timeAfter(value, state.serviceDuration),
      ),
    );
  }

  void updateEndTime(TimeOfDay value) {
    emit(state.copyWith(endTime: value));
  }

  void updateNotes(String value) {
    emit(state.copyWith(notes: value));
  }

  void updateMode({required bool aiMode}) {
    emit(state.copyWith(aiMode: aiMode, clearAiError: true));
  }

  List<StaffRecommendation> staffRecommendations() {
    final service = _selectedService();
    final recommendations = [
      for (final member in state.staff)
        StaffRecommendation(
          staff: member,
          available: _isAvailable(member),
          serviceMatch: _matchesService(member, service),
          score: _score(member, service),
        ),
    ];

    recommendations.sort((a, b) {
      final available = _compareBool(b.available, a.available);
      if (available != 0) return available;

      final serviceMatch = _compareBool(b.serviceMatch, a.serviceMatch);
      if (serviceMatch != 0) return serviceMatch;

      final rating = b.staff.rating.compareTo(a.staff.rating);
      if (rating != 0) return rating;

      final appointments = a.staff.appointments.compareTo(b.staff.appointments);
      if (appointments != 0) return appointments;

      return a.staff.name.compareTo(b.staff.name);
    });

    return recommendations;
  }

  /// Sends the appointment photo to the Booking Cascade API and pre-fills
  /// the form with whatever fields were extracted. Staff and service are
  /// rarely extracted by the API, so when absent they are auto-assigned
  /// from the tenant's own staff list and service catalog.
  Future<void> scanImage(String imagePath) async {
    emit(state.copyWith(aiScanning: true, clearAiError: true));

    final result = await _scanAppointmentImage(imagePath);

    await result.fold(
      (failure) async =>
          emit(state.copyWith(aiScanning: false, aiError: failure.message)),
      (extraction) async {
        final time = extraction.appointmentTime;
        final startTime = time == null
            ? state.startTime
            : TimeOfDay(hour: time.hour, minute: time.minute);
        final serviceName = await _resolveServiceName(extraction);
        final staffName = await _resolveStaffName(extraction);
        final selectedService = _serviceByName(serviceName);
        final selectedStaff = _staffByName(staffName);
        final serviceDuration =
            selectedService?.duration ?? state.serviceDuration;

        emit(
          state.copyWith(
            aiScanning: false,
            extraction: extraction,
            customerName: extraction.customerName ?? state.customerName,
            customerLookup: extraction.phone ?? state.customerLookup,
            staffId: selectedStaff?.id ?? state.staffId,
            staffName: staffName ?? state.staffName,
            serviceId: selectedService?.id ?? state.serviceId,
            serviceName: serviceName ?? state.serviceName,
            serviceDuration: serviceDuration,
            date: extraction.appointmentDate ?? state.date,
            startTime: startTime,
            endTime: _timeAfter(startTime, serviceDuration),
          ),
        );
        _watchBookingsForSelectedDay();
      },
    );
  }

  /// Uses the API-extracted service when present; otherwise matches the
  /// scanned text against the tenant's service catalog (longest match wins,
  /// e.g. "massage toàn thân" over "massage").
  Future<String?> _resolveServiceName(AppointmentExtraction extraction) async {
    final fromExtraction = extraction.serviceName;
    if (fromExtraction != null) {
      return fromExtraction;
    }

    final haystack = _scannedText(extraction);
    if (haystack.isEmpty) {
      return null;
    }

    final services = await _firstValue(
      _catalogRepository.watchServices(_tenantId),
    );

    String? best;
    for (final service in services) {
      final needle = StringUtilsX.normalizeForSearch(service.name);
      if (needle.isNotEmpty &&
          haystack.contains(needle) &&
          (best == null || service.name.length > best.length)) {
        best = service.name;
      }
    }
    return best;
  }

  /// Uses the API-extracted staff when present; otherwise looks for a staff
  /// member mentioned in the scanned text, and finally falls back to the
  /// first staff member who is currently available.
  Future<String?> _resolveStaffName(AppointmentExtraction extraction) async {
    final fromExtraction = extraction.staffName;
    if (fromExtraction != null) {
      return fromExtraction;
    }

    final staff = await _firstValue(
      _watchStaff(WatchStaffParams(tenantId: _tenantId)),
    );
    if (staff.isEmpty) {
      return null;
    }

    final haystack = _scannedText(extraction);
    final customerName = StringUtilsX.normalizeForSearch(
      extraction.customerName ?? '',
    );

    for (final member in staff) {
      final needle = StringUtilsX.normalizeForSearch(member.name);
      // Skip names indistinguishable from the customer's own name.
      if (needle.isEmpty || needle == customerName) {
        continue;
      }
      if (haystack.contains(needle)) {
        return member.name;
      }
    }

    for (final member in staff) {
      if (member.status == StaffStatus.available) {
        return member.name;
      }
    }
    return null;
  }

  String _scannedText(AppointmentExtraction extraction) {
    return StringUtilsX.normalizeForSearch(
      '${extraction.sourceText ?? ''} ${extraction.ocrFullText ?? ''}',
    );
  }

  Future<List<T>> _firstValue<T>(
    Stream<Either<Failure, List<T>>> stream,
  ) async {
    try {
      final result = await stream.first.timeout(const Duration(seconds: 5));
      return result.fold((_) => <T>[], (items) => items);
    } catch (_) {
      return <T>[];
    }
  }

  void _watchOptions() {
    _servicesSubscription = _catalogRepository
        .watchServices(_tenantId)
        .listen((result) {
      result.fold(
        (_) {},
        (services) => emit(state.copyWith(services: services)),
      );
    });

    _staffSubscription = _watchStaff(WatchStaffParams(tenantId: _tenantId))
        .listen((result) {
      result.fold((_) {}, (staff) => emit(state.copyWith(staff: staff)));
    });
  }

  void _watchBookingsForSelectedDay() {
    final start = DateTime(state.date.year, state.date.month, state.date.day);
    final end = start.add(const Duration(days: 1));
    _bookingsSubscription?.cancel();
    _bookingsSubscription = _watchBookings(
      WatchBookingsParams(tenantId: _tenantId, startDate: start, endDate: end),
    ).listen((result) {
      result.fold(
        (_) {},
        (bookings) => emit(state.copyWith(bookingsForDay: bookings)),
      );
    });
  }

  ServiceItem? _selectedService() {
    for (final service in state.services) {
      if (service.id == state.serviceId || service.name == state.serviceName) {
        return service;
      }
    }
    return null;
  }

  ServiceItem? _serviceByName(String? name) {
    if (name == null || name.isEmpty) {
      return null;
    }
    final normalized = StringUtilsX.normalizeForSearch(name);
    for (final service in state.services) {
      if (StringUtilsX.normalizeForSearch(service.name) == normalized) {
        return service;
      }
    }
    return null;
  }

  StaffMember? _staffByName(String? name) {
    if (name == null || name.isEmpty) {
      return null;
    }
    final normalized = StringUtilsX.normalizeForSearch(name);
    for (final staff in state.staff) {
      if (StringUtilsX.normalizeForSearch(staff.name) == normalized) {
        return staff;
      }
    }
    return null;
  }

  bool _isAvailable(StaffMember staff) {
    if (staff.status == StaffStatus.absent) {
      return false;
    }
    if (!_worksAt(staff, state.startDateTime)) {
      return false;
    }

    return !state.bookingsForDay.any((booking) {
      if (booking.staffId != staff.id ||
          booking.status == BookingStatus.cancelled ||
          booking.status == BookingStatus.completed ||
          booking.status == BookingStatus.noShow) {
        return false;
      }
      return state.startDateTime.isBefore(booking.endTime) &&
          state.endDateTime.isAfter(booking.startTime);
    });
  }

  bool _worksAt(StaffMember staff, DateTime start) {
    final shift = staff.shift[_weekdayKey(start.weekday)] ?? ShiftValue.full;
    return switch (shift) {
      ShiftValue.full => true,
      ShiftValue.morning => start.hour < 12,
      ShiftValue.afternoon => start.hour >= 12,
      ShiftValue.off => false,
    };
  }

  bool _matchesService(StaffMember staff, ServiceItem? service) {
    if (service == null) {
      return false;
    }
    final serviceTerms = StringUtilsX.normalizeForSearch(
      '${service.name} ${service.category}',
    );
    final staffTerms = StringUtilsX.normalizeForSearch(
      '${staff.role} ${staff.specialties.join(' ')}',
    );
    return serviceTerms
        .split(' ')
        .where((term) => term.length >= 3)
        .any(staffTerms.contains);
  }

  double _score(StaffMember staff, ServiceItem? service) {
    return (_isAvailable(staff) ? 1000 : 0) +
        (_matchesService(staff, service) ? 100 : 0) +
        staff.rating * 10 -
        staff.appointments * 0.05;
  }

  int _compareBool(bool a, bool b) {
    if (a == b) return 0;
    return a ? 1 : -1;
  }

  TimeOfDay _timeAfter(TimeOfDay start, int minutes) {
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = startMinutes + minutes.clamp(15, 24 * 60).toInt();
    return TimeOfDay(hour: (endMinutes ~/ 60) % 24, minute: endMinutes % 60);
  }

  String _weekdayKey(int weekday) {
    return switch (weekday) {
      DateTime.monday => 'mon',
      DateTime.tuesday => 'tue',
      DateTime.wednesday => 'wed',
      DateTime.thursday => 'thu',
      DateTime.friday => 'fri',
      DateTime.saturday => 'sat',
      DateTime.sunday => 'sun',
      _ => 'mon',
    };
  }

  @override
  Future<void> close() {
    _staffSubscription?.cancel();
    _servicesSubscription?.cancel();
    _bookingsSubscription?.cancel();
    return super.close();
  }
}

class StaffRecommendation {
  const StaffRecommendation({
    required this.staff,
    required this.available,
    required this.serviceMatch,
    required this.score,
  });

  final StaffMember staff;
  final bool available;
  final bool serviceMatch;
  final double score;
}
