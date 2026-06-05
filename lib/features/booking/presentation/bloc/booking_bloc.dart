import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../domain/usecases/cancel_booking_usecase.dart';
import '../../domain/usecases/create_booking_usecase.dart';
import '../../domain/usecases/update_booking_status_usecase.dart';
import '../../domain/usecases/watch_bookings_usecase.dart';
import '../../domain/entities/booking.dart';
import 'booking_event.dart';
import 'booking_state.dart';

@lazySingleton
class BookingBloc extends Bloc<BookingEvent, BookingState> {
  BookingBloc(
    this._watchBookingsUseCase,
    this._createBookingUseCase,
    this._updateBookingStatusUseCase,
    this._cancelBookingUseCase,
  ) : super(const BookingInitial()) {
    on<BookingStarted>(_onStarted);
    on<BookingCreateRequested>(_onCreateRequested);
    on<BookingStatusUpdateRequested>(_onStatusUpdateRequested);
    on<BookingCancelRequested>(_onCancelRequested);
  }

  final WatchBookingsUseCase _watchBookingsUseCase;
  final CreateBookingUseCase _createBookingUseCase;
  final UpdateBookingStatusUseCase _updateBookingStatusUseCase;
  final CancelBookingUseCase _cancelBookingUseCase;

  StreamSubscription? _bookingsSubscription;

  Future<void> _onStarted(
    BookingStarted event,
    Emitter<BookingState> emit,
  ) async {
    await _bookingsSubscription?.cancel();
    emit(const BookingLoading());
    _bookingsSubscription = _watchBookingsUseCase(event.params).listen(
      (result) {
        result.fold(
          (failure) {
            if (!emit.isDone) emit(BookingFailure(failure.message));
          },
          (bookings) {
            if (!emit.isDone) emit(BookingLoaded(bookings));
          },
        );
      },
      onError: (error) {
        if (!emit.isDone) emit(BookingFailure(error.toString()));
      },
    );
  }

  Future<void> _onCreateRequested(
    BookingCreateRequested event,
    Emitter<BookingState> emit,
  ) async {
    final result = await _createBookingUseCase(event.params);
    result.fold(
      (failure) => emit(BookingFailure(failure.message, previous: _current)),
      (_) {},
    );
  }

  Future<void> _onStatusUpdateRequested(
    BookingStatusUpdateRequested event,
    Emitter<BookingState> emit,
  ) async {
    final result = await _updateBookingStatusUseCase(event.params);
    result.fold(
      (failure) => emit(BookingFailure(failure.message, previous: _current)),
      (_) {},
    );
  }

  Future<void> _onCancelRequested(
    BookingCancelRequested event,
    Emitter<BookingState> emit,
  ) async {
    final result = await _cancelBookingUseCase(event.params);
    result.fold(
      (failure) => emit(BookingFailure(failure.message, previous: _current)),
      (_) {},
    );
  }

  List<Booking> get _current {
    final state = this.state;
    if (state is BookingLoaded) {
      return state.bookings;
    }
    if (state is BookingFailure) {
      return state.previous;
    }
    return const [];
  }

  @override
  Future<void> close() {
    _bookingsSubscription?.cancel();
    return super.close();
  }
}
