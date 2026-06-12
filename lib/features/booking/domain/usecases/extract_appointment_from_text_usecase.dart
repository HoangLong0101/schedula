import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failure.dart';
import '../entities/appointment_extraction.dart';
import '../repositories/appointment_extraction_repository.dart';

@injectable
class ExtractAppointmentFromTextUseCase {
  const ExtractAppointmentFromTextUseCase(this._repository);

  final AppointmentExtractionRepository _repository;

  Future<Either<Failure, AppointmentExtraction>> call(String text) {
    return _repository.extractFromText(text);
  }
}
