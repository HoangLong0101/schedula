import 'package:flutter/material.dart';

class StaffPage extends StatelessWidget {
  const StaffPage({super.key});

  static const routePath = '/staff';
  static const routeName = 'staff';

  @override
  Widget build(BuildContext context) {
    return const _FeaturePlaceholderPage(
      title: 'Staff',
      description: 'Scheduling, availability, and role management live here.',
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