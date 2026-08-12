import 'package:flutter_test/flutter_test.dart';
import 'package:schedula_admin/src/platform_dashboard.dart';

void main() {
  test('parses platform dashboard callable response', () {
    final dashboard = PlatformDashboard.fromMap({
      'generatedAt': 1000,
      'metrics': {
        'totalBusinesses': 4,
        'activeBusinesses': 3,
        'suspendedBusinesses': 1,
        'newBusinessesThisMonth': 2,
        'totalUsers': 8,
        'bookingsThisMonth': 12,
        'totalPayments': 5,
        'expiringSubscriptions': 1,
      },
      'recentBusinesses': [
        {
          'id': 'tenant-1',
          'name': 'An Nhiên Spa',
          'ownerName': 'Nguyễn An',
          'ownerEmail': 'an@example.com',
          'planTier': 'basic',
          'status': 'active',
          'createdAt': 1000,
          'planExpiresAt': null,
        },
      ],
    });

    expect(dashboard.metrics.totalBusinesses, 4);
    expect(dashboard.recentBusinesses.single.name, 'An Nhiên Spa');
  });
}
