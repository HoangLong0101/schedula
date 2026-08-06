import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failure.dart';
import '../../domain/entities/dashboard_stats.dart';
import '../../domain/entities/operational_report.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../../domain/usecases/get_dashboard_stats_usecase.dart';
import '../datasources/dashboard_datasource.dart';

@LazySingleton(as: DashboardRepository)
class DashboardRepositoryImpl implements DashboardRepository {
  DashboardRepositoryImpl(this._dataSource);

  final DashboardDataSource _dataSource;

  @override
  Future<Either<Failure, DashboardStats>> getDashboardStats(
    GetDashboardStatsParams params,
  ) async {
    try {
      final stats = await _dataSource.fetchStats(params.tenantId);
      return Right(stats);
    } catch (_) {
      return const Left(ServerFailure('Không thể tải dữ liệu thống kê.'));
    }
  }

  @override
  Future<Either<Failure, List<ReportRecord>>> getOperationalReports(
    String tenantId,
  ) async {
    try {
      return Right(await _dataSource.fetchOperationalReports(tenantId));
    } catch (_) {
      return const Left(ServerFailure('Không thể tải báo cáo vận hành.'));
    }
  }
}
