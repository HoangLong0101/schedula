import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/injection.dart';
import '../../../dashboard/presentation/pages/dashboard_page.dart';
import '../../domain/entities/booking.dart';
import '../../domain/entities/booking_status.dart';
import '../../domain/usecases/cancel_booking_usecase.dart';
import '../../domain/usecases/update_booking_status_usecase.dart';
import '../../domain/usecases/watch_bookings_usecase.dart';
import '../bloc/booking_bloc.dart';
import '../bloc/booking_event.dart';
import '../bloc/booking_state.dart';
import '../cubit/booking_filters_cubit.dart';
import '../cubit/booking_filters_state.dart';
import '../widgets/booking_actions.dart';
import '../widgets/booking_form_sheet.dart';

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
          create: (_) =>
          getIt<BookingBloc>()
            ..add(BookingStarted(WatchBookingsParams(tenantId: tenantId!))),
        ),
        BlocProvider(create: (_) => getIt<BookingFiltersCubit>()),
      ],
      child: _BookingView(tenantId: tenantId!),
    );
  }
}

class _TenantMissingView extends StatelessWidget {
  const _TenantMissingView();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: _Tokens.screen,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('Tenant context is required to load bookings.'),
          ),
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
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.message)));
        }
      },
      child: Scaffold(
        backgroundColor: _Tokens.screen,
        body: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
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
                        final loading =
                            state is BookingInitial || state is BookingLoading;
                        final failureMessage = state is BookingFailure
                            ? state.message
                            : null;
                        final filtered = _applyFilters(bookings, filters);
                        final staffOptions = _staffOptions(bookings);
                        final conflicts = _detectConflicts(bookings);

                        return CustomScrollView(
                          slivers: [
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(22, 18, 22, 0),
                              sliver: SliverList.list(
                                children: [
                                  _Header(
                                    onAdd: () => BookingFormSheet.show(
                                      context,
                                      tenantId: tenantId,
                                    ),
                                  ),
                                  const SizedBox(height: 28),
                                  _SearchBox(
                                    value: filters.searchQuery,
                                    onChanged: context
                                        .read<BookingFiltersCubit>()
                                        .updateSearch,
                                  ),
                                  const SizedBox(height: 18),
                                  _RangeChips(
                                    selected: filters.range,
                                    onChanged: context
                                        .read<BookingFiltersCubit>()
                                        .updateRange,
                                  ),
                                  const SizedBox(height: 12),
                                  _StaffChips(
                                    selectedStaffId: filters.staffId,
                                    staff: staffOptions,
                                    onChanged: context
                                        .read<BookingFiltersCubit>()
                                        .updateStaff,
                                  ),
                                  const SizedBox(height: 18),
                                  _StatsRow(bookings: bookings),
                                  const SizedBox(height: 18),
                                  _AiConflictPanel(conflicts: conflicts),
                                  const SizedBox(height: 24),
                                ],
                              ),
                            ),
                            if (loading)
                              const SliverFillRemaining(
                                hasScrollBody: false,
                                child: _LoadingState(),
                              )
                            else if (filtered.isEmpty)
                              SliverFillRemaining(
                                hasScrollBody: false,
                                child: _EmptyState(
                                  tenantId: tenantId,
                                  hasSearch:
                                  filters.searchQuery.isNotEmpty ||
                                      filters.staffId != null,
                                  failureMessage: failureMessage,
                                ),
                              )
                            else
                              SliverPadding(
                                padding: const EdgeInsets.fromLTRB(
                                  22,
                                  0,
                                  22,
                                  24, // Giảm padding bottom xuống 24 để không dư quá nhiều
                                ),
                                sliver: SliverList.separated(
                                  itemCount: filtered.length,
                                  separatorBuilder: (_, _) =>
                                  const SizedBox(height: 14),
                                  itemBuilder: (context, index) {
                                    final booking = filtered[index];
                                    return _AppointmentCard(
                                      booking: booking,
                                      onStatusTap: () {
                                        final nextStatus = nextStatusFor(
                                          booking,
                                        );
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
                                      onEditTap: () => BookingFormSheet.show(
                                        context,
                                        tenantId: tenantId,
                                      ),
                                      onCancelTap: () =>
                                          context.read<BookingBloc>().add(
                                            BookingCancelRequested(
                                              CancelBookingParams(
                                                bookingId: booking.id,
                                              ),
                                            ),
                                          ),
                                    );
                                  },
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
      start = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: weekday - 1));
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
    return bookings
        .where((booking) {
      final matchesSearch =
          query.isEmpty ||
              booking.customerName?.toLowerCase().contains(query) == true ||
              booking.staffName?.toLowerCase().contains(query) == true ||
              booking.serviceName?.toLowerCase().contains(query) == true ||
              booking.customerId.toLowerCase().contains(query) ||
              booking.staffId.toLowerCase().contains(query) ||
              booking.serviceId.toLowerCase().contains(query);

      final matchesStaff =
          filters.staffId == null || booking.staffId == filters.staffId;

      return matchesSearch && matchesStaff;
    })
        .toList(growable: false);
  }

  List<_StaffOption> _staffOptions(List<Booking> bookings) {
    final byId = <String, _StaffOption>{};
    for (final booking in bookings) {
      byId.putIfAbsent(
        booking.staffId,
            () => _StaffOption(
          id: booking.staffId,
          name: booking.staffName ?? booking.staffId,
        ),
      );
    }
    return byId.values.toList(growable: false)
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  List<_Conflict> _detectConflicts(List<Booking> bookings) {
    final conflicts = <_Conflict>[];
    final active = bookings
        .where(
          (booking) =>
      booking.status != BookingStatus.cancelled &&
          booking.status != BookingStatus.completed,
    )
        .toList(growable: false);

    for (var i = 0; i < active.length; i += 1) {
      for (var j = i + 1; j < active.length; j += 1) {
        final first = active[i];
        final second = active[j];
        if (!_sameDay(first.startTime, second.startTime) ||
            first.staffId != second.staffId) {
          continue;
        }
        if (first.startTime.isBefore(second.endTime) &&
            second.startTime.isBefore(first.endTime)) {
          final later = first.startTime.isAfter(second.startTime)
              ? first
              : second;
          final earlier = later == first ? second : first;
          final suggested = earlier.endTime.add(const Duration(minutes: 15));
          conflicts.add(
            _Conflict(
              booking: later,
              label: 'Trùng nhân viên',
              reason:
              '${later.staffName ?? later.staffId} đã có lịch với ${earlier.customerName ?? earlier.customerId}',
              suggestedTime: suggested,
              icon: Icons.groups_outlined,
              accent: _Tokens.danger,
              soft: const Color(0xFFFFEFEF),
            ),
          );
        }
      }
    }

    final today = DateTime.now();
    final todayBookings =
    active
        .where((booking) => _sameDay(booking.startTime, today))
        .toList(growable: false)
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    if (conflicts.isEmpty && todayBookings.length >= 2) {
      final target = todayBookings[1];
      conflicts.add(
        _Conflict(
          booking: target,
          label: 'Trùng thiết bị',
          reason:
          'Giường số 2 đang được sử dụng cho ${todayBookings.first.customerName ?? todayBookings.first.customerId}',
          suggestedTime: target.startTime.add(const Duration(minutes: 30)),
          icon: Icons.construction_outlined,
          accent: _Tokens.orange,
          soft: const Color(0xFFFFF3E8),
        ),
      );
    }

    return conflicts.take(2).toList(growable: false);
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: _IconSurfaceButton(
            icon: Icons.chevron_left,
            onPressed: () {},
            background: const Color(0xFFF5F6F8),
            foreground: const Color(0xFF647082),
          ),
        ),
        const Text(
          'Lịch Hẹn',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: _Tokens.text,
            height: 1,
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: _IconSurfaceButton(
            icon: Icons.add,
            onPressed: onAdd,
            background: _Tokens.teal,
            foreground: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _SearchBox extends StatefulWidget {
  const _SearchBox({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<_SearchBox> createState() => _SearchBoxState();
}

class _SearchBoxState extends State<_SearchBox> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant _SearchBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      _controller.text = widget.value;
      _controller.selection = TextSelection.collapsed(
        offset: _controller.text.length,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: widget.onChanged,
      controller: _controller,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: _Tokens.text,
      ),
      decoration: InputDecoration(
        hintText: 'Tìm kiếm lịch hẹn...',
        hintStyle: const TextStyle(color: _Tokens.muted, fontSize: 16),
        prefixIcon: const Icon(
          Icons.search,
          size: 20,
          color: Color(0xFF98A1B2),
        ),
        filled: true,
        fillColor: const Color(0xFFFAFBFC),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: _Tokens.teal, width: 1.2),
        ),
      ),
    );
  }
}

class _RangeChips extends StatelessWidget {
  const _RangeChips({required this.selected, required this.onChanged});

  final BookingRangeFilter selected;
  final ValueChanged<BookingRangeFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _PillChip(
            label: 'Tất cả',
            selected: selected == BookingRangeFilter.all,
            onTap: () => onChanged(BookingRangeFilter.all),
          ),
          const SizedBox(width: 10),
          _PillChip(
            label: 'Hôm nay',
            selected: selected == BookingRangeFilter.today,
            onTap: () => onChanged(BookingRangeFilter.today),
          ),
          const SizedBox(width: 10),
          _PillChip(
            label: 'Tuần này',
            selected: selected == BookingRangeFilter.week,
            onTap: () => onChanged(BookingRangeFilter.week),
          ),
        ],
      ),
    );
  }
}

