import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failure.dart';
import '../entities/appointment_extraction.dart';
import '../entities/appointment_image_upload.dart';
import '../repositories/appointment_extraction_repository.dart';

@injectable
class ScanAppointmentImageUseCase {
  const ScanAppointmentImageUseCase(this._repository);

  final AppointmentExtractionRepository _repository;

  Future<Either<Failure, AppointmentExtraction>> call(
    AppointmentImageUpload image,
  ) {
    if (image.bytes.isEmpty) {
      return Future.value(
        const Left(ValidationFailure('Ảnh lịch hẹn không hợp lệ.')),
      );
    }
    if (image.filename.trim().isEmpty) {
      return Future.value(
        const Left(ValidationFailure('Thiếu tên tệp ảnh lịch hẹn.')),
      );
    }
    return _repository.extractFromImage(image);
  }
}
