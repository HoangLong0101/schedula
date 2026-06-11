import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';
import '../entities/dashboard_stats.dart';
import '../usecases/get_dashboard_stats_usecase.dart';

abstract class DashboardRepository {
  Future<Either<Failure, DashboardStats>> getDashboardStats(
    GetDashboardStatsParams params,
  );
}
