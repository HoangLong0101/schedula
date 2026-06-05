import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failure.dart';
import '../entities/booking.dart';
import '../entities/booking_status.dart';
import '../repositories/booking_repository.dart';

class WatchBookingsParams {
  const WatchBookingsParams({
    required this.tenantId,
    this.startDate,
    this.endDate,
    this.staffId,
    this.status,
  });

  final String tenantId;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? staffId;
  final BookingStatus? status;
}

@injectable
class WatchBookingsUseCase {
  const WatchBookingsUseCase(this._repository);

  final BookingRepository _repository;

  Stream<Either<Failure, List<Booking>>> call(WatchBookingsParams params) {
    return _repository.watchBookings(params);
  }
}
