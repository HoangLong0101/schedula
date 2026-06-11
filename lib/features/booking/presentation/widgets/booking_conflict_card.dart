import 'package:flutter/material.dart';

class BookingConflictCard extends StatelessWidget {
  const BookingConflictCard({
    super.key,
    required this.title,
    required this.message,
    this.onResolve,
  });

  final String title;
  final String message;
  final VoidCallback? onResolve;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withAlpha(77),
        ),
        color: Theme.of(context).colorScheme.primary.withAlpha(20),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primary,
            child: Icon(
              Icons.auto_awesome,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(message, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          if (onResolve != null)
            TextButton(onPressed: onResolve, child: const Text('Resolve')),
        ],
      ),
    );
  }
}
