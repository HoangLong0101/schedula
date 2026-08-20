import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schedula_admin/src/admin_services.dart';
import 'package:schedula_admin/src/admin_shell.dart';
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
    },
    'businesses': [
      {
        'id': 'tenant-1',
        'name': 'An Nhiên Spa',
        'ownerName': 'Nguyễn An',
        'ownerEmail': 'an@example.com',
        'ownerPhone': '0901234567',
        'phone': '0901234567',
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
      'transactionStatus': {'paid': 1},
      'usageRateByDay': {'2026-08-12': 50, '2026-08-13': 100},
      'newBusinessesByDay': {'2026-08-12': 1, '2026-08-13': 0},
      'churnedBusinessesByDay': {'2026-08-12': 0, '2026-08-13': 1},
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
    'admins': [
      {
        'id': 'admin-1',
        'email': 'admin@schedula.vn',
        'role': 'super_admin',
        'active': true,
      },
    ],
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
      PlansWorkspace(data: workspace, api: api, onChanged: () {}),
      MonitoringWorkspace(data: workspace),
      ReportsWorkspace(data: workspace, filter: WorkspaceFilter.last30Days()),
      AdminUsersWorkspace(data: workspace, api: api, onChanged: () {}),
    ];

    for (final page in pages) {
      await render(tester, page);
    }
  });

  testWidgets('removed monitoring and province surfaces stay hidden', (
    tester,
  ) async {
    await render(tester, MonitoringWorkspace(data: workspace));

    expect(find.text('Webhook PayOS'), findsNothing);
    expect(find.text('Cloud Monitoring'), findsNothing);
    expect(find.text('Nhật ký kiểm toán'), findsOneWidget);
    expect(
      adminDestinations.map((item) => item.label),
      isNot(contains('Tỉnh thành')),
    );
  });

  testWidgets('dashboard groups related metrics with hover explanations', (
    tester,
  ) async {
    await render(tester, DashboardWorkspace(data: workspace));

    expect(find.text('Doanh thu và hiệu quả giao dịch'), findsOneWidget);
    expect(find.text('Doanh nghiệp và mức sử dụng'), findsOneWidget);
    expect(find.text('Hiệu quả landing page'), findsNothing);
    expect(find.byType(Tooltip), findsWidgets);
  });

  testWidgets('business metric cards switch the 30-day trend chart', (
    tester,
  ) async {
    await render(tester, DashboardWorkspace(data: workspace));

    expect(find.text('Tỷ lệ sử dụng trong kỳ đã chọn'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('trend-line')).last).height,
      greaterThan(0),
    );
    expect(find.byKey(const ValueKey('trend-point-2026-08-12')), findsWidgets);
    await tester.tap(find.text('Doanh nghiệp mới').last);
    await tester.pumpAndSettle();
    expect(find.text('Doanh nghiệp mới trong kỳ đã chọn'), findsOneWidget);
    await tester.ensureVisible(find.text('Đã rời bỏ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đã rời bỏ'));
    await tester.pumpAndSettle();
    expect(find.text('Doanh nghiệp rời bỏ trong kỳ đã chọn'), findsOneWidget);
  });

  testWidgets('tenant usage cards expand into editable record lists', (
    tester,
  ) async {
    final fakeApi = _FakeAdminApi();
    await render(
      tester,
      BusinessDetailDialog(
        business: workspace.businesses.first,
        api: fakeApi,
        onChanged: () {},
      ),
    );

    await tester.tap(find.byKey(const ValueKey('tenant-record-card-products')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('tenant-record-list-products')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('business-activity-trend-30')),
      findsOneWidget,
    );
    expect(find.text('Serum phục hồi'), findsOneWidget);
    expect(find.text('Thêm'), findsOneWidget);
    expect(find.byTooltip('Chỉnh sửa'), findsWidgets);
    expect(find.byTooltip('Xóa'), findsWidgets);
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
    expect(find.text('Chuyên nghiệp'), findsOneWidget);
  });

  testWidgets('business table shows owner phone instead of email', (
    tester,
  ) async {
    await render(
      tester,
      BusinessesWorkspace(data: workspace, api: api, onChanged: () {}),
    );

    expect(find.text('Số điện thoại'), findsOneWidget);
    expect(find.text('0901234567'), findsOneWidget);
    expect(find.text('an@example.com'), findsNothing);
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

    final basicX = tester.getTopLeft(find.text('Cơ bản')).dx;
    final proX = tester.getTopLeft(find.text('Chuyên nghiệp')).dx;
    final enterpriseX = tester.getTopLeft(find.text('Doanh nghiệp')).dx;
    expect(basicX, lessThan(proX));
    expect(proX, lessThan(enterpriseX));
    expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(3));
  });

  testWidgets('plan cards hide annual and trial facts and show 100 bookings', (
    tester,
  ) async {
    final plans = PlatformWorkspace.fromMap({
      'plans': [
        {
          'id': 'basic',
          'name': 'Cơ Bản',
          'price': 299000,
          'yearlyPrice': 2990000,
          'trialDays': 14,
          'features': ['Tối đa 100 lịch hẹn/tháng'],
          'status': 'active',
        },
      ],
    });

    await render(
      tester,
      PlansWorkspace(data: plans, api: api, onChanged: () {}),
    );

    expect(find.text('Tối đa 100 lịch hẹn/tháng'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Text && (widget.data ?? '').contains('/ năm'),
      ),
      findsNothing,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text && (widget.data ?? '').contains('ngày dùng thử'),
      ),
      findsNothing,
    );
  });

  testWidgets('filter dropdown opens without covering the filter control', (
    tester,
  ) async {
    await render(
      tester,
      GlobalFilterBar(
        section: AdminSection.transactions,
        value: WorkspaceFilter.last30Days(),
        workspace: workspace,
        onApply: (_) {},
      ),
    );

    expect(find.text('Tỉnh thành'), findsNothing);

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

  testWidgets('filter bar changes controls for the active section', (
    tester,
  ) async {
    await render(
      tester,
      GlobalFilterBar(
        section: AdminSection.businesses,
        value: WorkspaceFilter.last30Days(),
        workspace: workspace,
        onApply: (_) {},
      ),
    );

    expect(find.text('Loại hình'), findsOneWidget);
    expect(find.text('Đăng ký'), findsOneWidget);
    expect(find.text('Thanh toán'), findsNothing);
    expect(find.byKey(const ValueKey('workspace-date-range')), findsNothing);

    await render(
      tester,
      GlobalFilterBar(
        section: AdminSection.transactions,
        value: WorkspaceFilter.last30Days(),
        workspace: workspace,
        onApply: (_) {},
      ),
    );

    expect(find.text('Thanh toán'), findsOneWidget);
    expect(find.text('Đăng ký'), findsNothing);
    expect(find.byKey(const ValueKey('workspace-date-range')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('workspace-filter-strip')),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            (widget.data ?? '').contains('00:00:00') &&
            (widget.data ?? '').contains('23:59:59'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('workspace-date-range')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('workspace-date-dropdown')),
      findsOneWidget,
    );
    expect(find.text('Chọn khoảng ngày'), findsOneWidget);
    expect(find.text('Hủy'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('workspace-date-dropdown')),
        matching: find.text('Áp dụng'),
      ),
      findsOneWidget,
    );
  });

  test('default workspace range covers complete calendar days', () {
    final range = WorkspaceFilter.last30Days();

    expect(range.start.hour, 0);
    expect(range.start.minute, 0);
    expect(range.start.second, 0);
    expect(range.end.hour, 23);
    expect(range.end.minute, 59);
    expect(range.end.second, 59);
  });

  test('superseded payment status has a Vietnamese label', () {
    expect(statusLabel('superseded'), 'Đã thay thế');
  });
}

