import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/injection.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/bloc/auth_state.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/splash_page.dart';
import '../../features/booking/presentation/pages/booking_page.dart';
import '../../features/booking/presentation/pages/booking_page_wrapper.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_page_wrapper.dart';
import '../../features/account/presentation/pages/account_page.dart';
import '../../features/account/presentation/pages/account_info_page.dart';
import '../../features/staff/presentation/pages/staff_page.dart';
import '../../features/equipment/presentation/pages/equipment_page.dart';
import '../../features/customer/presentation/pages/customer_page.dart';
import '../../features/catalog/presentaion/pages/catalog_page.dart';

// Thay thế bằng đường dẫn thực tế của bạn
import 'main_shell_page.dart';

class AppRouter {
  static final GlobalKey<NavigatorState> rootNavigatorKey =
  GlobalKey<NavigatorState>(debugLabel: 'root');

  // Key riêng để điều khiển chuyển tab bên trong Shell
  static final GlobalKey<NavigatorState> _shellNavigatorKey =
  GlobalKey<NavigatorState>(debugLabel: 'shell');

  static final GoRouter router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: LoginPage.routePath,
    refreshListenable: GoRouterRefreshStream(getIt<AuthBloc>().stream),
    redirect: (BuildContext context, GoRouterState state) {
      final authState = getIt<AuthBloc>().state;
      final location = state.uri.toString();

      final isPublicRoute =
          location == SplashPage.routePath || location == LoginPage.routePath;

      if (authState is AuthLoading) {
        return null;
      }

      if ((authState is AuthInitial ||
          authState is Unauthenticated ||
          authState is AuthFailure) &&
          !isPublicRoute) {
        return LoginPage.routePath;
      }

      // Đổi logic redirect từ Login -> Dashboard (Trang chủ) thay vì Booking
      if (authState is Authenticated && isPublicRoute) {
        return BookingPage.routePath;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: SplashPage.routePath,
        name: SplashPage.routeName,
        builder: (_, _) => const SplashPage(),
      ),
      GoRoute(
        path: LoginPage.routePath,
        name: LoginPage.routeName,
        builder: (_, _) => const LoginPage(),
      ),
      GoRoute(
        path: DashboardPage.routePath,
        name: DashboardPage.routeName,
        builder: (_, _) => const DashboardPageWrapper(),
      ),
      GoRoute(
        path: BookingPage.routePath,
        name: BookingPage.routeName,
        builder: (context, state) => const BookingPageWrapper(),
      ),
      GoRoute(
        path: StaffPage.routePath,
        name: StaffPage.routeName,
        builder: (_, _) => const StaffPage(),
      ),
      GoRoute(
        path: CustomerPage.routePath,
        name: CustomerPage.routeName,
        builder: (_, _) => const CustomerPage(),

      // Khai báo StatefulShellRoute
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainShellPage(navigationShell: navigationShell);
        },
        branches: [
          // Nhánh 0: Trang chủ
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: DashboardPage.routePath,
                name: DashboardPage.routeName,
                builder: (context, state) => const DashboardPage(),
              ),
            ],
          ),
          // Nhánh 1: Lịch hẹn
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: BookingPage.routePath,
                name: BookingPage.routeName,
                builder: (context, state) {
                  // Lấy tenantId trực tiếp từ trạng thái đăng nhập
                  final authState = getIt<AuthBloc>().state;
                  final tenantId = authState is Authenticated ? authState.user.tenantId : null;

                  // Bỏ qua Wrapper, gọi thẳng BookingPage
                  return BookingPage(tenantId: tenantId);
                },
              ),
            ],
          ),
          // Nhánh 2: Thống kê (Placeholder)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/statistics',
                builder: (context, state) => const Scaffold(
                  body: Center(child: Text('Màn hình Thống kê (Trống)')),
                ),
              ),
            ],
          ),
          // Nhánh 3: Tài khoản (Placeholder)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/account',
                  builder: (context, state) => const AccountPage(),
                routes: [
                  GoRoute(
                    path: '/info',
                    builder: (context, state) => const AccountInfoPage(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/staff',
                name: StaffPage.routeName,
                builder: (_, _) => const StaffPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/customers',
                name: CustomerPage.routeName,
                builder: (_, _) => const CustomerPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/equipment',
                name: EquipmentPage.routeName,
                builder: (_, _) => const EquipmentPage(),
              ),
              GoRoute(
                path: '/catalog',
                name: 'catalog',
                builder: (_, _) => const CatalogPage(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}