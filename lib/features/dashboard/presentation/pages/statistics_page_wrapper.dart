import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../booking/presentation/pages/booking_page.dart';
import 'dashboard_page.dart';

class StatisticsPageWrapper extends StatelessWidget {
  const StatisticsPageWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;

    if (authState is AuthInitial || authState is AuthLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (authState is! Authenticated) {
      return Scaffold(
        appBar: AppBar(title: const Text('Thống kê')),
        body: const Center(child: Text('Vui lòng đăng nhập.')),
      );
    }

    if (authState.user.role != 'owner') {
      return const _StatisticsAccessDenied();
    }

    return DashboardPage(tenantId: authState.user.tenantId);
  }
}

class _StatisticsAccessDenied extends StatelessWidget {
  const _StatisticsAccessDenied();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Thống kê')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_outline,
                size: 48,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(height: 16),
              Text(
                'Chỉ chủ cơ sở mới có thể xem thống kê.',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.go(BookingPage.routePath),
                child: const Text('Về trang lịch đặt'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
