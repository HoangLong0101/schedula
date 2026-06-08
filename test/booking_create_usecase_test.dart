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
import 'package:schedula/core/errors/failure.dart';

class FakeBookingRepository implements BookingRepository {
  final Booking? toReturn;
  final bool shouldFail;
  FakeBookingRepository({this.toReturn, this.shouldFail = false});

  @override
  Future<Either<Failure, Booking>> createBooking(CreateBookingParams params) async {
    if (shouldFail) {
      return Left(ServerFailure('failed'));
    }
    return Right(toReturn ?? Booking(
      id: 'id',
      tenantId: params.tenantId,
      staffId: params.staffId,
      customerId: params.customerId,
      serviceId: params.serviceId,
      startTime: params.startTime,
      endTime: params.endTime,
      status: params.status,
    ));
  }

  // Unused for this test.
  @override
  Future<Either<Failure, Booking>> updateBookingStatus(UpdateBookingStatusParams params) {
    throw UnimplementedError();
  }

  @override
  Future<Either<Failure, void>> cancelBooking(CancelBookingParams params) {
    throw UnimplementedError();
  }

  @override
  Stream<Either<Failure, List<Booking>>> watchBookings(WatchBookingsParams params) {
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
      );

      final result = await usecase(params);
      expect(result.isRight(), true);
      result.fold((l) => fail('expected right'), (booking) {
        expect(booking.tenantId, 't1');
        expect(booking.staffId, 's1');
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
  });
}