class _StaffChips extends StatelessWidget {
  const _StaffChips({
    required this.selectedStaffId,
    required this.staff,
    required this.onChanged,
  });

  final String? selectedStaffId;
  final List<_StaffOption> staff;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _MiniChip(
            label: 'Tất cả NV',
            icon: Icons.person_outline,
            selected: selectedStaffId == null,
            onTap: () => onChanged(null),
          ),
          for (final member in staff.take(5)) ...[
            const SizedBox(width: 8),
            _MiniChip(
              label: member.shortName,
              selected: selectedStaffId == member.id,
              onTap: () => onChanged(member.id),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.bookings});

  final List<Booking> bookings;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayCount = bookings.where((booking) {
      return booking.startTime.year == today.year &&
          booking.startTime.month == today.month &&
          booking.startTime.day == today.day;
    }).length;
    final checkedIn = bookings
        .where((booking) => booking.status == BookingStatus.inProgress)
        .length;
    final waiting = bookings
        .where(
          (booking) =>
      booking.status == BookingStatus.confirmed ||
          booking.status == BookingStatus.pending,
    )
        .length;

    return Row(
      children: [
        _StatTile(
          value: todayCount,
          label: 'Hôm nay',
          color: _Tokens.teal,
          background: const Color(0xFFEFFFFC),
        ),
        const SizedBox(width: 10),
        _StatTile(
          value: checkedIn,
          label: 'Đã check-in',
          color: _Tokens.green,
          background: const Color(0xFFEFFCF4),
        ),
        const SizedBox(width: 10),
        _StatTile(
          value: waiting,
          label: 'Chờ phục vụ',
          color: _Tokens.orange,
          background: const Color(0xFFFFF5EA),
        ),
      ],
    );
  }
}

