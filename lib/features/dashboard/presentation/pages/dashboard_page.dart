import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_flavor.dart';
import '../../../booking/presentation/pages/booking_page.dart';
import '../../../customer/presentation/pages/customer_page.dart';
import '../../../staff/presentation/pages/staff_page.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  static const routePath = '/dashboard';
  static const routeName = 'dashboard';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${F.title} dashboard'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Daily operations at a glance',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'A layered feature surface for bookings, staff, and customer management.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _ActionCard(
                title: 'Bookings',
                subtitle: 'Appointments, availability, and reschedules.',
                icon: Icons.calendar_month_outlined,
                onTap: () => context.go(BookingPage.routePath),
              ),
              _ActionCard(
                title: 'Staff',
                subtitle: 'Therapists, shifts, and assignments.',
                icon: Icons.groups_outlined,
                onTap: () => context.go(StaffPage.routePath),
              ),
              _ActionCard(
                title: 'Customers',
                subtitle: 'Profiles, visit history, and notes.',
                icon: Icons.person_outline,
                onTap: () => context.go(CustomerPage.routePath),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Build mode',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    F.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 210,
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 30),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Text(subtitle),
              ],
            ),
          ),
        ),
      ),
    );
  }
}