class _FakeAdminApi extends AdminApi {
  @override
  Future<Map<Object?, Object?>> getBusinessDetail(
    String tenantId, {
    int activityDays = 30,
  }) async => {
    'business': {
      'id': tenantId,
      'ownerName': 'Nguyễn An',
      'ownerPhone': '0901234567',
      'address': 'Quận 3, TP.HCM',
      'province': 'TP.HCM',
      'planTier': 'pro',
    },
    'usage': {
      'bookings': 0,
      'customers': 0,
      'staff': 0,
      'services': 0,
      'products': 1,
      'equipment': 0,
    },
    'records': {
      'bookings': <Object?>[],
      'customers': <Object?>[],
      'staff': <Object?>[],
      'services': <Object?>[],
      'products': [
        {
          'id': 'product-1',
          'name': 'Serum phục hồi',
          'category': 'Chăm sóc da',
          'price': 450000,
          'unit': 'Chai',
        },
      ],
      'equipment': <Object?>[],
    },
    'payments': <Object?>[],
    'activity': [
      {
        'id': 'activity-1',
        'type': 'booking',
        'action': 'booking.created',
        'status': 'succeeded',
        'createdAt': DateTime.now()
            .subtract(const Duration(hours: 2))
            .millisecondsSinceEpoch,
      },
    ],
    'lifetimeRevenue': 0,
    'lifetimeRevenueAvailable': true,
  };

  @override
  Future<Map<Object?, Object?>> performAction({
    required String action,
    required String resourceId,
    Map<String, Object?> payload = const {},
  }) async => {'resourceId': resourceId};
}
