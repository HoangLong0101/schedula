import 'package:flutter/material.dart';

import '../../domain/entities/booking.dart';
import 'booking_card.dart';

class BookingList extends StatelessWidget {
  const BookingList({
    super.key,
    required this.bookings,
    required this.onStatusUpdate,
    required this.onEdit,
    required this.onCancel,
  });

  final List<Booking> bookings;
  final void Function(Booking) onStatusUpdate;
  final void Function(Booking) onEdit;
  final void Function(Booking) onCancel;

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) {
      return const _EmptyState();
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: bookings.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final booking = bookings[index];
        return BookingCard(
          booking: booking,
          onStatusTap: () => onStatusUpdate(booking),
          onEditTap: () => onEdit(booking),
          onCancelTap: () => onCancel(booking),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(
            Icons.event_busy,
            size: 48,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            'Chưa có lịch hẹn',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
