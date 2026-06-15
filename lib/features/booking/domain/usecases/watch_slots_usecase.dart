import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failure.dart';
import '../entities/slot.dart';
import '../repositories/booking_repository.dart';

class WatchSlotsParams {
  const WatchSlotsParams({
    required this.tenantId,
    required this.staffId,
    this.startDate,
    this.endDate,
  });

  final String tenantId;
  final String staffId;
  final DateTime? startDate;
  final DateTime? endDate;
}

@injectable
class WatchSlotsUseCase {
  const WatchSlotsUseCase(this._repository);

  final BookingRepository _repository;

  Stream<Either<Failure, List<Slot>>> call(WatchSlotsParams params) {
    if (params.tenantId.trim().isEmpty) {
      return Stream.value(const Left(ValidationFailure('Thiếu mã cơ sở.')));
    }
    if (params.staffId.trim().isEmpty) {
      return Stream.value(const Left(ValidationFailure('Thiếu mã nhân viên.')));
    }
    if (params.startDate != null &&
        params.endDate != null &&
        !params.endDate!.isAfter(params.startDate!)) {
      return Stream.value(
        const Left(ValidationFailure('Khoảng thời gian lọc không hợp lệ.')),
      );
    }
    return _repository.watchSlots(params);
  }
}
