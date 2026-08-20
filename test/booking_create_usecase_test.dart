import 'package:flutter_test/flutter_test.dart';
import 'package:dartz/dartz.dart';

import 'package:schedula/features/booking/domain/entities/booking.dart';
import 'package:schedula/features/booking/domain/entities/booking_status.dart';
import 'package:schedula/features/booking/domain/repositories/booking_repository.dart';
import 'package:schedula/features/booking/domain/usecases/update_booking_status_usecase.dart';
import 'package:schedula/features/booking/domain/usecases/cancel_booking_usecase.dart';
import 'package:schedula/features/booking/domain/usecases/watch_bookings_usecase.dart';
import 'package:schedula/features/booking/domain/usecases/watch_slots_usecase.dart';
import 'package:schedula/features/booking/domain/entities/slot.dart';
import 'package:schedula/features/booking/domain/usecases/create_booking_usecase.dart';
import 'package:schedula/features/booking/domain/usecases/update_booking_usecase.dart';
import 'package:schedula/core/errors/failure.dart';

class FakeBookingRepository implements BookingRepository {
  final Booking? toReturn;
  final bool shouldFail;
  FakeBookingRepository({this.toReturn, this.shouldFail = false});

  @override
  Future<Either<Failure, Booking>> createBooking(
    CreateBookingParams params,
  ) async {
    if (shouldFail) {
      return Left(ServerFailure('failed'));
    }
    return Right(
      toReturn ??
          Booking(
            id: 'id',
            tenantId: params.tenantId,
            staffId: params.staffId,
            customerId: params.customerId,
            serviceId: params.serviceId,
            startTime: params.startTime,
            endTime: params.endTime,
            status: params.status,
            resourceIds: params.resourceIds,
          ),
    );
  }

  // Unused for this test.
  @override
  Future<Either<Failure, Booking>> updateBookingStatus(
    UpdateBookingStatusParams params,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<Either<Failure, Booking>> updateBooking(
    UpdateBookingParams params,
  ) async {
    final booking = params.booking;
    return Right(
      Booking(
        id: params.bookingId,
        tenantId: booking.tenantId,
        staffId: booking.staffId,
        customerId: booking.customerId,
        serviceId: booking.serviceId,
        startTime: booking.startTime,
        endTime: booking.endTime,
        status: booking.status,
        notes: booking.notes,
      ),
    );
  }

  @override
  Future<Either<Failure, Booking>> markBookingPaid(
    MarkBookingPaidParams params,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<Either<Failure, void>> cancelBooking(CancelBookingParams params) {
    throw UnimplementedError();
  }

  @override
  Stream<Either<Failure, List<Booking>>> watchBookings(
    WatchBookingsParams params,
  ) {
    throw UnimplementedError();
  }

  @override
  Stream<Either<Failure, List<Slot>>> watchSlots(WatchSlotsParams params) {
    throw UnimplementedError();
  }
}

void main() {
  group('CreateBookingUseCase', () {
    test('returns booking on success', () async {
      final fakeRepo = FakeBookingRepository();
      final usecase = CreateBookingUseCase(fakeRepo);

      final params = CreateBookingParams(
        tenantId: 't1',
        staffId: 's1',
        customerId: 'c1',
        serviceId: 'svc1',
        startTime: DateTime.now(),
        endTime: DateTime.now().add(const Duration(hours: 1)),
        status: BookingStatus.pending,
        resourceIds: const ['equipment-1'],
      );

      final result = await usecase(params);
      expect(result.isRight(), true);
      result.fold((l) => fail('expected right'), (booking) {
        expect(booking.tenantId, 't1');
        expect(booking.staffId, 's1');
        expect(booking.resourceIds, const ['equipment-1']);
      });
    });

    test('returns failure when repo fails', () async {
      final fakeRepo = FakeBookingRepository(shouldFail: true);
      final usecase = CreateBookingUseCase(fakeRepo);

      final params = CreateBookingParams(
        tenantId: 't1',
        staffId: 's1',
        customerId: 'c1',
        serviceId: 'svc1',
        startTime: DateTime.now(),
        endTime: DateTime.now().add(const Duration(hours: 1)),
        status: BookingStatus.pending,
      );

      final result = await usecase(params);
      expect(result.isLeft(), true);
    });

    test(
      'returns validation failure when required fields are missing',
      () async {
        final fakeRepo = FakeBookingRepository();
        final usecase = CreateBookingUseCase(fakeRepo);
        final now = DateTime.now();

        final result = await usecase(
          CreateBookingParams(
            tenantId: '',
            staffId: '',
            customerId: '',
            serviceId: '',
            startTime: now,
            endTime: now,
            status: BookingStatus.pending,
          ),
        );

        expect(result.isLeft(), true);
        result.fold(
          (failure) => expect(failure, isA<ValidationFailure>()),
          (_) => fail('expected validation failure'),
        );
      },
    );
  });

  test(
    'UpdateBookingUseCase preserves the booking id and submitted fields',
    () async {
      final useCase = UpdateBookingUseCase(FakeBookingRepository());
      final start = DateTime(2026, 7, 27, 9);
      final result = await useCase(
        UpdateBookingParams(
          bookingId: 'booking-1',
          booking: CreateBookingParams(
            tenantId: 'tenant-1',
            staffId: 'staff-1',
            customerId: 'customer-1',
            serviceId: 'service-1',
            startTime: start,
            endTime: start.add(const Duration(hours: 1)),
            status: BookingStatus.confirmed,
            notes: 'updated',
          ),
        ),
      );

      result.fold((failure) => fail(failure.message), (booking) {
        expect(booking.id, 'booking-1');
        expect(booking.notes, 'updated');
        expect(booking.status, BookingStatus.confirmed);
      });
    },
  );

  test('MarkBookingPaidUseCase rejects invalid manual payment data', () async {
    final useCase = MarkBookingPaidUseCase(FakeBookingRepository());

    final badMethod = await useCase(
      const MarkBookingPaidParams(
        bookingId: 'booking-1',
        method: 'card',
        amount: 100000,
      ),
    );
    final badAmount = await useCase(
      const MarkBookingPaidParams(
        bookingId: 'booking-1',
        method: 'cash',
        amount: 0,
      ),
    );

    expect(badMethod.isLeft(), true);
    expect(badAmount.isLeft(), true);
  });
}
