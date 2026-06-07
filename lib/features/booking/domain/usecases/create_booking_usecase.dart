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
    return _repository.createBooking(params);
  }
}
