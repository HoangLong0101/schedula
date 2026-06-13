import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/utils/date_utils.dart';
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
    final query = _bookings.where('tenantId', isEqualTo: params.tenantId);

    try {
      await for (final snapshot in query.snapshots()) {
        yield _filterBookings(snapshot, params);
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
    final slotId =
        '${DateUtilsX.formatIsoDate(params.startTime)}_${params.staffId}';
    final slotRef = _slots.doc(slotId);

    return _firestore.runTransaction((tx) async {
      final slotSnap = await tx.get(slotRef);
      final slotData = slotSnap.data() ?? const <String, dynamic>{};
      final rawIntervals = slotData['intervals'] as List<dynamic>? ?? const [];
      final intervals = rawIntervals
          .whereType<Map<String, dynamic>>()
          .map(SlotIntervalModel.fromJson)
          .toList(growable: false);

      final overlaps = intervals.any((interval) {
        return params.startTime.isBefore(interval.endTime) &&
            params.endTime.isAfter(interval.startTime);
      });

      if (overlaps) {
        throw BookingConflictException('Slot already taken');
      }

      final updatedIntervals = [
        ...intervals,
        SlotIntervalModel(
          startTime: params.startTime,
          endTime: params.endTime,
          bookingId: bookingRef.id,
        ),
      ];

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

      tx.set(
        slotRef,
        SlotModel(
          id: slotRef.id,
          tenantId: params.tenantId,
          staffId: params.staffId,
          date: DateTime(
            params.startTime.year,
            params.startTime.month,
            params.startTime.day,
          ),
          intervals: updatedIntervals,
        ).toFirestore(),
        SetOptions(merge: true),
      );

      tx.set(bookingRef, booking.toFirestore());

      return booking;
    });
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

  List<BookingModel> _filterBookings(
    QuerySnapshot<Map<String, dynamic>> snapshot,
    WatchBookingsParams params,
  ) {
    final bookings = snapshot.docs
        .map(BookingModel.fromFirestore)
        .where((booking) {
          final matchesStart =
              params.startDate == null ||
              !booking.startTime.isBefore(params.startDate!);
          final matchesEnd =
              params.endDate == null ||
              booking.startTime.isBefore(params.endDate!);
          final matchesStaff =
              params.staffId == null ||
              params.staffId!.isEmpty ||
              booking.staffId == params.staffId;
          final matchesStatus =
              params.status == null || booking.status == params.status;

          return matchesStart && matchesEnd && matchesStaff && matchesStatus;
        })
        .toList(growable: false);

    return bookings..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  bool _isPermissionDenied(Object error) {
    return error is FirebaseException && error.code == 'permission-denied' ||
        error is PlatformException &&
            (error.code == 'permission-denied' ||
                (error.message?.contains('PERMISSION_DENIED') ?? false) ||
                (error.message?.contains('permission-denied') ?? false));
  }
}
