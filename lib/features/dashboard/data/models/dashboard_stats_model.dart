import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/dashboard_stats.dart';

class DashboardStatsModel extends DashboardStats {
  const DashboardStatsModel({
    required super.totalBookings,
    required super.completedBookings,
    required super.cancelledBookings,
    required super.noShowBookings,
    required super.upcomingBookings,
    required super.heatmap,
    required super.dailyTrend,
    required super.todayAppointments,
    required super.staffAvailability,
    required super.customerOverview,
  });

  static const _trendWindow = Duration(days: 6);

  /// Builds the stats from Firestore aggregate counts plus the raw booking
  /// documents within the heatmap window (used to bucket by weekday/period
  /// and by day for the bookings trend chart).
  factory DashboardStatsModel.fromAggregates({
    required int totalBookings,
    required int completedBookings,
    required int cancelledBookings,
    required int noShowBookings,
    required int upcomingBookings,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> heatmapDocs,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> todayBookingDocs,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>>
    inProgressBookingDocs,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> staffDocs,
    required int totalCustomers,
    required int returningCustomers,
    required int needsFollowUpCustomers,
  }) {
    final counts = <(int, BookingPeriod), int>{};
    final dailyCounts = <DateTime, int>{};
    for (final doc in heatmapDocs) {
      final startTime = (doc.data()['startTime'] as Timestamp?)?.toDate();
      if (startTime == null) continue;

      final key = (startTime.weekday, _periodOf(startTime.hour));
      counts[key] = (counts[key] ?? 0) + 1;

      final day = DateTime(startTime.year, startTime.month, startTime.day);
      dailyCounts[day] = (dailyCounts[day] ?? 0) + 1;
    }

    final heatmap = [
      for (final entry in counts.entries)
        BookingHeatmapCell(
          weekday: entry.key.$1,
          period: entry.key.$2,
          count: entry.value,
        ),
    ];

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final dailyTrend = [
      for (var offset = _trendWindow.inDays; offset >= 0; offset--)
        BookingTrendPoint(
          date: todayDate.subtract(Duration(days: offset)),
          count: dailyCounts[todayDate.subtract(Duration(days: offset))] ?? 0,
        ),
    ];

    final todayAppointments = [
      for (final doc in todayBookingDocs)
        if ((doc.data()['startTime'] as Timestamp?)?.toDate() != null)
          DashboardAppointment(
            id: doc.id,
            customerName: doc.data()['customerName'] as String? ?? 'Khách',
            staffName: doc.data()['staffName'] as String? ?? '',
            serviceName: doc.data()['serviceName'] as String? ?? '',
            startTime: (doc.data()['startTime'] as Timestamp).toDate(),
          ),
    ];

    final inSessionStaffIds = {
      for (final doc in inProgressBookingDocs) doc.data()['staffId'] as String?,
    };

    final staffAvailability = [
      for (final doc in staffDocs)
        if (doc.data()['role'] != 'owner')
          StaffAvailability(
            id: doc.id,
            name: doc.data()['name'] as String? ?? 'Nhân viên',
            inSession: inSessionStaffIds.contains(doc.id),
          ),
    ];

    final customerOverview = CustomerOverview(
      totalCustomers: totalCustomers,
      returningCustomers: returningCustomers,
      needsFollowUpCustomers: needsFollowUpCustomers,
    );

    return DashboardStatsModel(
      totalBookings: totalBookings,
      completedBookings: completedBookings,
      cancelledBookings: cancelledBookings,
      noShowBookings: noShowBookings,
      upcomingBookings: upcomingBookings,
      heatmap: heatmap,
      dailyTrend: dailyTrend,
      todayAppointments: todayAppointments,
      staffAvailability: staffAvailability,
      customerOverview: customerOverview,
    );
  }

  static BookingPeriod _periodOf(int hour) {
    if (hour < 12) return BookingPeriod.morning;
    if (hour < 18) return BookingPeriod.afternoon;
    return BookingPeriod.evening;
  }
}
