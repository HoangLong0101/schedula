import 'package:flutter_test/flutter_test.dart';
import 'package:dartz/dartz.dart';

import 'package:schedula/features/dashboard/domain/entities/dashboard_stats.dart';
import 'package:schedula/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:schedula/features/dashboard/domain/usecases/get_dashboard_stats_usecase.dart';
import 'package:schedula/core/errors/failure.dart';

class FakeDashboardRepository implements DashboardRepository {
  FakeDashboardRepository({this.toReturn, this.shouldFail = false});

  final DashboardStats? toReturn;
  final bool shouldFail;

  @override
  Future<Either<Failure, DashboardStats>> getDashboardStats(
    GetDashboardStatsParams params,
  ) async {
    if (shouldFail) {
      return Left(ServerFailure('failed'));
    }
    return Right(toReturn ?? DashboardStats.empty);
  }
}

void main() {
  group('GetDashboardStatsUseCase', () {
    test('returns DashboardStats on success', () async {
      final stats = DashboardStats(
        totalBookings: 10,
        completedBookings: 6,
        cancelledBookings: 2,
        noShowBookings: 1,
        upcomingBookings: 3,
        totalRevenue: 1200000,
        hourlyBookingCounts: const [0, 4, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        heatmap: const [
          BookingHeatmapCell(
            weekday: DateTime.monday,
            period: BookingPeriod.morning,
            count: 4,
          ),
        ],
        dailyTrend: [BookingTrendPoint(date: DateTime(2026, 6, 10), count: 5)],
        todayAppointments: [
          DashboardAppointment(
            id: 'b1',
            customerName: 'Khách A',
            staffName: 'Nhân viên A',
            serviceName: 'Cắt tóc',
            startTime: DateTime(2026, 6, 10, 9),
          ),
        ],
        staffAvailability: const [
          StaffAvailability(
            id: 's1',
            name: 'Nhân viên A',
            inSession: true,
            bookingCount: 4,
          ),
        ],
        customerOverview: const CustomerOverview(
          totalCustomers: 8,
          returningCustomers: 3,
          needsFollowUpCustomers: 2,
        ),
      );
      final fakeRepo = FakeDashboardRepository(toReturn: stats);
      final usecase = GetDashboardStatsUseCase(fakeRepo);

      final result = await usecase(
        const GetDashboardStatsParams(tenantId: 't1'),
      );

      expect(result.isRight(), true);
      result.fold((l) => fail('expected right'), (value) {
        expect(value.totalBookings, 10);
        expect(value.totalRevenue, 1200000);
        expect(value.cancellationRate, 0.2);
        expect(value.peakHeatmapCount, 4);
        expect(value.peakDailyTrendCount, 5);
        expect(value.todayAppointments.length, 1);
        expect(value.staffAvailability.single.inSession, true);
        expect(value.customerOverview.totalCustomers, 8);
      });
    });

    test('returns failure when repo fails', () async {
      final fakeRepo = FakeDashboardRepository(shouldFail: true);
      final usecase = GetDashboardStatsUseCase(fakeRepo);

      final result = await usecase(
        const GetDashboardStatsParams(tenantId: 't1'),
      );

      expect(result.isLeft(), true);
    });

    test('cancellationRate is 0 when there are no bookings', () {
      expect(DashboardStats.empty.cancellationRate, 0);
      expect(DashboardStats.empty.peakHeatmapCount, 0);
      expect(DashboardStats.empty.peakDailyTrendCount, 0);
      expect(DashboardStats.empty.todayAppointments, isEmpty);
      expect(DashboardStats.empty.staffAvailability, isEmpty);
      expect(DashboardStats.empty.customerOverview, CustomerOverview.empty);
    });
  });
}
