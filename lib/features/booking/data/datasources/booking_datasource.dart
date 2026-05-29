import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';

import '../models/booking_model.dart';

@lazySingleton
class BookingDataSource {
  BookingDataSource(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _bookings =>
      _firestore.collection('bookings');

  Future<List<BookingModel>> fetchBookings() async {
    final snapshot = await _bookings.orderBy('title').get();
    return snapshot.docs.map(BookingModel.fromFirestore).toList();
  }

  Stream<List<BookingModel>> watchBookings(String tenantId) {
    return _bookings
        .where('tenantId', isEqualTo: tenantId)
        .orderBy('title')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map(BookingModel.fromFirestore)
            .toList(growable: false));
  }

  Future<void> saveBooking(BookingModel booking) {
    return _bookings.doc(booking.id).set(
          booking.toFirestore(),
          SetOptions(merge: true),
        );
  }

  Future<void> deleteBooking(String bookingId) {
    return _bookings.doc(bookingId).delete();
  }
}
