import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/utils/string_utils.dart';
import '../../../catalog/domain/repositories/catalog_repository.dart';
import '../../../staff/domain/entities/staff_member.dart';
import '../../../staff/domain/usecases/watch_staff_usecase.dart';
import '../../domain/entities/appointment_extraction.dart';
import '../../domain/usecases/scan_appointment_image_usecase.dart';
import 'booking_form_state.dart';

class BookingFormCubit extends Cubit<BookingFormState> {
  BookingFormCubit(
    this._tenantId,
    this._scanAppointmentImage,
    this._watchStaff,
    this._catalogRepository,
  ) : super(BookingFormState());

  final String _tenantId;
  final ScanAppointmentImageUseCase _scanAppointmentImage;
  final WatchStaffUseCase _watchStaff;
  final CatalogRepository _catalogRepository;

  void updateCustomerLookup(String value) {
    emit(state.copyWith(customerLookup: value));
  }

  void updateCustomerName(String value) {
    emit(state.copyWith(customerName: value));
  }

  void updateStaffName(String value) {
    emit(state.copyWith(staffName: value));
  }

  void updateServiceName(String value) {
    emit(state.copyWith(serviceName: value));
  }

  void updateDate(DateTime value) {
    emit(state.copyWith(date: value));
  }

  void updateStartTime(TimeOfDay value) {
    emit(
      state.copyWith(
        startTime: value,
        endTime: _endTimeFor(value, state.endTime),
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

        emit(
          state.copyWith(
            aiScanning: false,
            extraction: extraction,
            customerName: extraction.customerName ?? state.customerName,
            customerLookup: extraction.phone ?? state.customerLookup,
            staffName: staffName ?? state.staffName,
            serviceName: serviceName ?? state.serviceName,
            date: extraction.appointmentDate ?? state.date,
            startTime: startTime,
            endTime: _endTimeFor(startTime, state.endTime),
          ),
        );
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

  /// Keeps the end time at least one hour after the start time.
  TimeOfDay _endTimeFor(TimeOfDay start, TimeOfDay currentEnd) {
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = currentEnd.hour * 60 + currentEnd.minute;
    if (endMinutes > startMinutes) {
      return currentEnd;
    }
    return TimeOfDay(
      hour: ((startMinutes + 60) ~/ 60) % 24,
      minute: (startMinutes + 60) % 60,
    );
  }
}
