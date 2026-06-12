import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../booking/presentation/pages/booking_page.dart';
import 'dashboard_page.dart';

class StatisticsPageWrapper extends StatefulWidget {
  const StatisticsPageWrapper({super.key});

  @override
  State<StatisticsPageWrapper> createState() => _StatisticsPageWrapperState();
}

class _StatisticsPageWrapperState extends State<StatisticsPageWrapper> {
  String? _tenantId;
  String? _role;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadClaims();
  }

  Future<void> _loadClaims() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _error = 'Not signed in';
        _loading = false;
      });
      return;
    }

    try {
      final token = await user.getIdTokenResult(true);
      setState(() {
        _tenantId = token.claims?['tenantId'] as String?;
        _role = token.claims?['role'] as String?;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Failed to read tenant claims';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Thống kê')),
        body: Center(child: Text(_error!)),
      );
    }

    if (_role != 'owner') {
      return const _StatisticsAccessDenied();
    }

    return DashboardPage(tenantId: _tenantId);
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
