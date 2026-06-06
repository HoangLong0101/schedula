import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failure.dart';
import '../../domain/entities/booking.dart';
import '../../domain/entities/slot.dart';
import '../../domain/repositories/booking_repository.dart';
import '../../domain/usecases/cancel_booking_usecase.dart';
import '../../domain/usecases/create_booking_usecase.dart';
import '../../domain/usecases/update_booking_status_usecase.dart';
import '../../domain/usecases/watch_bookings_usecase.dart';
import '../../domain/usecases/watch_slots_usecase.dart';
import '../datasources/booking_datasource.dart';

@LazySingleton(as: BookingRepository)
class BookingRepositoryImpl implements BookingRepository {
  const BookingRepositoryImpl(this._dataSource);

  final BookingDataSource _dataSource;

  @override
  Future<Either<Failure, Booking>> createBooking(
    CreateBookingParams params,
  ) async {
    try {
      final model = await _dataSource.createBooking(params);
      return Right(model);
    } on BookingConflictException catch (error) {
      return Left(ConflictFailure(error.message));
    } catch (error) {
      return Left(ServerFailure(error.toString()));
    }
  }

  @override
  Stream<Either<Failure, List<Booking>>> watchBookings(
    WatchBookingsParams params,
  ) {
    return _dataSource.watchBookings(params).transform(
          StreamTransformer.fromHandlers(
            handleData: (data, sink) => sink.add(Right(data)),
            handleError: (error, stackTrace, sink) {
              sink.add(Left(ServerFailure(error.toString())));
            },
          ),
        );
  }

  @override
  Stream<Either<Failure, List<Slot>>> watchSlots(WatchSlotsParams params) {
    return _dataSource.watchSlots(params).transform(
          StreamTransformer.fromHandlers(
            handleData: (data, sink) => sink.add(Right(data)),
            handleError: (error, stackTrace, sink) {
              sink.add(Left(ServerFailure(error.toString())));
            },
          ),
        );
  }

  @override
  Future<Either<Failure, Booking>> updateBookingStatus(
    UpdateBookingStatusParams params,
  ) async {
    try {
      final booking = await _dataSource.updateBookingStatus(params);
      return Right(booking);
    } on BookingNotFoundException catch (error) {
      return Left(NotFoundFailure(error.message));
    } catch (error) {
      return Left(ServerFailure(error.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> cancelBooking(CancelBookingParams params) async {
    try {
      await _dataSource.cancelBooking(params);
      return const Right(null);
    } catch (error) {
      return Left(ServerFailure(error.toString()));
    }
  }
}
