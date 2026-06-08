import 'package:equatable/equatable.dart';

import '../../domain/entities/booking.dart';

sealed class BookingState extends Equatable {
  const BookingState();

  @override
  List<Object?> get props => const [];
}

final class BookingInitial extends BookingState {
  const BookingInitial();
}

final class BookingLoading extends BookingState {
  const BookingLoading();
}

final class BookingLoaded extends BookingState {
  const BookingLoaded(this.bookings);

  final List<Booking> bookings;

  @override
  List<Object?> get props => [bookings];
}

final class BookingFailure extends BookingState {
  const BookingFailure(this.message, {this.previous = const []});

  final String message;
  final List<Booking> previous;

  @override
  List<Object?> get props => [message, previous];
}
