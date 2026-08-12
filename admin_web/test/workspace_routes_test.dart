import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schedula_admin/src/admin_services.dart';
import 'package:schedula_admin/src/admin_theme.dart';
import 'package:schedula_admin/src/platform_workspace.dart';
import 'package:schedula_admin/src/workspace_pages.dart';

void main() {
  final workspace = PlatformWorkspace.fromMap({
    'generatedAt': 1000,
    'actor': {
      'uid': 'admin-1',
      'email': 'admin@schedula.vn',
      'role': 'super_admin',
      'permissions': [
        'dashboard.read',
        'business.read',
        'business.write',
        'transaction.read',
        'transaction.reconcile',
        'subscription.write',
        'plan.write',
        'analytics.read',
        'report.export',
        'monitoring.read',
        'admin.write',
      ],
    },
    'metrics': {
      'totalRevenue': 699000,
      'mrr': 699000,
      'arr': 8388000,
      'arpu': 699000,
      'activeBusinesses': 1,
      'newBusinesses': 1,
      'activeSubscriptions': 1,
      'transactionSuccessRate': 100,
      'topProvince': 'TP. Hồ Chí Minh',
    },
    'businesses': [
      {
        'id': 'tenant-1',
        'name': 'An Nhiên Spa',
        'ownerName': 'Nguyễn An',
        'ownerEmail': 'an@example.com',
        'businessType': 'Spa',
        'province': 'TP. Hồ Chí Minh',
        'planTier': 'pro',
        'subscriptionStatus': 'active',
        'status': 'active',
        'createdAt': 1000,
      },
    ],
    'transactions': [
      {
        'id': 'payment-1',
        'orderCode': 123,
        'tenantId': 'tenant-1',
        'businessName': 'An Nhiên Spa',
        'province': 'TP. Hồ Chí Minh',
        'planTier': 'pro',
        'amount': 699000,
        'provider': 'payos',
        'status': 'paid',
        'reconciliationStatus': 'verified',
        'createdAt': 1000,
      },
    ],
    'plans': [
      {
        'id': 'pro',
        'name': 'Schedula Pro',
        'price': 699000,
        'yearlyPrice': 6990000,
        'trialDays': 14,
        'features': ['Báo cáo'],
        'status': 'active',
      },
    ],
    'analytics': {
      'revenueByDay': {'2026-08-10': 699000},
      'revenueByPlan': {'pro': 699000},
      'revenueByProvince': {'TP. Hồ Chí Minh': 699000},
      'transactionStatus': {'paid': 1},
      'businessesByProvince': {'TP. Hồ Chí Minh': 1},
    },
    'auditEvents': [
      {
        'id': 'audit-1',
        'action': 'subscription.extend',
        'actorEmail': 'admin@schedula.vn',
        'entityType': 'tenant',
        'entityId': 'tenant-1',
        'createdAt': 1000,
      },
    ],
    'webhookEvents': [
      {'id': 'hook-1', 'status': 'verified', 'createdAt': 1000},
    ],
    'admins': [
      {
        'id': 'admin-1',
        'email': 'admin@schedula.vn',
        'role': 'super_admin',
        'active': true,
      },
    ],
    'limits': const {},
  });
  final api = AdminApi();

  Future<void> render(WidgetTester tester, Widget child) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 1100);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        theme: AdminTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: child,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  testWidgets('all operational sections render without placeholders', (
    tester,
  ) async {
    final pages = <Widget>[
      DashboardWorkspace(data: workspace),
      BusinessesWorkspace(data: workspace, api: api, onChanged: () {}),
      TransactionsWorkspace(data: workspace, api: api, onChanged: () {}),
      SubscriptionsWorkspace(data: workspace, api: api, onChanged: () {}),
      RevenueWorkspace(data: workspace),
      ProvinceWorkspace(data: workspace),
      PlansWorkspace(data: workspace, api: api, onChanged: () {}),
      MonitoringWorkspace(data: workspace),
      ReportsWorkspace(data: workspace, filter: WorkspaceFilter.last30Days()),
      AdminUsersWorkspace(data: workspace, api: api, onChanged: () {}),
    ];

    for (final page in pages) {
      await render(tester, page);
    }
  });

  testWidgets('dashboard groups related metrics with hover explanations', (
    tester,
  ) async {
    await render(tester, DashboardWorkspace(data: workspace));

    expect(find.text('Doanh thu và hiệu quả giao dịch'), findsOneWidget);
    expect(find.text('Doanh nghiệp, mức sử dụng và khu vực'), findsOneWidget);
    expect(find.byType(Tooltip), findsWidgets);
  });

  testWidgets('subscription table remains usable on a narrow viewport', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(680, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        theme: AdminTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SubscriptionsWorkspace(
              data: workspace,
              api: api,
              onChanged: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('An Nhiên Spa'), findsOneWidget);
  });

  testWidgets('plans are ordered from lowest to highest monthly price', (
    tester,
  ) async {
    final plans = PlatformWorkspace.fromMap({
      'plans': [
        {
          'id': 'enterprise',
          'name': 'Doanh Nghiệp',
          'price': 1499000,
          'features': ['Không giới hạn lịch hẹn'],
          'status': 'active',
        },
        {
          'id': 'basic',
          'name': 'Cơ Bản',
          'price': 299000,
          'features': ['50 lịch hẹn mỗi tháng'],
          'status': 'active',
        },
        {
          'id': 'pro',
          'name': 'Chuyên Nghiệp',
          'price': 699000,
          'features': ['Báo cáo nâng cao'],
          'status': 'active',
        },
      ],
    });

    await render(
      tester,
      PlansWorkspace(data: plans, api: api, onChanged: () {}),
    );

    final basicX = tester.getTopLeft(find.text('Cơ Bản')).dx;
    final proX = tester.getTopLeft(find.text('Chuyên Nghiệp')).dx;
    final enterpriseX = tester.getTopLeft(find.text('Doanh Nghiệp')).dx;
    expect(basicX, lessThan(proX));
    expect(proX, lessThan(enterpriseX));
    expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(3));
  });

  testWidgets('filter dropdown opens without covering the filter control', (
    tester,
  ) async {
    await render(
      tester,
      GlobalFilterBar(
        value: WorkspaceFilter.last30Days(),
        workspace: workspace,
        onApply: (_) {},
      ),
    );

    final anchor = tester.getRect(find.text('Mọi trạng thái'));
    await tester.tap(find.text('Mọi trạng thái'));
    await tester.pumpAndSettle();

    expect(find.text('Đã thanh toán'), findsOneWidget);
    final statusLabels = find.text('Mọi trạng thái').evaluate().toList();
    expect(statusLabels, hasLength(2));
    final labelRects = statusLabels
        .map(
          (element) => tester.getRect(
            find.byElementPredicate(
              (candidate) => identical(candidate, element),
            ),
          ),
        )
        .toList();
    expect(labelRects.any((rect) => rect.top >= anchor.bottom), isTrue);
    expect(tester.takeException(), isNull);
  });

  test('superseded payment status has a Vietnamese label', () {
    expect(statusLabel('superseded'), 'Đã thay thế');
  });
}
