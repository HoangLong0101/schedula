import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failure.dart';
import '../entities/booking.dart';
import '../entities/booking_status.dart';
import '../repositories/booking_repository.dart';

class UpdateBookingStatusParams {
  const UpdateBookingStatusParams({
    required this.bookingId,
    required this.status,
  });

  final String bookingId;
  final BookingStatus status;
}

@injectable
class UpdateBookingStatusUseCase {
  const UpdateBookingStatusUseCase(this._repository);

  final BookingRepository _repository;

  Future<Either<Failure, Booking>> call(UpdateBookingStatusParams params) {
    return _repository.updateBookingStatus(params);
  }
}
