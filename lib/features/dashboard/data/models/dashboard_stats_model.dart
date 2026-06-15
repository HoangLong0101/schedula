import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/dashboard_stats.dart';

class DashboardStatsModel extends DashboardStats {
  const DashboardStatsModel({
    required super.totalBookings,
    required super.completedBookings,
    required super.cancelledBookings,
    required super.noShowBookings,
    required super.upcomingBookings,
    required super.totalRevenue,
    required super.hourlyBookingCounts,
    required super.heatmap,
    required super.dailyTrend,
    required super.todayAppointments,
    required super.staffAvailability,
    required super.customerOverview,
  });

  static const _trendWindow = Duration(days: 6);

  factory DashboardStatsModel.fromAggregates({
    required int totalBookings,
    required int completedBookings,
    required int cancelledBookings,
    required int noShowBookings,
    required int upcomingBookings,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> heatmapDocs,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> tenantStatsDocs,
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
    final staffBookingCounts = <String, int>{};
    final hourlyBookingCounts = List<int>.filled(12, 0);
    for (final doc in heatmapDocs) {
      final startTime = _timestampFrom(doc.data()['startTime'])?.toDate();
      if (startTime == null) continue;

      if (startTime.hour >= 8 && startTime.hour <= 19) {
        hourlyBookingCounts[startTime.hour - 8] += 1;
      }

      final staffId = doc.data()['staffId'];
      if (staffId is String && staffId.isNotEmpty) {
        staffBookingCounts[staffId] = (staffBookingCounts[staffId] ?? 0) + 1;
      }

      final key = (startTime.weekday, _periodOf(startTime.hour));
      counts[key] = (counts[key] ?? 0) + 1;

      final day = DateTime(startTime.year, startTime.month, startTime.day);
      dailyCounts[day] = (dailyCounts[day] ?? 0) + 1;
    }

    var totalRevenue = 0;
    for (final doc in tenantStatsDocs) {
      final data = doc.data();
      totalRevenue += (data['revenue'] as num?)?.round() ?? 0;

      final timestamp = _timestampFrom(data['date']);
      final totalBookings = (data['totalBookings'] as num?)?.round();
      if (timestamp == null || totalBookings == null) continue;
      final date = timestamp.toDate();
      dailyCounts[DateTime(date.year, date.month, date.day)] = totalBookings;
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

    final todayAppointments = <DashboardAppointment>[];
    for (final doc in todayBookingDocs) {
      final data = doc.data();
      final startTime = _timestampFrom(data['startTime']);
      if (startTime == null) continue;

      todayAppointments.add(
        DashboardAppointment(
          id: doc.id,
          customerName: data['customerName'] as String? ?? 'Khach',
          staffName: data['staffName'] as String? ?? '',
          serviceName: data['serviceName'] as String? ?? '',
          startTime: startTime.toDate(),
        ),
      );
    }

    final inSessionStaffIds = {
      for (final doc in inProgressBookingDocs)
        if (doc.data()['staffId'] is String) doc.data()['staffId'] as String,
    };

    final staffAvailability = [
      for (final doc in staffDocs)
        if (doc.data()['role'] != 'owner')
          StaffAvailability(
            id: doc.id,
            name: doc.data()['name'] as String? ?? 'Nhan vien',
            inSession: inSessionStaffIds.contains(doc.id),
            bookingCount: staffBookingCounts[doc.id] ?? 0,
          ),
    ];

    return DashboardStatsModel(
      totalBookings: totalBookings,
      completedBookings: completedBookings,
      cancelledBookings: cancelledBookings,
      noShowBookings: noShowBookings,
      upcomingBookings: upcomingBookings,
      totalRevenue: totalRevenue,
      hourlyBookingCounts: hourlyBookingCounts,
      heatmap: heatmap,
      dailyTrend: dailyTrend,
      todayAppointments: todayAppointments,
      staffAvailability: staffAvailability,
      customerOverview: CustomerOverview(
        totalCustomers: totalCustomers,
        returningCustomers: returningCustomers,
        needsFollowUpCustomers: needsFollowUpCustomers,
      ),
    );
  }

  static Timestamp? _timestampFrom(Object? value) {
    return value is Timestamp ? value : null;
  }

  static BookingPeriod _periodOf(int hour) {
    if (hour < 12) return BookingPeriod.morning;
    if (hour < 18) return BookingPeriod.afternoon;
    return BookingPeriod.evening;
  }
}
