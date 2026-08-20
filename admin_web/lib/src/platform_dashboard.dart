class PlatformDashboard {
  const PlatformDashboard({
    required this.generatedAt,
    required this.metrics,
    required this.recentBusinesses,
  });

  factory PlatformDashboard.fromMap(Map<Object?, Object?> data) {
    return PlatformDashboard(
      generatedAt: DateTime.fromMillisecondsSinceEpoch(
        _int(data['generatedAt']),
      ),
      metrics: PlatformMetrics.fromMap(
        Map<Object?, Object?>.from(data['metrics'] as Map),
      ),
      recentBusinesses: (data['recentBusinesses'] as List? ?? const [])
          .map(
            (item) => PlatformBusiness.fromMap(
              Map<Object?, Object?>.from(item as Map),
            ),
          )
          .toList(growable: false),
    );
  }

  final DateTime generatedAt;
  final PlatformMetrics metrics;
  final List<PlatformBusiness> recentBusinesses;
}

class PlatformMetrics {
  const PlatformMetrics({
    required this.totalBusinesses,
    required this.activeBusinesses,
    required this.suspendedBusinesses,
    required this.newBusinessesThisMonth,
    required this.totalUsers,
    required this.bookingsThisMonth,
    required this.totalPayments,
    required this.expiringSubscriptions,
  });

  factory PlatformMetrics.fromMap(Map<Object?, Object?> data) {
    return PlatformMetrics(
      totalBusinesses: _int(data['totalBusinesses']),
      activeBusinesses: _int(data['activeBusinesses']),
      suspendedBusinesses: _int(data['suspendedBusinesses']),
      newBusinessesThisMonth: _int(data['newBusinessesThisMonth']),
      totalUsers: _int(data['totalUsers']),
      bookingsThisMonth: _int(data['bookingsThisMonth']),
      totalPayments: _int(data['totalPayments']),
      expiringSubscriptions: _int(data['expiringSubscriptions']),
    );
  }

  final int totalBusinesses;
  final int activeBusinesses;
  final int suspendedBusinesses;
  final int newBusinessesThisMonth;
  final int totalUsers;
  final int bookingsThisMonth;
  final int totalPayments;
  final int expiringSubscriptions;
}

class PlatformBusiness {
  const PlatformBusiness({
    required this.id,
    required this.name,
    required this.ownerName,
    required this.ownerEmail,
    required this.planTier,
    required this.status,
    required this.createdAt,
    required this.planExpiresAt,
  });

  factory PlatformBusiness.fromMap(Map<Object?, Object?> data) {
    return PlatformBusiness(
      id: data['id'] as String? ?? '',
      name: data['name'] as String? ?? '',
      ownerName: data['ownerName'] as String? ?? '',
      ownerEmail: data['ownerEmail'] as String? ?? '',
      planTier: data['planTier'] as String? ?? 'basic',
      status: data['status'] as String? ?? 'active',
      createdAt: _date(data['createdAt']),
      planExpiresAt: _date(data['planExpiresAt']),
    );
  }

  final String id;
  final String name;
  final String ownerName;
  final String ownerEmail;
  final String planTier;
  final String status;
  final DateTime? createdAt;
  final DateTime? planExpiresAt;
}

int _int(Object? value) => value is num ? value.toInt() : 0;

DateTime? _date(Object? value) =>
    value is num ? DateTime.fromMillisecondsSinceEpoch(value.toInt()) : null;
