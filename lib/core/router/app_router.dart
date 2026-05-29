import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/injection.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/bloc/auth_state.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/splash_page.dart';
import '../../features/booking/presentation/pages/booking_page.dart';
import '../../features/customer/presentation/pages/customer_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/staff/presentation/pages/staff_page.dart';

class AppRouter {
  static final GlobalKey<NavigatorState> rootNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'root');

  static final GoRouter router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: SplashPage.routePath,
    redirect: (BuildContext context, GoRouterState state) {
      // Access the authentication state from the AuthBloc.
      final authState = getIt<AuthBloc>().state;
      final location = state.uri.toString();

      // Define public routes that do not require authentication.
      final isPublicRoute = location == SplashPage.routePath ||
          location == LoginPage.routePath;

      // If the auth state is still initializing, show the splash page.
      if (authState is AuthInitial || authState is AuthLoading) {
        return SplashPage.routePath;
      }

      // If the user is unauthenticated and trying to access a protected route,
      // redirect them to the login page.
      if (authState is Unauthenticated && !isPublicRoute) {
        return LoginPage.routePath;
      }

      // If the user is authenticated and trying to access the login or splash page,
      // redirect them to the main dashboard.
      if (authState is Authenticated && isPublicRoute) {
        return DashboardPage.routePath;
      }

      // No redirection needed.
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
        builder: (_, _) => const DashboardPage(),
      ),
      GoRoute(
        path: BookingPage.routePath,
        name: BookingPage.routeName,
        builder: (_, _) => const BookingPage(),
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
    ],
  );
}