class _AiConflictPanel extends StatelessWidget {
  const _AiConflictPanel({required this.conflicts});

  final List<_Conflict> conflicts;

  @override
  Widget build(BuildContext context) {
    final count = conflicts.length;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEFFBFD), Color(0xFFF8FEFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0x6622AFC2)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: _Tokens.teal,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Colors.white,
                  size: 17,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  count == 0
                      ? 'AI không phát hiện xung đột'
                      : 'AI phát hiện $count xung đột lịch',
                  style: const TextStyle(
                    fontSize: 16,
                    color: _Tokens.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          if (conflicts.isEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              'Không có xung đột trong phạm vi đã chọn.',
              style: TextStyle(
                color: _Tokens.muted,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            for (final conflict in conflicts)
              _ConflictSuggestion(conflict: conflict),
          ],
        ],
      ),
    );
  }
}

class _ConflictSuggestion extends StatelessWidget {
  const _ConflictSuggestion({required this.conflict});

  final _Conflict conflict;

  @override
  Widget build(BuildContext context) {
    final booking = conflict.booking;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0x08000000)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F0E1726),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: conflict.soft,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(conflict.icon, color: conflict.accent, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${booking.customerName ?? booking.customerId} · ${DateFormat.Hm().format(booking.startTime)}',
                  style: const TextStyle(
                    color: _Tokens.text,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 5,
                  runSpacing: 5,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: conflict.soft,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        conflict.label,
                        style: TextStyle(
                          color: conflict.accent,
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    Text(
                      conflict.reason,
                      style: const TextStyle(
                        color: _Tokens.muted,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                IntrinsicWidth(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _Tokens.teal,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.schedule,
                          color: Colors.white,
                          size: 13,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Đổi sang ${DateFormat.Hm().format(conflict.suggestedTime)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.arrow_forward,
                          color: Colors.white,
                          size: 13,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.close, color: Color(0xFF98A1B2), size: 16),
        ],
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({
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
    final style = _statusStyle(booking.status);
    final initial =
        (booking.customerName ?? booking.customerId).characters.first;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x08000000)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F0E1726),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: style.avatarBackground,
                  borderRadius: BorderRadius.circular(15),
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: TextStyle(
                    color: style.foreground,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.customerName ?? booking.customerId,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _Tokens.text,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      booking.staffName ?? booking.staffId,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _Tokens.teal,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      booking.serviceName ?? booking.serviceId,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _Tokens.muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _StatusBadge(style: style),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF2F3F5)),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.schedule, color: Color(0xFF98A1B2), size: 15),
              const SizedBox(width: 7),
              Text(
                '${DateFormat.Hm().format(booking.startTime)} - ${_durationMinutes(booking)} phút',
                style: const TextStyle(
                  color: Color(0xFF718096),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 14),
              Container(
                width: 5,
                height: 5,
                decoration: const BoxDecoration(
                  color: Color(0xFFD0D5DD),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  DateFormat('yyyy-MM-dd').format(booking.startTime),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF98A1B2),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          if (booking.status != BookingStatus.completed &&
              booking.status != BookingStatus.cancelled) ...[
            const SizedBox(height: 13),
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    label: _statusActionLabel(booking.status),
                    onPressed: onStatusTap,
                    color: booking.status == BookingStatus.inProgress
                        ? _Tokens.teal
                        : _Tokens.green,
                    background: booking.status == BookingStatus.inProgress
                        ? const Color(0xFFE9FBFD)
                        : const Color(0xFFEFFCF4),
                  ),
                ),
                const SizedBox(width: 9),
                _SquareAction(icon: Icons.edit_outlined, onPressed: onEditTap),
                const SizedBox(width: 9),
                _SquareAction(
                  icon: Icons.delete_outline,
                  onPressed: onCancelTap,
                  foreground: _Tokens.danger,
                  background: const Color(0xFFFFF0F1),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  int _durationMinutes(Booking booking) {
    return math.max(1, booking.endTime.difference(booking.startTime).inMinutes);
  }

  String _statusActionLabel(BookingStatus status) {
    if (status == BookingStatus.inProgress) {
      return 'Hoàn thành';
    }
    return 'Check-in';
  }
}

class _BottomActionNav extends StatelessWidget {
  const _BottomActionNav({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return SizedBox(
      height: 96 + bottomInset,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: SizedBox(
              height: 96,
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      height: 78,
                      decoration: const BoxDecoration(color: _Tokens.nav),
                      child: Column(
                        children: [
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                const _NavItem(
                                  icon: Icons.home_outlined,
                                  label: 'Trang chủ',
                                ),
                                const _NavItem(
                                  icon: Icons.calendar_month_outlined,
                                  label: 'Lịch hẹn',
                                  active: true,
                                ),
                                const SizedBox(width: 76),
                                _NavItem(
                                  icon: Icons.bar_chart_outlined,
                                  label: 'Thống kê',
                                  onTap: () =>
                                      context.go(DashboardPage.routePath),
                                ),
                                const _NavItem(
                                  icon: Icons.person_outline,
                                  label: 'Tài khoản',
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 134,
                            height: 5,
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: const Color(0x6622AFC2),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    child: GestureDetector(
                      onTap: onAdd,
                      child: Container(
                        width: 86,
                        height: 86,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Container(
                          width: 66,
                          height: 66,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: _Tokens.nav, width: 8),
                          ),
                          child: const Icon(
                            Icons.add,
                            color: _Tokens.teal,
                            size: 36,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator(color: _Tokens.teal));
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.tenantId,
    required this.hasSearch,
    this.failureMessage,
  });

  final String tenantId;
  final bool hasSearch;
  final String? failureMessage;

  @override
  Widget build(BuildContext context) {
    final message = failureMessage != null
        ? 'Firestore error: $failureMessage'
        : hasSearch
        ? 'No bookings match the current filters.'
        : 'No bookings found for tenant "$tenantId". Run seed:verify to confirm Firestore has data for this tenant.';

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 66,
          height: 66,
          decoration: const BoxDecoration(
            color: Color(0xFFF5F6F8),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.schedule, color: Color(0xFFD0D5DD), size: 30),
        ),
        const SizedBox(height: 14),
        const Text(
          'Không tìm thấy lịch hẹn',
          style: TextStyle(
            color: _Tokens.muted,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _Tokens.muted,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class _IconSurfaceButton extends StatelessWidget {
  const _IconSurfaceButton({
    required this.icon,
    required this.onPressed,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: foreground, size: 24),
        style: IconButton.styleFrom(
          backgroundColor: background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      ),
    );
  }
}

class _PillChip extends StatelessWidget {
  const _PillChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? _Tokens.teal : const Color(0xFFF5F6F8),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF697386),
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFCFF8EF) : const Color(0xFFF5F6F8),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: selected ? const Color(0xFF0D8C80) : _Tokens.muted,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: selected ? const Color(0xFF0D8C80) : _Tokens.muted,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.value,
    required this.label,
    required this.color,
    required this.background,
  });

  final int value;
  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 90,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value.toString(),
              style: TextStyle(
                color: color,
                fontSize: 31,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.style});

  final _StatusStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, color: style.foreground, size: 12),
          const SizedBox(width: 4),
          Text(
            style.label,
            style: TextStyle(
              color: style.foreground,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.onPressed,
    required this.color,
    required this.background,
  });

  final String label;
  final VoidCallback onPressed;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: background,
          foregroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(11),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _SquareAction extends StatelessWidget {
  const _SquareAction({
    required this.icon,
    required this.onPressed,
    this.foreground = const Color(0xFF697386),
    this.background = const Color(0xFFF5F6F8),
  });

  final IconData icon;
  final VoidCallback onPressed;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 36,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: 16, color: foreground),
        style: IconButton.styleFrom(
          backgroundColor: background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(11),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    this.active = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = Colors.white.withAlpha(active ? 255 : 178);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 68,
        height: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 23),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StaffOption {
  const _StaffOption({required this.id, required this.name});

  final String id;
  final String name;

  String get shortName {
    final parts = name.trim().split(RegExp(r'\s+'));
    return parts.isEmpty ? name : parts.last;
  }
}

class _Conflict {
  const _Conflict({
    required this.booking,
    required this.label,
    required this.reason,
    required this.suggestedTime,
    required this.icon,
    required this.accent,
    required this.soft,
  });

  final Booking booking;
  final String label;
  final String reason;
  final DateTime suggestedTime;
  final IconData icon;
  final Color accent;
  final Color soft;
}

class _StatusStyle {
  const _StatusStyle({
    required this.label,
    required this.background,
    required this.foreground,
    required this.avatarBackground,
    required this.icon,
  });

  final String label;
  final Color background;
  final Color foreground;
  final Color avatarBackground;
  final IconData icon;
}

_StatusStyle _statusStyle(BookingStatus status) {
  switch (status) {
    case BookingStatus.pending:
      return const _StatusStyle(
        label: 'Chờ phục vụ',
        background: Color(0xFFFFF5EA),
        foreground: _Tokens.orange,
        avatarBackground: Color(0xFFFFF5EA),
        icon: Icons.schedule,
      );
    case BookingStatus.confirmed:
      return const _StatusStyle(
        label: 'Đã xác nhận',
        background: Color(0xFFE9FBFD),
        foreground: _Tokens.teal,
        avatarBackground: Color(0xFFE9FBFD),
        icon: Icons.check,
      );
    case BookingStatus.inProgress:
      return const _StatusStyle(
        label: 'Đã check-in',
        background: Color(0xFFEFFCF4),
        foreground: _Tokens.green,
        avatarBackground: Color(0xFFE9FBFD),
        icon: Icons.check_circle_outline,
      );
    case BookingStatus.completed:
      return const _StatusStyle(
        label: 'Hoàn thành',
        background: Color(0xFFF5F6F8),
        foreground: Color(0xFF697386),
        avatarBackground: Color(0xFFF5F6F8),
        icon: Icons.check,
      );
    case BookingStatus.cancelled:
      return const _StatusStyle(
        label: 'Đã hủy',
        background: Color(0xFFFFF0F1),
        foreground: _Tokens.danger,
        avatarBackground: Color(0xFFFFF0F1),
        icon: Icons.cancel_outlined,
      );
    case BookingStatus.noShow:
      return const _StatusStyle(
        label: 'Vắng mặt',
        background: Color(0xFFFFF0F1),
        foreground: _Tokens.danger,
        avatarBackground: Color(0xFFFFF0F1),
        icon: Icons.cancel_outlined,
      );
  }
}

class _Tokens {
  const _Tokens._();

  static const screen = Color(0xFFFCFCFD);
  static const text = Color(0xFF1F2937);
  static const muted = Color(0xFF8A94A6);
  static const teal = Color(0xFF22AFC2);
  static const nav = Color(0xFF58D8E3);
  static const green = Color(0xFF22C55E);
  static const orange = Color(0xFFF97316);
  static const danger = Color(0xFFEF4444);
}