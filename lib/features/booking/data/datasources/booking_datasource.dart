import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/services.dart';
import 'package:injectable/injectable.dart';

import '../../domain/entities/booking_status.dart';
import '../../domain/usecases/cancel_booking_usecase.dart';
import '../../domain/usecases/create_booking_usecase.dart';
import '../../domain/usecases/update_booking_usecase.dart';
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

class BookingPaymentRequiredException implements Exception {
  BookingPaymentRequiredException(this.message);

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

  FirebaseFunctions get _functions =>
      FirebaseFunctions.instanceFor(region: 'asia-southeast1');

  Stream<List<BookingModel>> watchBookings(WatchBookingsParams params) async* {
    Query<Map<String, dynamic>> query = _bookings.where(
      'tenantId',
      isEqualTo: params.tenantId,
    );

    if (params.staffId != null && params.staffId!.isNotEmpty) {
      query = query.where('staffId', isEqualTo: params.staffId);
    }
    if (params.customerId != null && params.customerId!.isNotEmpty) {
      query = query.where('customerId', isEqualTo: params.customerId);
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

  Future<BookingModel> createBooking(CreateBookingParams params) {
    return _mutate({'action': 'create', ..._bookingData(params)});
  }

  Future<BookingModel> updateBooking(UpdateBookingParams params) {
    return _mutate({
      'action': 'update',
      'bookingId': params.bookingId,
      ..._bookingData(params.booking),
    });
  }

  Future<BookingModel> updateBookingStatus(UpdateBookingStatusParams params) {
    return _mutate({
      'action': 'status',
      'bookingId': params.bookingId,
      'status': params.status.value,
    });
  }

  Future<BookingModel> markBookingPaid(MarkBookingPaidParams params) async {
    final result = await _functions
        .httpsCallable('recordManualPayment')
        .call<Map<String, dynamic>>({
          'bookingId': params.bookingId,
          'method': params.method,
          'amount': params.amount,
          'reference': params.reference,
        });
    return _readBooking(result.data['bookingId'] as String);
  }

  Future<void> cancelBooking(CancelBookingParams params) async {
    await _functions.httpsCallable('mutateBooking').call<void>({
      'action': 'cancel',
      'bookingId': params.bookingId,
      'reason': params.reason,
    });
  }

  Future<BookingModel> _mutate(Map<String, dynamic> data) async {
    try {
      final result = await _functions
          .httpsCallable('mutateBooking')
          .call<Map<String, dynamic>>(data);
      return _readBooking(result.data['bookingId'] as String);
    } on FirebaseFunctionsException catch (error) {
      if (error.code == 'already-exists') {
        throw BookingConflictException(error.message ?? 'Booking conflict');
      }
      if (error.code == 'not-found') {
        throw BookingNotFoundException(
          error.message ?? 'Không tìm thấy lịch hẹn.',
        );
      }
      if (error.code == 'failed-precondition') {
        throw BookingPaymentRequiredException(
          error.message ?? 'Booking rejected',
        );
      }
      rethrow;
    }
  }

  Future<BookingModel> _readBooking(String id) async {
    final snapshot = await _bookings.doc(id).get();
    if (!snapshot.exists) {
      throw BookingNotFoundException('Không tìm thấy lịch hẹn.');
    }
    return BookingModel.fromFirestore(snapshot);
  }

  Map<String, dynamic> _bookingData(CreateBookingParams params) => {
    'staffId': params.staffId,
    'customerId': params.customerId,
    'serviceId': params.serviceId,
    'startTime': params.startTime.toUtc().toIso8601String(),
    'endTime': params.endTime.toUtc().toIso8601String(),
    'status': params.status.value,
    'notes': params.notes,
    'customerName': params.customerName,
    'staffName': params.staffName,
    'serviceName': params.serviceName,
    'resourceIds': params.resourceIds,
  };

  bool _isPermissionDenied(Object error) {
    return error is FirebaseException && error.code == 'permission-denied' ||
        error is PlatformException &&
            (error.code == 'permission-denied' ||
                (error.message?.contains('PERMISSION_DENIED') ?? false) ||
                (error.message?.contains('permission-denied') ?? false));
  }
}
