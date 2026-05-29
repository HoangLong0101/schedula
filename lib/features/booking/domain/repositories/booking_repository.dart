import 'dart:async';

import '../entities/booking.dart';

abstract class BookingRepository {
  Future<List<Booking>> getBookings();

  Stream<List<Booking>> watchBookings(String tenantId);

  Future<void> saveBooking(Booking booking);

  Future<void> deleteBooking(String bookingId);
}
