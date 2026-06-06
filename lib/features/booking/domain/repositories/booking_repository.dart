import 'dart:async';

import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';
import '../entities/booking.dart';
import '../entities/slot.dart';
import '../usecases/cancel_booking_usecase.dart';
import '../usecases/create_booking_usecase.dart';
import '../usecases/update_booking_status_usecase.dart';
import '../usecases/watch_bookings_usecase.dart';
import '../usecases/watch_slots_usecase.dart';

abstract class BookingRepository {
  Future<Either<Failure, Booking>> createBooking(CreateBookingParams params);

  Stream<Either<Failure, List<Booking>>> watchBookings(
    WatchBookingsParams params,
  );

  Stream<Either<Failure, List<Slot>>> watchSlots(
    WatchSlotsParams params,
  );

  Future<Either<Failure, Booking>> updateBookingStatus(
    UpdateBookingStatusParams params,
  );

  Future<Either<Failure, void>> cancelBooking(
    CancelBookingParams params,
  );
}
