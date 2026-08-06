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

class MarkBookingPaidParams {
  const MarkBookingPaidParams({
    required this.bookingId,
    required this.method,
    required this.amount,
    this.reference,
  });

  final String bookingId;
  final String method;
  final int amount;
  final String? reference;
}

@injectable
class UpdateBookingStatusUseCase {
  const UpdateBookingStatusUseCase(this._repository);

  final BookingRepository _repository;

  Future<Either<Failure, Booking>> call(UpdateBookingStatusParams params) {
    if (params.bookingId.trim().isEmpty) {
      return Future.value(const Left(ValidationFailure('Thiếu mã lịch hẹn.')));
    }
    return _repository.updateBookingStatus(params);
  }
}

@injectable
class MarkBookingPaidUseCase {
  const MarkBookingPaidUseCase(this._repository);

  final BookingRepository _repository;

  Future<Either<Failure, Booking>> call(MarkBookingPaidParams params) {
    if (params.bookingId.trim().isEmpty) {
      return Future.value(const Left(ValidationFailure('Thiếu mã lịch hẹn.')));
    }
    if (!const {'cash', 'bank_transfer'}.contains(params.method)) {
      return Future.value(
        const Left(ValidationFailure('Phương thức thanh toán không hợp lệ.')),
      );
    }
    if (params.amount <= 0) {
      return Future.value(
        const Left(ValidationFailure('Số tiền phải lớn hơn 0.')),
      );
    }
    return _repository.markBookingPaid(params);
  }
}
