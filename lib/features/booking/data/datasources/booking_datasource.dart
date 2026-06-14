import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:injectable/injectable.dart';

import '../../domain/entities/booking_status.dart';
import '../../domain/usecases/cancel_booking_usecase.dart';
import '../../domain/usecases/create_booking_usecase.dart';
import '../../domain/usecases/update_booking_status_usecase.dart';
import '../../domain/usecases/watch_bookings_usecase.dart';
import '../../domain/usecases/watch_slots_usecase.dart';
import '../models/booking_model.dart';
import '../models/slot_model.dart';

class BookingConflictException implements Exception {
  BookingConflictException(this.message);

  final String message;
}

class BookingNotFoundException implements Exception {
  BookingNotFoundException(this.message);

  final String message;
}

@lazySingleton
class BookingDataSource {
  BookingDataSource(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _bookings =>
      _firestore.collection('bookings');

  CollectionReference<Map<String, dynamic>> get _slots =>
      _firestore.collection('slots');

  Stream<List<BookingModel>> watchBookings(WatchBookingsParams params) async* {
    Query<Map<String, dynamic>> query = _bookings.where(
      'tenantId',
      isEqualTo: params.tenantId,
    );

    if (params.staffId != null && params.staffId!.isNotEmpty) {
      query = query.where('staffId', isEqualTo: params.staffId);
    }
    if (params.status != null) {
      query = query.where('status', isEqualTo: params.status!.value);
    }
    if (params.startDate != null) {
      query = query.where(
        'startTime',
        isGreaterThanOrEqualTo: Timestamp.fromDate(params.startDate!),
      );
    }
    if (params.endDate != null) {
      query = query.where(
        'startTime',
        isLessThan: Timestamp.fromDate(params.endDate!),
      );
    }
    query = query.orderBy('startTime');

    try {
      await for (final snapshot in query.snapshots()) {
        yield snapshot.docs
            .map(BookingModel.fromFirestore)
            .toList(growable: false);
      }
    } catch (error) {
      if (_isPermissionDenied(error)) {
        yield const <BookingModel>[];
        return;
      }
      rethrow;
    }
  }

  Stream<List<SlotModel>> watchSlots(WatchSlotsParams params) async* {
    Query<Map<String, dynamic>> query = _slots
        .where('tenantId', isEqualTo: params.tenantId)
        .where('staffId', isEqualTo: params.staffId)
        .orderBy('date');

    if (params.startDate != null) {
      query = query.where(
        'date',
        isGreaterThanOrEqualTo: Timestamp.fromDate(params.startDate!),
      );
    }
    if (params.endDate != null) {
      query = query.where(
        'date',
        isLessThan: Timestamp.fromDate(params.endDate!),
      );
    }

    try {
      await for (final snapshot in query.snapshots()) {
        yield snapshot.docs
            .map(SlotModel.fromFirestore)
            .toList(growable: false);
      }
    } catch (error) {
      if (_isPermissionDenied(error)) {
        yield const <SlotModel>[];
        return;
      }
      rethrow;
    }
  }

  Future<BookingModel> createBooking(CreateBookingParams params) async {
    final bookingRef = _bookings.doc();

    final conflicts = await _bookings
        .where('tenantId', isEqualTo: params.tenantId)
        .where('staffId', isEqualTo: params.staffId)
        .get();

    final hasOverlap = conflicts.docs.map(BookingModel.fromFirestore).any((
      booking,
    ) {
      if (booking.status == BookingStatus.cancelled ||
          booking.status == BookingStatus.completed ||
          booking.status == BookingStatus.noShow) {
        return false;
      }
      return params.startTime.isBefore(booking.endTime) &&
          params.endTime.isAfter(booking.startTime);
    });

    if (hasOverlap) {
      throw BookingConflictException('Slot already taken');
    }

    final booking = BookingModel(
      id: bookingRef.id,
      tenantId: params.tenantId,
      staffId: params.staffId,
      customerId: params.customerId,
      serviceId: params.serviceId,
      startTime: params.startTime,
      endTime: params.endTime,
      status: params.status,
      notes: params.notes,
      createdBy: params.createdBy,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      customerName: params.customerName,
      staffName: params.staffName,
      serviceName: params.serviceName,
    );

    await bookingRef.set(booking.toFirestore());
    return booking;
  }

  Future<BookingModel> updateBookingStatus(
    UpdateBookingStatusParams params,
  ) async {
    final ref = _bookings.doc(params.bookingId);
    await ref.update({
      'status': params.status.value,
      'updatedAt': Timestamp.now(),
    });
    final snapshot = await ref.get();
    if (!snapshot.exists) {
      throw BookingNotFoundException('Booking not found');
    }
    return BookingModel.fromFirestore(snapshot);
  }

  Future<void> cancelBooking(CancelBookingParams params) async {
    final ref = _bookings.doc(params.bookingId);
    await ref.update({
      'status': 'cancelled',
      'updatedAt': Timestamp.now(),
      if (params.reason != null) 'notes': params.reason,
    });
  }

  bool _isPermissionDenied(Object error) {
    return error is FirebaseException && error.code == 'permission-denied' ||
        error is PlatformException &&
            (error.code == 'permission-denied' ||
                (error.message?.contains('PERMISSION_DENIED') ?? false) ||
                (error.message?.contains('permission-denied') ?? false));
  }
}
