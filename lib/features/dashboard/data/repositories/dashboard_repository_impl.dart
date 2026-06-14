import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failure.dart';
import '../../domain/entities/dashboard_stats.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../../domain/usecases/get_dashboard_stats_usecase.dart';
import '../datasources/dashboard_datasource.dart';

@LazySingleton(as: DashboardRepository)
class DashboardRepositoryImpl implements DashboardRepository {
  DashboardRepositoryImpl(this._dataSource);

  final DashboardDataSource _dataSource;
  final Map<String, _DashboardStatsCacheEntry> _cache = {};

  static const _cacheTtl = Duration(minutes: 2);

  @override
  Future<Either<Failure, DashboardStats>> getDashboardStats(
    GetDashboardStatsParams params,
  ) async {
    try {
      final cached = _cache[params.tenantId];
      if (!params.forceRefresh &&
          cached != null &&
          DateTime.now().difference(cached.cachedAt) < _cacheTtl) {
        return Right(cached.stats);
      }

      final stats = await _dataSource.fetchStats(params.tenantId);
      _cache[params.tenantId] = _DashboardStatsCacheEntry(
        stats: stats,
        cachedAt: DateTime.now(),
      );
      return Right(stats);
    } catch (error) {
      return Left(ServerFailure(error.toString()));
    }
  }
}

class _DashboardStatsCacheEntry {
  const _DashboardStatsCacheEntry({
    required this.stats,
    required this.cachedAt,
  });

  final DashboardStats stats;
  final DateTime cachedAt;
}
