import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:injectable/injectable.dart';

import '../../../booking/domain/entities/booking_status.dart';
import '../models/dashboard_stats_model.dart';
import '../../domain/entities/operational_report.dart';

@lazySingleton
class DashboardDataSource {
  DashboardDataSource(this._firestore);

  final FirebaseFirestore _firestore;

  static const _heatmapWindow = Duration(days: 30);
  static const _followUpWindow = Duration(days: 30);
  static const _activeBookingStatuses = [
    BookingStatus.pending,
    BookingStatus.confirmed,
    BookingStatus.inProgress,
  ];

  CollectionReference<Map<String, dynamic>> get _bookings =>
      _firestore.collection('bookings');

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  CollectionReference<Map<String, dynamic>> get _customers =>
      _firestore.collection('customers');

  CollectionReference<Map<String, dynamic>> get _tenantStatsDaily =>
      _firestore.collection('tenantStatsDaily');

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

    final results = await Future.wait<Object>([
      _safeCount(base.count()),
      _safeCount(
        base.where('status', isEqualTo: BookingStatus.completed.value).count(),
      ),
      _safeCount(
        base.where('status', isEqualTo: BookingStatus.cancelled.value).count(),
      ),
      _safeCount(
        base.where('status', isEqualTo: BookingStatus.noShow.value).count(),
      ),
      _safeCount(
        base
            .where(
              'status',
              whereIn: _activeBookingStatuses
                  .map((status) => status.value)
                  .toList(),
            )
            .where('startTime', isGreaterThanOrEqualTo: now)
            .count(),
      ),
      _safeDocs(
        base
            .where('startTime', isGreaterThanOrEqualTo: heatmapStart)
            .where('startTime', isLessThanOrEqualTo: now)
            .orderBy('startTime'),
      ),
      _safeDocs(_tenantStatsDaily.where('tenantId', isEqualTo: tenantId)),
      _safeDocs(
        base
            .where(
              'status',
              whereIn: _activeBookingStatuses
                  .map((status) => status.value)
                  .toList(),
            )
            .where('startTime', isGreaterThanOrEqualTo: startOfToday)
            .where('startTime', isLessThan: startOfTomorrow)
            .orderBy('startTime'),
      ),
      _safeDocs(_users.where('tenantId', isEqualTo: tenantId)),
      _safeCount(customersBase.count()),
      _safeCount(
        customersBase.where('visitCount', isGreaterThanOrEqualTo: 2).count(),
      ),
      _safeCount(
        customersBase.where('lastVisit', isLessThan: followUpCutoff).count(),
      ),
    ]);

    return DashboardStatsModel.fromAggregates(
      totalBookings: results[0] as int,
      completedBookings: results[1] as int,
      cancelledBookings: results[2] as int,
      noShowBookings: results[3] as int,
      upcomingBookings: results[4] as int,
      heatmapDocs:
          results[5] as List<QueryDocumentSnapshot<Map<String, dynamic>>>,
      tenantStatsDocs:
          results[6] as List<QueryDocumentSnapshot<Map<String, dynamic>>>,
      todayBookingDocs:
          results[7] as List<QueryDocumentSnapshot<Map<String, dynamic>>>,
      staffDocs:
          results[8] as List<QueryDocumentSnapshot<Map<String, dynamic>>>,
      totalCustomers: results[9] as int,
      returningCustomers: results[10] as int,
      needsFollowUpCustomers: results[11] as int,
    );
  }

  Future<List<ReportRecord>> fetchOperationalReports(String tenantId) async {
    final queries = await Future.wait([
      _firestore
          .collection('bookings')
          .where('tenantId', isEqualTo: tenantId)
          .get(),
      _firestore
          .collection('payments')
          .where('tenantId', isEqualTo: tenantId)
          .get(),
      _firestore
          .collection('customers')
          .where('tenantId', isEqualTo: tenantId)
          .get(),
      _firestore
          .collection('campaigns')
          .where('tenantId', isEqualTo: tenantId)
          .get(),
      _firestore
          .collection('users')
          .where('tenantId', isEqualTo: tenantId)
          .get(),
    ]);
    final records = <ReportRecord>[];

    for (final document in queries[0].docs) {
      final data = document.data();
      records.add(
        ReportRecord(
          id: document.id,
          kind: ReportKind.bookings,
          date: _date(data['startTime']),
          title: data['customerName'] as String? ?? document.id,
          subtitle: data['serviceName'] as String? ?? '',
          staffId: data['staffId'] as String? ?? '',
          serviceId: data['serviceId'] as String? ?? '',
          status: data['status'] as String? ?? '',
          paymentMethod: data['paymentMethod'] as String? ?? '',
          bookingId: document.id,
          amount: (data['paymentAmount'] as num?)?.round() ?? 0,
        ),
      );
    }
    for (final document in queries[1].docs) {
      final data = document.data();
      records.add(
        ReportRecord(
          id: document.id,
          kind: ReportKind.payments,
          date: _date(
            data['recordedAt'] ?? data['paidAt'] ?? data['createdAt'],
          ),
          title: data['type'] == 'subscription'
              ? data['planName'] as String? ?? 'Gói dịch vụ'
              : 'Thanh toán lịch hẹn',
          subtitle: data['reference'] as String? ?? '',
          status: data['status'] as String? ?? '',
          paymentMethod:
              data['method'] as String? ??
              (data['paymentLinkId'] == null ? '' : 'payos'),
          bookingId: data['bookingId'] as String? ?? '',
          amount: (data['amount'] as num?)?.round() ?? 0,
          reconciliationStatus:
              data['reconciliationStatus'] as String? ??
              (data['status'] == 'paid' ? 'matched' : 'pending'),
        ),
      );
    }
    for (final document in queries[2].docs) {
      final data = document.data();
      records.add(
        ReportRecord(
          id: document.id,
          kind: ReportKind.customers,
          date: _date(data['lastVisit'] ?? data['createdAt']),
          title: data['name'] as String? ?? '',
          subtitle: data['email'] as String? ?? '',
          status: data['emailOptedOut'] == true ? 'opted_out' : 'active',
          amount:
              (data['visitCount'] as num?)?.round() ??
              (data['totalVisits'] as num?)?.round() ??
              0,
        ),
      );
    }
    for (final document in queries[3].docs) {
      final data = document.data();
      records.add(
        ReportRecord(
          id: document.id,
          kind: ReportKind.campaigns,
          date: _date(data['createdAt']),
          title: data['templateId'] as String? ?? '',
          subtitle: 'Đã gửi ${data['sent'] ?? 0}, lỗi ${data['failed'] ?? 0}',
          status: data['status'] as String? ?? '',
          amount: (data['sent'] as num?)?.round() ?? 0,
        ),
      );
    }
    for (final document in queries[4].docs) {
      final data = document.data();
      final role = data['role'] as String? ?? '';
      if (role != 'staff' && role != 'receptionist') continue;
      records.add(
        ReportRecord(
          id: document.id,
          kind: ReportKind.staff,
          date: _date(data['createdAt']),
          title: data['name'] as String? ?? data['email'] as String? ?? '',
          subtitle: role,
          staffId: document.id,
          status: data['active'] == false ? 'inactive' : 'active',
        ),
      );
    }
    // ponytail: full tenant scan is intentional for small operators; move
    // filtering to report Functions when a tenant exceeds 10,000 records.
    return records;
  }

  DateTime _date(Object? value) => value is Timestamp
      ? value.toDate()
      : DateTime.fromMillisecondsSinceEpoch(0);

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
