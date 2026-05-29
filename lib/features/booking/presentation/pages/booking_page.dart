import 'package:flutter/material.dart';

class BookingPage extends StatelessWidget {
  const BookingPage({super.key});

  static const routePath = '/booking';
  static const routeName = 'booking';

  @override
  Widget build(BuildContext context) {
    return const _FeaturePlaceholderPage(
      title: 'Bookings',
      description: 'Calendar, reservations, and appointment controls live here.',
    );
  }
}

class _FeaturePlaceholderPage extends StatelessWidget {
  const _FeaturePlaceholderPage({
    required this.title,
    required this.description,
  });

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                description,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}