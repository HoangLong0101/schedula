import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';
import '../entities/appointment_extraction.dart';
import '../entities/appointment_image_upload.dart';

abstract class AppointmentExtractionRepository {
  Future<Either<Failure, AppointmentExtraction>> extractFromText(String text);

  Future<Either<Failure, AppointmentExtraction>> extractFromImage(
    AppointmentImageUpload image,
  );
}
