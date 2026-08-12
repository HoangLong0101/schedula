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
      _safeReportDocs(
        _firestore
            .collection('bookings')
            .where('tenantId', isEqualTo: tenantId),
      ),
      _safeReportDocs(
        _firestore
            .collection('payments')
            .where('tenantId', isEqualTo: tenantId),
      ),
      _safeReportDocs(
        _firestore
            .collection('customers')
            .where('tenantId', isEqualTo: tenantId),
      ),
      _safeReportDocs(
        _firestore
            .collection('campaigns')
            .where('tenantId', isEqualTo: tenantId),
      ),
      _safeReportDocs(
        _firestore.collection('users').where('tenantId', isEqualTo: tenantId),
      ),
    ]);
    final records = <ReportRecord>[];

    for (final document in queries[0]) {
      final data = document.data();
      records.add(
        ReportRecord(
          id: document.id,
          kind: ReportKind.bookings,
          date: _date(data['startTime']),
          title: _text(data['customerName'], fallback: document.id),
          subtitle: _text(data['serviceName']),
          staffId: _text(data['staffId']),
          serviceId: _text(data['serviceId']),
          status: _text(data['status']),
          paymentMethod: _text(data['paymentMethod']),
          bookingId: document.id,
          amount: _integer(data['paymentAmount']),
        ),
      );
    }
    for (final document in queries[1]) {
      final data = document.data();
      final paymentMethod = _text(data['method']);
      final reconciliationStatus = _text(data['reconciliationStatus']);
      records.add(
        ReportRecord(
          id: document.id,
          kind: ReportKind.payments,
          date: _date(
            data['recordedAt'] ?? data['paidAt'] ?? data['createdAt'],
          ),
          title: data['type'] == 'subscription'
              ? _text(data['planName'], fallback: 'Gói dịch vụ')
              : 'Thanh toán lịch hẹn',
          subtitle: _text(data['reference']),
          status: _text(data['status']),
          paymentMethod: paymentMethod.isNotEmpty
              ? paymentMethod
              : (data['paymentLinkId'] == null ? '' : 'payos'),
          bookingId: _text(data['bookingId']),
          amount: _integer(data['amount']),
          reconciliationStatus: reconciliationStatus.isNotEmpty
              ? reconciliationStatus
              : (data['status'] == 'paid' ? 'matched' : 'pending'),
        ),
      );
    }
    for (final document in queries[2]) {
      final data = document.data();
      final visitCount = _integer(data['visitCount']);
      records.add(
        ReportRecord(
          id: document.id,
          kind: ReportKind.customers,
          date: _date(data['lastVisit'] ?? data['createdAt']),
          title: _text(data['name']),
          subtitle: _text(data['email']),
          status: data['emailOptedOut'] == true ? 'opted_out' : 'active',
          amount: visitCount != 0 ? visitCount : _integer(data['totalVisits']),
        ),
      );
    }
    for (final document in queries[3]) {
      final data = document.data();
      records.add(
        ReportRecord(
          id: document.id,
          kind: ReportKind.campaigns,
          date: _date(data['createdAt']),
          title: _text(data['templateId']),
          subtitle: 'Đã gửi ${data['sent'] ?? 0}, lỗi ${data['failed'] ?? 0}',
          status: _text(data['status']),
          amount: _integer(data['sent']),
        ),
      );
    }
    for (final document in queries[4]) {
      final data = document.data();
      final role = _text(data['role']);
      if (role != 'staff' && role != 'receptionist') continue;
      final name = _text(data['name']);
      records.add(
        ReportRecord(
          id: document.id,
          kind: ReportKind.staff,
          date: _date(data['createdAt']),
          title: name.isNotEmpty ? name : _text(data['email']),
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
      : value is DateTime
      ? value
      : DateTime.fromMillisecondsSinceEpoch(0);

  String _text(Object? value, {String fallback = ''}) =>
      value is String && value.isNotEmpty ? value : fallback;

  int _integer(Object? value) =>
      value is num ? value.round() : int.tryParse(value?.toString() ?? '') ?? 0;

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

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _safeReportDocs(
    Query<Map<String, dynamic>> query,
  ) async {
    try {
      return (await query.get()).docs;
    } on FirebaseException {
      return const [];
    } on PlatformException {
      return const [];
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
