import 'package:flutter/material.dart';

import '../cubit/booking_filters_state.dart';

class BookingFilterTabs extends StatelessWidget {
  const BookingFilterTabs({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final BookingRangeFilter selected;
  final ValueChanged<BookingRangeFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        _FilterChip(
          label: 'All',
          selected: selected == BookingRangeFilter.all,
          onTap: () => onChanged(BookingRangeFilter.all),
        ),
        _FilterChip(
          label: 'Today',
          selected: selected == BookingRangeFilter.today,
          onTap: () => onChanged(BookingRangeFilter.today),
        ),
        _FilterChip(
          label: 'This week',
          selected: selected == BookingRangeFilter.week,
          onTap: () => onChanged(BookingRangeFilter.week),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: colorScheme.primary,
      labelStyle: TextStyle(
        color: selected ? colorScheme.onPrimary : colorScheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
      backgroundColor: colorScheme.surfaceContainerHighest,
      showCheckmark: false,
    );
  }
}
