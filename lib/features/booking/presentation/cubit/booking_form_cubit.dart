import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'booking_form_state.dart';

class BookingFormCubit extends Cubit<BookingFormState> {
  BookingFormCubit() : super(BookingFormState());

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
    final startMinutes = value.hour * 60 + value.minute;
    final endMinutes = state.endTime.hour * 60 + state.endTime.minute;
    final endTime = endMinutes <= startMinutes
        ? TimeOfDay(
            hour: ((startMinutes + 60) ~/ 60) % 24,
            minute: (startMinutes + 60) % 60,
          )
        : state.endTime;

    emit(state.copyWith(startTime: value, endTime: endTime));
  }

  void updateEndTime(TimeOfDay value) {
    emit(state.copyWith(endTime: value));
  }

  void updateNotes(String value) {
    emit(state.copyWith(notes: value));
  }

  void updateMode({required bool aiMode}) {
    emit(state.copyWith(aiMode: aiMode));
  }
}
