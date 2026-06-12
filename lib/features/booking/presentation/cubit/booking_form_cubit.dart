import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/scan_appointment_image_usecase.dart';
import 'booking_form_state.dart';

class BookingFormCubit extends Cubit<BookingFormState> {
  BookingFormCubit(this._scanAppointmentImage) : super(BookingFormState());

  final ScanAppointmentImageUseCase _scanAppointmentImage;

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
  /// the form with whatever fields were extracted.
  Future<void> scanImage(String imagePath) async {
    emit(state.copyWith(aiScanning: true, clearAiError: true));

    final result = await _scanAppointmentImage(imagePath);

    result.fold(
      (failure) =>
          emit(state.copyWith(aiScanning: false, aiError: failure.message)),
      (extraction) {
        final time = extraction.appointmentTime;
        final startTime = time == null
            ? state.startTime
            : TimeOfDay(hour: time.hour, minute: time.minute);

        emit(
          state.copyWith(
            aiScanning: false,
            extraction: extraction,
            customerName: extraction.customerName ?? state.customerName,
            customerLookup: extraction.phone ?? state.customerLookup,
            date: extraction.appointmentDate ?? state.date,
            startTime: startTime,
            endTime: _endTimeFor(startTime, state.endTime),
          ),
        );
      },
    );
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
