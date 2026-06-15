import 'package:equatable/equatable.dart';

import '../../domain/usecases/cancel_booking_usecase.dart';
import '../../domain/usecases/create_booking_usecase.dart';
import '../../domain/usecases/update_booking_status_usecase.dart';
import '../../domain/usecases/watch_bookings_usecase.dart';
import '../../domain/entities/booking.dart';

sealed class BookingEvent extends Equatable {
  const BookingEvent();

  @override
  List<Object?> get props => const [];
}

final class BookingStarted extends BookingEvent {
  const BookingStarted(this.params);

  final WatchBookingsParams params;

  @override
  List<Object?> get props => [params];
}

final class BookingCreateRequested extends BookingEvent {
  const BookingCreateRequested(this.params);

  final CreateBookingParams params;

  @override
  List<Object?> get props => [params];
}

final class BookingStatusUpdateRequested extends BookingEvent {
  const BookingStatusUpdateRequested(this.params);

  final UpdateBookingStatusParams params;

  @override
  List<Object?> get props => [params];
}

final class BookingPaymentCompleteRequested extends BookingEvent {
  const BookingPaymentCompleteRequested(this.params);

  final MarkBookingPaidParams params;

  @override
  List<Object?> get props => [params];
}

final class BookingCancelRequested extends BookingEvent {
  const BookingCancelRequested(this.params);

  final CancelBookingParams params;

  @override
  List<Object?> get props => [params];
}

final class BookingWatchUpdated extends BookingEvent {
  const BookingWatchUpdated(this.bookings);

  final List<Booking> bookings;

  @override
  List<Object?> get props => [bookings];
}

final class BookingWatchFailed extends BookingEvent {
  const BookingWatchFailed(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
