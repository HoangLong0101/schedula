import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
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

    return DashboardStatsModel.fromAggregates(
      totalBookings: await _safeCount(base.count()),
      completedBookings: await _safeCount(
        base.where('status', isEqualTo: BookingStatus.completed.value).count(),
      ),
      cancelledBookings: await _safeCount(
        base.where('status', isEqualTo: BookingStatus.cancelled.value).count(),
      ),
      noShowBookings: await _safeCount(
        base.where('status', isEqualTo: BookingStatus.noShow.value).count(),
      ),
      upcomingBookings: await _safeCount(
        base.where('startTime', isGreaterThanOrEqualTo: now).count(),
      ),
      heatmapDocs: await _safeDocs(
        base
            .where('startTime', isGreaterThanOrEqualTo: heatmapStart)
            .where('startTime', isLessThanOrEqualTo: now)
            .orderBy('startTime'),
      ),
      todayBookingDocs: await _safeDocs(
        base
            .where('startTime', isGreaterThanOrEqualTo: startOfToday)
            .where('startTime', isLessThan: startOfTomorrow)
            .orderBy('startTime'),
      ),
      inProgressBookingDocs: await _safeDocs(
        base.where('status', isEqualTo: BookingStatus.inProgress.value),
      ),
      staffDocs: await _safeDocs(_users.where('tenantId', isEqualTo: tenantId)),
      totalCustomers: await _safeCount(customersBase.count()),
      returningCustomers: await _safeCount(
        customersBase.where('visitCount', isGreaterThanOrEqualTo: 2).count(),
      ),
      needsFollowUpCustomers: await _safeCount(
        customersBase.where('lastVisit', isLessThan: followUpCutoff).count(),
      ),
    );
  }

  Future<int> _safeCount(AggregateQuery query) async {
    try {
      final snapshot = await query.get();
      return snapshot.count ?? 0;
    } catch (error) {
      if (_isPermissionDenied(error)) {
        return 0;
      }
      rethrow;
    }
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _safeDocs(
    Query<Map<String, dynamic>> query,
  ) async {
    try {
      final snapshot = await query.get();
      return snapshot.docs;
    } catch (error) {
      if (_isPermissionDenied(error)) {
        return const [];
      }
      rethrow;
    }
  }

  bool _isPermissionDenied(Object error) {
    return error is FirebaseException && error.code == 'permission-denied' ||
        error is PlatformException &&
            (error.code == 'permission-denied' ||
                (error.message?.contains('PERMISSION_DENIED') ?? false) ||
                (error.message?.contains('permission-denied') ?? false));
  }
}
