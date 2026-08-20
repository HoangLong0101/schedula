import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schedula_admin/src/admin_theme.dart';
import 'package:schedula_admin/src/dashboard_page.dart';
import 'package:schedula_admin/src/platform_dashboard.dart';

void main() {
  final dashboard = PlatformDashboard(
    generatedAt: DateTime(2026, 8, 9, 10),
    metrics: const PlatformMetrics(
      totalBusinesses: 12,
      activeBusinesses: 10,
      suspendedBusinesses: 2,
      newBusinessesThisMonth: 3,
      totalUsers: 28,
      bookingsThisMonth: 76,
      totalPayments: 15,
      expiringSubscriptions: 2,
    ),
    recentBusinesses: [
      PlatformBusiness(
        id: 'tenant-1',
        name: 'An Nhiên Spa',
        ownerName: 'Nguyễn An',
        ownerEmail: 'an@example.com',
        planTier: 'basic',
        status: 'active',
        createdAt: DateTime(2026, 8, 1),
        planExpiresAt: DateTime(2026, 9, 1),
      ),
    ],
  );

  Future<void> render(WidgetTester tester, Size size) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        theme: AdminTheme.light,
        home: DashboardPage(
          future: Future.value(dashboard),
          onRefresh: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders live dashboard content at desktop width', (tester) async {
    await render(tester, const Size(1280, 900));

    expect(find.text('Tổng quan hệ thống'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('An Nhiên Spa'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('collapses dashboard without overflow on narrow screens', (
    tester,
  ) async {
    await render(tester, const Size(430, 900));

    expect(find.text('Tổng quan hệ thống'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
