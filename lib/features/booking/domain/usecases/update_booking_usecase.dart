import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failure.dart';
import '../entities/booking.dart';
import '../repositories/booking_repository.dart';
import 'create_booking_usecase.dart';

class UpdateBookingParams {
  const UpdateBookingParams({required this.bookingId, required this.booking});

  final String bookingId;
  final CreateBookingParams booking;
}

@injectable
class UpdateBookingUseCase {
  const UpdateBookingUseCase(this._repository);

  final BookingRepository _repository;

  Future<Either<Failure, Booking>> call(UpdateBookingParams params) {
    if (params.bookingId.trim().isEmpty) {
      return Future.value(const Left(ValidationFailure('Thiếu mã lịch hẹn.')));
    }
    if (!params.booking.endTime.isAfter(params.booking.startTime)) {
      return Future.value(
        const Left(ValidationFailure('Giờ kết thúc phải sau giờ bắt đầu.')),
      );
    }
    return _repository.updateBooking(params);
  }
}
