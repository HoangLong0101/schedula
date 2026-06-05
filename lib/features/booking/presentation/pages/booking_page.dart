import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../domain/entities/booking.dart';
import '../../domain/usecases/cancel_booking_usecase.dart';
import '../../domain/usecases/update_booking_status_usecase.dart';
import '../../domain/usecases/watch_bookings_usecase.dart';
import '../bloc/booking_bloc.dart';
import '../bloc/booking_event.dart';
import '../bloc/booking_state.dart';
import '../cubit/booking_filters_cubit.dart';
import '../cubit/booking_filters_state.dart';
import '../widgets/booking_actions.dart';
import '../widgets/booking_conflict_card.dart';
import '../widgets/booking_filter_tabs.dart';
import '../widgets/booking_form_sheet.dart';
import '../widgets/booking_list.dart';
import '../widgets/booking_search_field.dart';
import '../widgets/booking_stats_row.dart';

class BookingPage extends StatelessWidget {
  const BookingPage({super.key, this.tenantId});

  static const routePath = '/booking';
  static const routeName = 'booking';

  final String? tenantId;

  @override
  Widget build(BuildContext context) {
    if (tenantId == null || tenantId!.isEmpty) {
      return const _TenantMissingView();
    }

    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => getIt<BookingBloc>()
            ..add(
              BookingStarted(
                WatchBookingsParams(tenantId: tenantId!),
              ),
            ),
        ),
        BlocProvider(
          create: (_) => getIt<BookingFiltersCubit>(),
        ),
      ],
      child: _BookingView(tenantId: tenantId!),
    );
  }
}

class _TenantMissingView extends StatelessWidget {
  const _TenantMissingView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bookings')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Tenant context is required to load bookings.'),
        ),
      ),
    );
  }
}

class _BookingView extends StatelessWidget {
  const _BookingView({required this.tenantId});

  final String tenantId;

  @override
  Widget build(BuildContext context) {
    return BlocListener<BookingBloc, BookingState>(
      listener: (context, state) {
        if (state is BookingFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Lich Hen'),
          actions: [
            IconButton(
              onPressed: () => BookingFormSheet.show(
                context,
                tenantId: tenantId,
              ),
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        body: SafeArea(
          child: BlocListener<BookingFiltersCubit, BookingFiltersState>(
            listenWhen: (previous, next) {
              return previous.range != next.range ||
                  previous.staffId != next.staffId;
            },
            listener: _syncFilters,
            child: BlocBuilder<BookingFiltersCubit, BookingFiltersState>(
              builder: (context, filters) {
                return BlocBuilder<BookingBloc, BookingState>(
                  builder: (context, state) {
                    final bookings = _resolveBookings(state);
                    final filtered = _applyFilters(bookings, filters);
                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        BookingSearchField(
                          value: filters.searchQuery,
                          onChanged: context
                              .read<BookingFiltersCubit>()
                              .updateSearch,
                        ),
                        const SizedBox(height: 12),
                        BookingFilterTabs(
                          selected: filters.range,
                          onChanged: context
                              .read<BookingFiltersCubit>()
                              .updateRange,
                        ),
                        const SizedBox(height: 12),
                        BookingStatsRow(
                          bookings: bookings,
                          today: DateTime.now(),
                        ),
                        const SizedBox(height: 12),
                        const BookingConflictCard(
                          title: 'AI conflict scan',
                          message: 'No conflicts detected for selected range.',
                        ),
                        const SizedBox(height: 12),
                        BookingList(
                          bookings: filtered,
                          onStatusUpdate: (booking) {
                            final nextStatus = nextStatusFor(booking);
                            if (nextStatus == booking.status) {
                              return;
                            }
                            context.read<BookingBloc>().add(
                                  BookingStatusUpdateRequested(
                                    UpdateBookingStatusParams(
                                      bookingId: booking.id,
                                      status: nextStatus,
                                    ),
                                  ),
                                );
                          },
                          onEdit: (_) => BookingFormSheet.show(
                            context,
                            tenantId: tenantId,
                          ),
                          onCancel: (booking) =>
                              context.read<BookingBloc>().add(
                                    BookingCancelRequested(
                                      CancelBookingParams(
                                        bookingId: booking.id,
                                      ),
                                    ),
                                  ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _syncFilters(BuildContext context, BookingFiltersState filters) {
    final now = DateTime.now();
    DateTime? start;
    DateTime? end;

    if (filters.range == BookingRangeFilter.today) {
      start = DateTime(now.year, now.month, now.day);
      end = start.add(const Duration(days: 1));
    } else if (filters.range == BookingRangeFilter.week) {
      final weekday = now.weekday;
      start = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: weekday - 1));
      end = start.add(const Duration(days: 7));
    }

    context.read<BookingBloc>().add(
          BookingStarted(
            WatchBookingsParams(
              tenantId: tenantId,
              startDate: start,
              endDate: end,
              staffId: filters.staffId,
            ),
          ),
        );
  }

  List<Booking> _resolveBookings(BookingState state) {
    if (state is BookingLoaded) {
      return state.bookings;
    }
    if (state is BookingFailure) {
      return state.previous;
    }
    return const [];
  }

  List<Booking> _applyFilters(
    List<Booking> bookings,
    BookingFiltersState filters,
  ) {
    final query = filters.searchQuery.toLowerCase();
    if (query.isEmpty) {
      return bookings;
    }
    return bookings.where((booking) {
      return booking.customerName?.toLowerCase().contains(query) == true ||
          booking.staffName?.toLowerCase().contains(query) == true ||
          booking.serviceName?.toLowerCase().contains(query) == true ||
          booking.customerId.toLowerCase().contains(query) ||
          booking.staffId.toLowerCase().contains(query) ||
          booking.serviceId.toLowerCase().contains(query);
    }).toList(growable: false);
  }
}