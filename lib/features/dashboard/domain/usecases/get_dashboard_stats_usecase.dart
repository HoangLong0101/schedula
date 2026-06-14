import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failure.dart';
import '../entities/dashboard_stats.dart';
import '../repositories/dashboard_repository.dart';

class GetDashboardStatsParams {
  const GetDashboardStatsParams({
    required this.tenantId,
    this.forceRefresh = false,
  });

  final String tenantId;
  final bool forceRefresh;
}

@injectable
class GetDashboardStatsUseCase {
  const GetDashboardStatsUseCase(this._repository);

  final DashboardRepository _repository;

  Future<Either<Failure, DashboardStats>> call(GetDashboardStatsParams params) {
    return _repository.getDashboardStats(params);
  }
}
