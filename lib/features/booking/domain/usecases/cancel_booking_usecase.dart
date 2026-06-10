import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failure.dart';
import '../repositories/booking_repository.dart';

class CancelBookingParams {
  const CancelBookingParams({required this.bookingId, this.reason});

  final String bookingId;
  final String? reason;
}

@injectable
class CancelBookingUseCase {
  const CancelBookingUseCase(this._repository);

  final BookingRepository _repository;

  Future<Either<Failure, void>> call(CancelBookingParams params) {
    return _repository.cancelBooking(params);
  }
}
