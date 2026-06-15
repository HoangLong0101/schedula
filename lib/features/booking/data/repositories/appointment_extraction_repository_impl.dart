import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failure.dart';
import '../../domain/entities/appointment_extraction.dart';
import '../../domain/entities/appointment_image_upload.dart';
import '../../domain/repositories/appointment_extraction_repository.dart';
import '../datasources/booking_cascade_api_datasource.dart';

@LazySingleton(as: AppointmentExtractionRepository)
class AppointmentExtractionRepositoryImpl
    implements AppointmentExtractionRepository {
  const AppointmentExtractionRepositoryImpl(this._dataSource);

  final BookingCascadeApiDataSource _dataSource;

  @override
  Future<Either<Failure, AppointmentExtraction>> extractFromText(String text) {
    return _guard(() => _dataSource.extractText(text));
  }

  @override
  Future<Either<Failure, AppointmentExtraction>> extractFromImage(
    AppointmentImageUpload image,
  ) {
    return _guard(() => _dataSource.scanAppointmentImage(image));
  }

  Future<Either<Failure, AppointmentExtraction>> _guard(
    Future<Map<String, dynamic>> Function() request,
  ) async {
    try {
      final fields = await request();
      return Right(AppointmentExtraction(fields: fields));
    } on BookingCascadeApiNotConfiguredException catch (error) {
      return Left(ValidationFailure(error.message));
    } on BookingCascadeApiException catch (error) {
      return Left(ServerFailure(error.message));
    } catch (error) {
      return Left(ServerFailure(error.toString()));
    }
  }
}
