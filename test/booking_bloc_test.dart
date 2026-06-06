import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:dartz/dartz.dart';

import 'package:schedula/features/booking/presentation/bloc/booking_bloc.dart';
import 'package:schedula/features/booking/presentation/bloc/booking_event.dart';
import 'package:schedula/features/booking/presentation/bloc/booking_state.dart';
import 'package:schedula/features/booking/domain/usecases/watch_bookings_usecase.dart';
import 'package:schedula/features/booking/domain/usecases/create_booking_usecase.dart';
import 'package:schedula/features/booking/domain/usecases/update_booking_status_usecase.dart';
import 'package:schedula/features/booking/domain/usecases/cancel_booking_usecase.dart';
import 'package:schedula/features/booking/domain/entities/booking.dart';
import 'package:schedula/features/booking/domain/entities/booking_status.dart';
import 'package:schedula/core/errors/failure.dart';

class FakeWatchBookingsUseCase implements WatchBookingsUseCase {
  final StreamController<Either<Failure, List<Booking>>> _ctrl;
  FakeWatchBookingsUseCase(this._ctrl);
  @override
  Stream<Either<Failure, List<Booking>>> call(WatchBookingsParams params) {
    return _ctrl.stream;
  }
}

class FakeCreateBookingUseCase implements CreateBookingUseCase {
  final Future<Either<Failure, Booking>> Function(CreateBookingParams) fn;
  FakeCreateBookingUseCase(this.fn);
  @override
  Future<Either<Failure, Booking>> call(CreateBookingParams params) => fn(params);
}

class FakeUpdateBookingStatusUseCase implements UpdateBookingStatusUseCase {
  final Future<Either<Failure, Booking>> Function(UpdateBookingStatusParams) fn;
  FakeUpdateBookingStatusUseCase(this.fn);
  @override
  Future<Either<Failure, Booking>> call(UpdateBookingStatusParams params) => fn(params);
}

class FakeCancelBookingUseCase implements CancelBookingUseCase {
  final Future<Either<Failure, void>> Function(CancelBookingParams) fn;
  FakeCancelBookingUseCase(this.fn);
  @override
  Future<Either<Failure, void>> call(CancelBookingParams params) => fn(params);
}

void main() {
  group('BookingBloc', () {
    late StreamController<Either<Failure, List<Booking>>> ctrl;
    late BookingBloc bloc;

    setUp(() {
      ctrl = StreamController<Either<Failure, List<Booking>>>();
      final watch = FakeWatchBookingsUseCase(ctrl);
      final create = FakeCreateBookingUseCase((_) async => Right(Booking(
            id: 'b1',
            tenantId: 't1',
            staffId: 's1',
            customerId: 'c1',
            serviceId: 'svc1',
            startTime: DateTime.now(),
            endTime: DateTime.now().add(const Duration(hours: 1)),
            status: BookingStatus.pending,
          )));
      final update = FakeUpdateBookingStatusUseCase((_) async => Right(Booking(
            id: 'b1',
            tenantId: 't1',
            staffId: 's1',
            customerId: 'c1',
            serviceId: 'svc1',
            startTime: DateTime.now(),
            endTime: DateTime.now().add(const Duration(hours: 1)),
            status: BookingStatus.confirmed,
          )));
      final cancel = FakeCancelBookingUseCase((_) async => Right(null));

      bloc = BookingBloc(watch, create, update, cancel);
    });

    tearDown(() {
      ctrl.close();
      bloc.close();
    });

    test('emits loaded when watch returns bookings', () async {
      final bookings = <Booking>[
        Booking(
          id: 'b1',
          tenantId: 't1',
          staffId: 's1',
          customerId: 'c1',
          serviceId: 'svc1',
          startTime: DateTime.now(),
          endTime: DateTime.now().add(const Duration(hours: 1)),
          status: BookingStatus.pending,
        )
      ];

      bloc.add(BookingStarted(WatchBookingsParams(tenantId: 't1')));
      ctrl.add(Right(bookings));

      await expectLater(
        bloc.stream,
        emitsThrough(isA<BookingLoaded>()),
      );
    });

    test('emits failure when create fails', () async {
      final create = FakeCreateBookingUseCase((_) async => Left(ServerFailure('fail')));
      // Recreate bloc with failing create
      final watch = FakeWatchBookingsUseCase(ctrl);
      final update = FakeUpdateBookingStatusUseCase((_) async => Right(Booking(
            id: 'b1',
            tenantId: 't1',
            staffId: 's1',
            customerId: 'c1',
            serviceId: 'svc1',
            startTime: DateTime.now(),
            endTime: DateTime.now().add(const Duration(hours: 1)),
            status: BookingStatus.confirmed,
          )));
      final cancel = FakeCancelBookingUseCase((_) async => Right(null));
      final failingBloc = BookingBloc(watch, create, update, cancel);

      failingBloc.add(BookingCreateRequested(CreateBookingParams(
        tenantId: 't1',
        staffId: 's1',
        customerId: 'c1',
        serviceId: 'svc1',
        startTime: DateTime.now(),
        endTime: DateTime.now().add(const Duration(hours: 1)),
        status: BookingStatus.pending,
      )));

      await expectLater(
        failingBloc.stream,
        emitsThrough(isA<BookingFailure>()),
      );

      await failingBloc.close();
    });
  });
}
