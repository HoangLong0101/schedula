import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failure.dart';
import '../entities/operational_report.dart';
import '../repositories/dashboard_repository.dart';

@injectable
class GetOperationalReportsUseCase {
  const GetOperationalReportsUseCase(this._repository);

  final DashboardRepository _repository;

  Future<Either<Failure, List<ReportRecord>>> call(String tenantId) {
    if (tenantId.trim().isEmpty) {
      return Future.value(const Left(ValidationFailure('Thiếu mã cơ sở.')));
    }
    return _repository.getOperationalReports(tenantId);
  }
}
