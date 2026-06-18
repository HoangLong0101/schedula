import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failure.dart';
import '../entities/booking.dart';
import '../entities/booking_status.dart';
import '../repositories/booking_repository.dart';

class CreateBookingParams {
  const CreateBookingParams({
    required this.tenantId,
    required this.staffId,
    required this.customerId,
    required this.serviceId,
    required this.startTime,
    required this.endTime,
    required this.status,
    this.notes,
    this.createdBy,
    this.customerName,
    this.staffName,
    this.serviceName,
  });

  final String tenantId;
  final String staffId;
  final String customerId;
  final String serviceId;
  final DateTime startTime;
  final DateTime endTime;
  final BookingStatus status;
  final String? notes;
  final String? createdBy;
  final String? customerName;
  final String? staffName;
  final String? serviceName;
}

@injectable
class CreateBookingUseCase {
  const CreateBookingUseCase(this._repository);

  final BookingRepository _repository;

  Future<Either<Failure, Booking>> call(CreateBookingParams params) {
    if (params.tenantId.trim().isEmpty) {
      return Future.value(const Left(ValidationFailure('Thiếu mã cơ sở.')));
    }
    if (params.serviceId.trim().isEmpty) {
      return Future.value(const Left(ValidationFailure('Vui lòng chọn dịch vụ.')));
    }
    if (params.staffId.trim().isEmpty) {
      return Future.value(const Left(ValidationFailure('Vui lòng chọn nhân viên phụ trách.')));
    }
    if (params.customerId.trim().isEmpty &&
        (params.customerName == null || params.customerName!.trim().isEmpty)) {
      return Future.value(const Left(ValidationFailure('Vui lòng nhập khách hàng.')));
    }
    if (!params.endTime.isAfter(params.startTime)) {
      return Future.value(
        const Left(ValidationFailure('Giờ kết thúc phải sau giờ bắt đầu.')),
      );
    }
    return _repository.createBooking(params);
  }
}
