import 'package:flutter/material.dart';

import '../../domain/entities/booking.dart';
import '../../domain/entities/booking_status.dart';

class BookingStatsRow extends StatelessWidget {
  const BookingStatsRow({
    super.key,
    required this.bookings,
    required this.today,
  });

  final List<Booking> bookings;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final todayBookings = bookings
        .where((booking) {
          return booking.startTime.year == today.year &&
              booking.startTime.month == today.month &&
              booking.startTime.day == today.day;
        })
        .toList(growable: false);

    final checkedIn = bookings
        .where((booking) => booking.status == BookingStatus.inProgress)
        .length;
    final waiting = bookings
        .where((booking) => booking.status == BookingStatus.confirmed)
        .length;

    return Row(
      children: [
        _StatCard(
          label: 'Today',
          value: todayBookings.length.toString(),
          color: colorScheme.primary,
        ),
        const SizedBox(width: 8),
        _StatCard(
          label: 'Checked-in',
          value: checkedIn.toString(),
          color: colorScheme.tertiary,
        ),
        const SizedBox(width: 8),
        _StatCard(
          label: 'Waiting',
          value: waiting.toString(),
          color: colorScheme.secondary,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}
