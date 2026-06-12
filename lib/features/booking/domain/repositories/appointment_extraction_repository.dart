import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';
import '../entities/appointment_extraction.dart';

abstract class AppointmentExtractionRepository {
  Future<Either<Failure, AppointmentExtraction>> extractFromText(String text);

  Future<Either<Failure, AppointmentExtraction>> extractFromImage(
    String imagePath,
  );
}
