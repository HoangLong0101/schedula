import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schedula_admin/src/admin_services.dart';
import 'package:schedula_admin/src/admin_theme.dart';
import 'package:schedula_admin/src/login_page.dart';

void main() {
  Future<void> render(WidgetTester tester, Size size) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        theme: AdminTheme.light,
        home: LoginPage(auth: AdminAuthService()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders the login form on desktop', (tester) async {
    await render(tester, const Size(1440, 900));

    expect(find.text('Đăng nhập quản trị'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.byType(Image), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders the login form on a narrow viewport', (tester) async {
    await render(tester, const Size(390, 844));

    expect(find.text('Đăng nhập quản trị'), findsOneWidget);
    expect(find.text('Quên mật khẩu?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
