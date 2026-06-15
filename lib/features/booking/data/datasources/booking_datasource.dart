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

typedef _AggregateEntry = ({
  DocumentReference<Map<String, dynamic>> ref,
  Map<String, Object> metadata,
});

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

  CollectionReference<Map<String, dynamic>> get _services =>
      _firestore.collection('services');

  CollectionReference<Map<String, dynamic>> get _tenantStatsDaily =>
      _firestore.collection('tenantStatsDaily');

  CollectionReference<Map<String, dynamic>> get _staffStatsDaily =>
      _firestore.collection('staffStatsDaily');

  CollectionReference<Map<String, dynamic>> get _serviceStatsDaily =>
      _firestore.collection('serviceStatsDaily');

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
      throw BookingConflictException('Khung giờ này đã có lịch hẹn.');
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

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists) {
        throw BookingNotFoundException('Không tìm thấy lịch hẹn.');
      }

      final booking = BookingModel.fromFirestore(snapshot);
      if (params.status == BookingStatus.completed &&
          booking.paymentStatus != 'paid') {
        throw BookingPaymentRequiredException(
          'Vui lòng hoàn tất thanh toán trước khi hoàn thành lịch hẹn.',
        );
      }

      final paymentAmount =
          params.status == BookingStatus.completed && booking.paymentAmount == null
          ? await _servicePrice(transaction, booking.serviceId)
          : booking.paymentAmount;

      transaction.update(ref, {
        'status': params.status.value,
        if (paymentAmount != null && booking.paymentAmount == null)
          'paymentAmount': paymentAmount,
        'updatedAt': Timestamp.now(),
      });

      if (params.status == BookingStatus.completed &&
          booking.status != BookingStatus.completed) {
        _incrementCompletedAggregates(transaction, booking, paymentAmount ?? 0);
      }
    });

    final updatedSnapshot = await ref.get();
    return BookingModel.fromFirestore(updatedSnapshot);
  }

  Future<BookingModel> markBookingPaid(MarkBookingPaidParams params) async {
    final ref = _bookings.doc(params.bookingId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists) {
        throw BookingNotFoundException('Không tìm thấy lịch hẹn.');
      }

      final booking = BookingModel.fromFirestore(snapshot);
      final amount = await _servicePrice(transaction, booking.serviceId);
      final wasPaid = booking.paymentStatus == 'paid';

      transaction.update(ref, {
        'paymentStatus': 'paid',
        'paymentAmount': amount,
        'paymentPaidAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });

      if (!wasPaid && booking.status == BookingStatus.completed) {
        _incrementRevenueAggregates(transaction, booking, amount);
      }
    });

    final updatedSnapshot = await ref.get();
    return BookingModel.fromFirestore(updatedSnapshot);
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

  Future<int> _servicePrice(
    Transaction transaction,
    String serviceId,
  ) async {
    if (serviceId.isEmpty) {
      return 0;
    }

    final snapshot = await transaction.get(_services.doc(serviceId));
    final price = snapshot.data()?['price'];
    return price is num ? price.round() : 0;
  }

  void _incrementCompletedAggregates(
    Transaction transaction,
    BookingModel booking,
    int amount,
  ) {
    _incrementRevenueAggregates(transaction, booking, amount);
    _incrementAggregateFields(transaction, _aggregateEntries(booking), {
      'completedBookings': FieldValue.increment(1),
    });
  }

  void _incrementRevenueAggregates(
    Transaction transaction,
    BookingModel booking,
    int amount,
  ) {
    _incrementAggregateFields(transaction, _aggregateEntries(booking), {
      'revenue': FieldValue.increment(amount),
      'updatedAt': Timestamp.now(),
    });
  }

  void _incrementAggregateFields(
    Transaction transaction,
    List<_AggregateEntry> entries,
    Map<String, Object> fields,
  ) {
    for (final entry in entries) {
      transaction.set(
        entry.ref,
        {
          ...entry.metadata,
          ...fields,
        },
        SetOptions(merge: true),
      );
    }
  }

  List<_AggregateEntry> _aggregateEntries(BookingModel booking) {
    final dateKey = _dateKey(booking.startTime);
    final date = Timestamp.fromDate(
      DateTime(
        booking.startTime.year,
        booking.startTime.month,
        booking.startTime.day,
      ),
    );
    return [
      (
        ref: _tenantStatsDaily.doc('${booking.tenantId}_$dateKey'),
        metadata: {
          'tenantId': booking.tenantId,
          'date': date,
          'dateKey': dateKey,
        },
      ),
      (
        ref: _staffStatsDaily.doc('${booking.tenantId}_${booking.staffId}_$dateKey'),
        metadata: {
          'tenantId': booking.tenantId,
          'staffId': booking.staffId,
          if (booking.staffName != null) 'staffName': booking.staffName!,
          'date': date,
          'dateKey': dateKey,
        },
      ),
      (
        ref: _serviceStatsDaily.doc(
          '${booking.tenantId}_${booking.serviceId}_$dateKey',
        ),
        metadata: {
          'tenantId': booking.tenantId,
          'serviceId': booking.serviceId,
          if (booking.serviceName != null) 'serviceName': booking.serviceName!,
          'date': date,
          'dateKey': dateKey,
        },
      ),
    ];
  }

  String _dateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}
