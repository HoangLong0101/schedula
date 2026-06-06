import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'booking_form_state.dart';

class BookingFormCubit extends Cubit<BookingFormState> {
  BookingFormCubit() : super(const BookingFormState());

  void updateCustomerId(String value) {
    emit(state.copyWith(customerId: value));
  }

  void updateStaffId(String value) {
    emit(state.copyWith(staffId: value));
  }

  void updateServiceId(String value) {
    emit(state.copyWith(serviceId: value));
  }

  void updateDate(DateTime value) {
    emit(state.copyWith(date: value));
  }

  void updateStartTime(TimeOfDay value) {
    emit(state.copyWith(startTime: value));
  }

  void updateEndTime(TimeOfDay value) {
    emit(state.copyWith(endTime: value));
  }

  void updateNotes(String value) {
    emit(state.copyWith(notes: value));
  }
}
