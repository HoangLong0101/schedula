import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';

import '../../../booking/domain/entities/booking_status.dart';
import '../models/dashboard_stats_model.dart';

@lazySingleton
class DashboardDataSource {
  DashboardDataSource(this._firestore);

  final FirebaseFirestore _firestore;

  static const _heatmapWindow = Duration(days: 30);
  static const _followUpWindow = Duration(days: 30);

  CollectionReference<Map<String, dynamic>> get _bookings =>
      _firestore.collection('bookings');

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  CollectionReference<Map<String, dynamic>> get _customers =>
      _firestore.collection('customers');

  Future<DashboardStatsModel> fetchStats(String tenantId) async {
    final base = _bookings.where('tenantId', isEqualTo: tenantId);
    final customersBase = _customers.where('tenantId', isEqualTo: tenantId);
    final now = Timestamp.now();
    final heatmapStart = Timestamp.fromDate(
      DateTime.now().subtract(_heatmapWindow),
    );
    final todayStart = DateTime.now();
    final startOfToday = Timestamp.fromDate(
      DateTime(todayStart.year, todayStart.month, todayStart.day),
    );
    final startOfTomorrow = Timestamp.fromDate(
      DateTime(
        todayStart.year,
        todayStart.month,
        todayStart.day,
      ).add(const Duration(days: 1)),
    );
    final followUpCutoff = Timestamp.fromDate(
      DateTime.now().subtract(_followUpWindow),
    );

    final results = await Future.wait<dynamic>([
      base.count().get(),
      base
          .where('status', isEqualTo: BookingStatus.completed.value)
          .count()
          .get(),
      base
          .where('status', isEqualTo: BookingStatus.cancelled.value)
          .count()
          .get(),
      base.where('status', isEqualTo: BookingStatus.noShow.value).count().get(),
      base.where('startTime', isGreaterThanOrEqualTo: now).count().get(),
      base
          .where('startTime', isGreaterThanOrEqualTo: heatmapStart)
          .where('startTime', isLessThanOrEqualTo: now)
          .orderBy('startTime')
          .get(),
      base
          .where('startTime', isGreaterThanOrEqualTo: startOfToday)
          .where('startTime', isLessThan: startOfTomorrow)
          .orderBy('startTime')
          .get(),
      base.where('status', isEqualTo: BookingStatus.inProgress.value).get(),
      _users.where('tenantId', isEqualTo: tenantId).get(),
      customersBase.count().get(),
      customersBase
          .where('visitCount', isGreaterThanOrEqualTo: 2)
          .count()
          .get(),
      customersBase
          .where('lastVisit', isLessThan: followUpCutoff)
          .count()
          .get(),
    ]);

    final heatmapSnapshot = results[5] as QuerySnapshot<Map<String, dynamic>>;
    final todayBookingsSnapshot =
        results[6] as QuerySnapshot<Map<String, dynamic>>;
    final inProgressSnapshot =
        results[7] as QuerySnapshot<Map<String, dynamic>>;
    final staffSnapshot = results[8] as QuerySnapshot<Map<String, dynamic>>;

    return DashboardStatsModel.fromAggregates(
      totalBookings: (results[0] as AggregateQuerySnapshot).count ?? 0,
      completedBookings: (results[1] as AggregateQuerySnapshot).count ?? 0,
      cancelledBookings: (results[2] as AggregateQuerySnapshot).count ?? 0,
      noShowBookings: (results[3] as AggregateQuerySnapshot).count ?? 0,
      upcomingBookings: (results[4] as AggregateQuerySnapshot).count ?? 0,
      heatmapDocs: heatmapSnapshot.docs,
      todayBookingDocs: todayBookingsSnapshot.docs,
      inProgressBookingDocs: inProgressSnapshot.docs,
      staffDocs: staffSnapshot.docs,
      totalCustomers: (results[9] as AggregateQuerySnapshot).count ?? 0,
      returningCustomers: (results[10] as AggregateQuerySnapshot).count ?? 0,
      needsFollowUpCustomers:
          (results[11] as AggregateQuerySnapshot).count ?? 0,
    );
  }
}
