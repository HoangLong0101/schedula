import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/injection.dart';
import '../../features/account/presentation/pages/account_info_page.dart';
import '../../features/account/presentation/pages/account_page.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/bloc/auth_state.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/pages/splash_page.dart';
import '../../features/booking/presentation/pages/booking_page.dart';
import '../../features/catalog/presentaion/pages/catalog_page.dart';
import '../../features/customer/presentation/pages/customer_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_page_wrapper.dart';
import '../../features/dashboard/presentation/pages/home_page.dart';
import '../../features/dashboard/presentation/pages/statistics_page_wrapper.dart';
import '../../features/equipment/presentation/pages/equipment_page.dart';
import '../../features/notification/presentation/pages/notification_page.dart';
import '../../features/payment/presentation/pages/payment_result_page.dart';
import '../../features/staff/presentation/pages/staff_page.dart';
import 'main_shell_page.dart';

class AppRouter {
  static final GlobalKey<NavigatorState> rootNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'root');

  static final GoRouter router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: LoginPage.routePath,
    refreshListenable: GoRouterRefreshStream(getIt<AuthBloc>().stream),
    redirect: (BuildContext context, GoRouterState state) {
      final authState = getIt<AuthBloc>().state;
      final location = state.uri.toString();

      final isPublicRoute =
          location == SplashPage.routePath ||
          location == LoginPage.routePath ||
          location == RegisterPage.routePath ||
          location == RegisterPage.googleSetupPath ||
          location.startsWith(PaymentResultPage.successRoutePath) ||
          location.startsWith(PaymentResultPage.cancelRoutePath);
      final isAuthEntryRoute =
          location == SplashPage.routePath ||
          location == LoginPage.routePath ||
          location == RegisterPage.routePath ||
          location == RegisterPage.googleSetupPath;

      if (authState is AuthLoading) {
        return null;
      }

      if (authState is AuthProfileSetupRequired) {
        return location == RegisterPage.googleSetupPath
            ? null
            : RegisterPage.googleSetupPath;
      }

      if ((authState is AuthInitial ||
              authState is Unauthenticated ||
              authState is AuthFailure) &&
          !isPublicRoute) {
        return LoginPage.routePath;
      }

      if (authState is Authenticated && isAuthEntryRoute) {
        return HomePage.routePath;
      }

      if (authState is Authenticated && authState.user.isStaff) {
        final staffBlockedRoutes = <String>{
          StaffPage.routePath,
          CustomerPage.routePath,
          EquipmentPage.routePath,
          CatalogPage.routePath,
          NotificationPage.routePath,
        };
        if (staffBlockedRoutes.contains(location)) {
          return BookingPage.routePath;
        }
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
        path: RegisterPage.routePath,
        name: RegisterPage.routeName,
        builder: (_, _) => const RegisterPage(),
      ),
      GoRoute(
        path: RegisterPage.googleSetupPath,
        name: RegisterPage.googleSetupRouteName,
        builder: (_, _) => const RegisterPage(googleSetup: true),
      ),
      GoRoute(
        path: PaymentResultPage.successRoutePath,
        builder: (context, state) => PaymentResultPage.success(
          orderCode: state.uri.queryParameters['orderCode'],
        ),
      ),
      GoRoute(
        path: PaymentResultPage.cancelRoutePath,
        builder: (context, state) => PaymentResultPage.cancelled(
          orderCode: state.uri.queryParameters['orderCode'],
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainShellPage(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: HomePage.routePath,
                name: HomePage.routeName,
                builder: (context, state) => const DashboardPageWrapper(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: BookingPage.routePath,
                name: BookingPage.routeName,
                builder: (context, state) {
                  final authState = getIt<AuthBloc>().state;
                  final tenantId = authState is Authenticated
                      ? authState.user.tenantId
                      : null;
                  final staffId =
                      authState is Authenticated && authState.user.isStaff
                      ? authState.user.id
                      : null;

                  return BookingPage(
                    tenantId: tenantId,
                    restrictedStaffId: staffId,
                  );
                },
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: DashboardPage.routePath,
                name: DashboardPage.routeName,
                builder: (context, state) => const StatisticsPageWrapper(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AccountPage.routePath,
                builder: (context, state) => const AccountPage(),
                routes: [
                  GoRoute(
                    path: 'info',
                    builder: (context, state) => const AccountInfoPage(),
                  ),
                ],
              ),
            ],
          ),
        ],
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
      ),
      GoRoute(
        path: EquipmentPage.routePath,
        name: EquipmentPage.routeName,
        builder: (_, _) => const EquipmentPage(),
      ),
      GoRoute(
        path: CatalogPage.routePath,
        name: CatalogPage.routeName,
        builder: (_, _) => const CatalogPage(),
      ),
      GoRoute(
        path: NotificationPage.routePath,
        name: NotificationPage.routeName,
        builder: (_, _) => const NotificationPage(),
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
