import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_flavor.dart';
import '../../../dashboard/presentation/pages/home_page.dart';
import 'login_page.dart';

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  static const routePath = '/';
  static const routeName = 'splash';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF063B39), Color(0xFF0F766E), Color(0xFFE7F8F4)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),
                const Icon(Icons.spa_outlined, size: 56, color: Colors.white),
                const SizedBox(height: 20),
                Text(
                  F.title,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Quản lý lịch hẹn, nhân viên và khách hàng trong một không gian làm việc.',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white.withAlpha(220),
                  ),
                ),
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: () => context.go(LoginPage.routePath),
                  child: const Text('Đăng nhập'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => context.go(HomePage.routePath),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white70),
                  ),
                  child: const Text('Vào trang tổng quan'),
                ),
                const Spacer(),
                Text(
                  'Bản phát triển MVP',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
