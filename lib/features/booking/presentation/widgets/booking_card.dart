import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/booking.dart';
import '../../domain/entities/booking_status.dart';

class BookingCard extends StatelessWidget {
  const BookingCard({
    super.key,
    required this.booking,
    required this.onStatusTap,
    required this.onEditTap,
    required this.onCancelTap,
  });

  final Booking booking;
  final VoidCallback onStatusTap;
  final VoidCallback onEditTap;
  final VoidCallback onCancelTap;

  @override
  Widget build(BuildContext context) {
    final timeRange =
        '${DateFormat.Hm().format(booking.startTime)} - ${DateFormat.Hm().format(booking.endTime)}';
    final statusStyle = _statusStyle(context, booking.status);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking.customerName ?? booking.customerId,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        booking.serviceName ?? booking.serviceId,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusStyle.background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusStyle.label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: statusStyle.foreground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 16,
                  color: statusStyle.foreground,
                ),
                const SizedBox(width: 6),
                Text(timeRange),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.person, size: 16, color: statusStyle.foreground),
                const SizedBox(width: 6),
                Text(booking.staffName ?? booking.staffId),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (booking.status != BookingStatus.completed &&
                    booking.status != BookingStatus.cancelled) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onStatusTap,
                      child: const Text('Update status'),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                IconButton(onPressed: onEditTap, icon: const Icon(Icons.edit)),
                IconButton(
                  onPressed: onCancelTap,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BookingStatusStyle {
  const _BookingStatusStyle({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;
}

_BookingStatusStyle _statusStyle(BuildContext context, BookingStatus status) {
  final colorScheme = Theme.of(context).colorScheme;
  switch (status) {
    case BookingStatus.pending:
      return _BookingStatusStyle(
        label: 'Pending',
        background: colorScheme.surfaceContainerHighest,
        foreground: colorScheme.onSurface,
      );
    case BookingStatus.confirmed:
      return _BookingStatusStyle(
        label: 'Confirmed',
        background: colorScheme.primary.withAlpha(31),
        foreground: colorScheme.primary,
      );
    case BookingStatus.inProgress:
      return _BookingStatusStyle(
        label: 'Checked-in',
        background: colorScheme.tertiaryContainer,
        foreground: colorScheme.onTertiaryContainer,
      );
    case BookingStatus.completed:
      return _BookingStatusStyle(
        label: 'Completed',
        background: colorScheme.surfaceContainerHighest,
        foreground: colorScheme.onSurface,
      );
    case BookingStatus.cancelled:
      return _BookingStatusStyle(
        label: 'Cancelled',
        background: colorScheme.errorContainer,
        foreground: colorScheme.onErrorContainer,
      );
    case BookingStatus.noShow:
      return _BookingStatusStyle(
        label: 'No show',
        background: colorScheme.errorContainer,
        foreground: colorScheme.onErrorContainer,
      );
  }
}
