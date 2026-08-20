import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:schedula/features/dashboard/data/datasources/dashboard_datasource.dart';
import 'package:schedula/features/dashboard/data/repositories/dashboard_repository_impl.dart';
import 'package:schedula/features/dashboard/data/models/dashboard_stats_model.dart';
import 'package:schedula/features/dashboard/domain/entities/dashboard_stats.dart';
import 'package:schedula/features/dashboard/domain/entities/operational_report.dart';
import 'package:schedula/features/dashboard/domain/usecases/get_dashboard_stats_usecase.dart';

class FakeDashboardDataSource implements DashboardDataSource {
  int fetchCount = 0;
  DashboardStatsModel stats = _stats(0);
  Completer<DashboardStatsModel>? blocker;

  @override
  Future<DashboardStatsModel> fetchStats(String tenantId) {
    fetchCount++;
    return blocker?.future ?? Future.value(stats);
  }

  @override
  Future<List<ReportRecord>> fetchOperationalReports(String tenantId) async =>
      const [];
}

DashboardStatsModel _stats(int totalBookings) => DashboardStatsModel(
  totalBookings: totalBookings,
  completedBookings: 0,
  cancelledBookings: 0,
  noShowBookings: 0,
  upcomingBookings: 0,
  totalRevenue: 0,
  hourlyBookingCounts: const [],
  heatmap: const [],
  dailyTrend: const [],
  todayAppointments: const [],
  staffAvailability: const [],
  customerOverview: CustomerOverview.empty,
);

void main() {
  test('reuses cached dashboard stats until a force refresh', () async {
    final source = FakeDashboardDataSource()..stats = _stats(1);
    final repository = DashboardRepositoryImpl(source);

    final first = await repository.getDashboardStats(
      const GetDashboardStatsParams(tenantId: 'tenant-1'),
    );
    source.stats = _stats(2);
    final cached = await repository.getDashboardStats(
      const GetDashboardStatsParams(tenantId: 'tenant-1'),
    );
    final refreshed = await repository.getDashboardStats(
      const GetDashboardStatsParams(tenantId: 'tenant-1', forceRefresh: true),
    );

    expect(source.fetchCount, 2);
    expect(first.getOrElse(() => DashboardStats.empty).totalBookings, 1);
    expect(cached.getOrElse(() => DashboardStats.empty).totalBookings, 1);
    expect(refreshed.getOrElse(() => DashboardStats.empty).totalBookings, 2);
  });

  test('coalesces concurrent dashboard requests for one tenant', () async {
    final source = FakeDashboardDataSource()
      ..blocker = Completer<DashboardStatsModel>();
    final repository = DashboardRepositoryImpl(source);

    final first = repository.getDashboardStats(
      const GetDashboardStatsParams(tenantId: 'tenant-1'),
    );
    final second = repository.getDashboardStats(
      const GetDashboardStatsParams(tenantId: 'tenant-1'),
    );

    expect(source.fetchCount, 1);
    source.blocker!.complete(_stats(3));
    await Future.wait([first, second]);
    expect(source.fetchCount, 1);
  });
}
