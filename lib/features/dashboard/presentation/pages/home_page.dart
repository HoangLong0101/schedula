import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/injection.dart';
import '../../../booking/presentation/pages/booking_page.dart';
import '../../../customer/presentation/pages/customer_page.dart';
import '../../../notification/presentation/pages/notification_page.dart';
import '../../../staff/presentation/pages/staff_page.dart';
import '../../domain/entities/dashboard_stats.dart';
import '../cubit/dashboard_cubit.dart';
import '../cubit/dashboard_state.dart';

final ValueNotifier<int> dashboardRefreshNotifier = ValueNotifier<int>(0);

void requestDashboardRefresh() {
  dashboardRefreshNotifier.value++;
}

class HomePage extends StatelessWidget {
  const HomePage({super.key, this.tenantId});

  static const routePath = '/dashboard';
  static const routeName = 'home';

  final String? tenantId;

  @override
  Widget build(BuildContext context) {
    final tenantId = this.tenantId;
    if (tenantId == null || tenantId.isEmpty) {
      return const _TenantMissingView();
    }

    return BlocProvider(
      create: (_) => getIt<DashboardCubit>()..load(tenantId),
      child: _DashboardView(tenantId: tenantId),
    );
  }
}

class _TenantMissingView extends StatelessWidget {
  const _TenantMissingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text('Thiếu thông tin cơ sở để tải trang tổng quan.'),
      ),
    );
  }
}

class _DashboardView extends StatefulWidget {
  const _DashboardView({required this.tenantId});

  final String tenantId;

  @override
  State<_DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<_DashboardView> {
  @override
  void initState() {
    super.initState();
    dashboardRefreshNotifier.addListener(_refreshDashboard);
  }

  @override
  void dispose() {
    dashboardRefreshNotifier.removeListener(_refreshDashboard);
    super.dispose();
  }

  void _refreshDashboard() {
    if (!mounted) return;
    context.read<DashboardCubit>().load(
      widget.tenantId,
      forceRefresh: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: _HomeColors.teal,
          onRefresh: () => context.read<DashboardCubit>().load(
            widget.tenantId,
            forceRefresh: true,
          ),
          child: BlocBuilder<DashboardCubit, DashboardState>(
            builder: (context, state) {
              return switch (state) {
                DashboardInitial() ||
                DashboardLoading() => const _LoadingView(),
                DashboardFailure(:final message) => _ErrorView(
                  message: message,
                  tenantId: widget.tenantId,
                ),
                DashboardLoaded(:final stats) => _HomeContent(stats: stats),
              };
            },
          ),
        ),
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: const [
        SizedBox(height: 220),
        Center(child: CircularProgressIndicator(color: _HomeColors.teal)),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.tenantId});

  final String message;
  final String tenantId;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 120),
        const Icon(Icons.error_outline, color: _HomeColors.orange, size: 48),
        const SizedBox(height: 12),
        Text(
          'Không thể tải trang chủ',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        Center(
          child: FilledButton(
            onPressed: () => context.read<DashboardCubit>().load(
              tenantId,
              forceRefresh: true,
            ),
            child: const Text('Thử lại'),
          ),
        ),
      ],
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({required this.stats});

  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final todayCount = stats.todayAppointments.length;
    final newCustomers =
        (stats.customerOverview.totalCustomers -
                stats.customerOverview.returningCustomers)
            .clamp(0, stats.customerOverview.totalCustomers);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 34),
      children: [
        const _HomeHeader(),
        const SizedBox(height: 26),
        Text(
          'Dashboard',
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
            color: _HomeColors.ink,
            fontWeight: FontWeight.w900,
            fontSize: 28,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Chào mừng,',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: _HomeColors.muted,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            _AddBookingButton(onTap: () => context.go(BookingPage.routePath)),
            const Spacer(),
            _InlineLink(
              label: 'Xem thêm',
              onTap: () => context.go(BookingPage.routePath),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _KpiCard(
                label: 'Lịch hẹn hôm nay',
                value: todayCount,
                delta: '+2.8%',
                deltaPositive: true,
                icon: Icons.arrow_outward,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _KpiCard(
                label: 'khách mới đặt lịch',
                value: newCustomers,
                delta: '-3.8%',
                deltaPositive: false,
                icon: Icons.south_east,
              ),
            ),
          ],
        ),
        const SizedBox(height: 30),
        _SectionHeader(title: 'Lịch sắp tới', trailing: _todayLabel()),
        const SizedBox(height: 16),
        _UpcomingAppointments(appointments: stats.todayAppointments),
        const SizedBox(height: 30),
        _SectionHeader(
          title: 'Nhân viên',
          linkLabel: 'Xem thêm',
          onTap: () => context.push(StaffPage.routePath),
        ),
        const SizedBox(height: 16),
        _StaffPanel(staff: stats.staffAvailability),
        const SizedBox(height: 30),
        _SectionHeader(
          title: 'Quản lý Khách hàng',
          linkLabel: 'Xem tất cả',
          onTap: () => context.push(CustomerPage.routePath),
        ),
        const SizedBox(height: 16),
        _CustomerPanel(overview: stats.customerOverview),
        const SizedBox(height: 30),
        _SectionHeader(
          title: 'Đề xuất từ AI',
          leadingIcon: Icons.auto_awesome,
          linkLabel: 'Xem chi tiết',
          onTap: () => context.go('/statistics'),
        ),
        const SizedBox(height: 16),
        const _AiInsights(),
      ],
    );
  }

  String _todayLabel() {
    final now = DateTime.now();
    return '${now.day} Tháng ${now.month} ${now.year}';
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Color(0xFFE1E1E4),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_outline, color: Color(0xFF777A80)),
            ),
            Positioned(
              right: 1,
              bottom: 1,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: const Color(0xFF75EA6A),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
          ],
        ),
        const Spacer(),
        const _SchedulaLogo(),
        const Spacer(),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => context.push(NotificationPage.routePath),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: _HomeShadow.card,
                ),
                child: const Icon(
                  Icons.notifications_none,
                  color: _HomeColors.teal,
                  size: 23,
                ),
              ),
              Positioned(
                right: -3,
                top: -4,
                child: Container(
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: _HomeColors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '3',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SchedulaLogo extends StatelessWidget {
  const _SchedulaLogo();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'resource/schedula_logo.png',
      width: 166,
      height: 42,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );
  }
}

class _AddBookingButton extends StatelessWidget {
  const _AddBookingButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          boxShadow: _HomeShadow.card,
          border: Border.all(color: _HomeColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.add_circle_outline,
              size: 20,
              color: _HomeColors.muted,
            ),
            const SizedBox(width: 8),
            Text(
              'Thêm lịch hẹn',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: _HomeColors.muted,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineLink extends StatelessWidget {
  const _InlineLink({
    required this.label,
    required this.onTap,
    this.chevron = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool chevron;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: _HomeColors.tealDark,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (chevron) ...[
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right,
              color: _HomeColors.tealDark,
              size: 18,
            ),
          ],
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.delta,
    required this.deltaPositive,
    required this.icon,
  });

  final String label;
  final int value;
  final String delta;
  final bool deltaPositive;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _HomeCard(
      minHeight: 198,
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Icon(
                  Icons.circle,
                  size: 15,
                  color: _HomeColors.greenDot,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: _HomeColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(icon, color: _HomeColors.ink, size: 18),
            ],
          ),
          const SizedBox(height: 30),
          Text(
            '$value',
            style: theme.textTheme.headlineLarge?.copyWith(
              color: _HomeColors.hotOrange,
              fontWeight: FontWeight.w900,
              fontSize: 68,
              height: 0.95,
            ),
          ),
          const SizedBox(height: 12),
          RichText(
            text: TextSpan(
              style: theme.textTheme.bodySmall?.copyWith(
                color: _HomeColors.muted,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
              children: [
                TextSpan(
                  text: delta,
                  style: TextStyle(
                    color: deltaPositive ? _HomeColors.green : _HomeColors.red,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const TextSpan(text: ' số lượng khách so với hôm qua'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.trailing,
    this.linkLabel,
    this.onTap,
    this.leadingIcon,
  });

  final String title;
  final String? trailing;
  final String? linkLabel;
  final VoidCallback? onTap;
  final IconData? leadingIcon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (leadingIcon != null) ...[
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _HomeColors.tealDark,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(leadingIcon, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: _HomeColors.ink,
              fontWeight: FontWeight.w900,
              fontSize: 24,
            ),
          ),
        ),
        if (trailing != null)
          Text(
            trailing ?? '',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: _HomeColors.muted,
              fontWeight: FontWeight.w800,
            ),
          )
        else if (linkLabel != null && onTap != null)
          _InlineLink(
            label: linkLabel ?? '',
            onTap: onTap ?? () {},
            chevron: true,
          ),
      ],
    );
  }
}

class _UpcomingAppointments extends StatelessWidget {
  const _UpcomingAppointments({required this.appointments});

  final List<DashboardAppointment> appointments;

  @override
  Widget build(BuildContext context) {
    if (appointments.isEmpty) {
      return const _EmptyUpcomingAppointments();
    }

    return SizedBox(
      height: 222,
      child: ListView.separated(
        clipBehavior: Clip.none,
        scrollDirection: Axis.horizontal,
        itemCount: appointments.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          return _AppointmentCard(appointment: appointments[index]);
        },
      ),
    );
  }
}

class _EmptyUpcomingAppointments extends StatelessWidget {
  const _EmptyUpcomingAppointments();

  @override
  Widget build(BuildContext context) {
    return _HomeCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      child: Column(
        children: [
          const Icon(
            Icons.event_available_outlined,
            size: 34,
            color: _HomeColors.grayBlue,
          ),
          const SizedBox(height: 10),
          Text(
            'Chưa có lịch hẹn sắp tới',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: _HomeColors.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Lịch hẹn mới của tenant này sẽ xuất hiện tại đây.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: _HomeColors.muted),
          ),
        ],
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({required this.appointment});

  final DashboardAppointment appointment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 348,
      child: _HomeCard(
        padding: const EdgeInsets.all(20),
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
                        appointment.customerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: _HomeColors.ink,
                          fontWeight: FontWeight.w900,
                          fontSize: 24,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        appointment.staffName.isEmpty
                            ? 'Nhân viên phụ trách'
                            : appointment.staffName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: _HomeColors.hotOrange,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        appointment.serviceName.isEmpty
                            ? 'Dịch vụ chăm sóc'
                            : appointment.serviceName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: _HomeColors.muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 50,
                  height: 50,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _HomeColors.tealWash,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(
                    Icons.calendar_month_outlined,
                    color: _HomeColors.teal,
                  ),
                ),
              ],
            ),
            const Spacer(),
            RichText(
              text: TextSpan(
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: _HomeColors.muted,
                  fontWeight: FontWeight.w500,
                ),
                children: [
                  const TextSpan(text: 'Bắt đầu lúc '),
                  TextSpan(
                    text: DateFormat.Hm().format(appointment.startTime),
                    style: const TextStyle(
                      color: _HomeColors.ink,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: const [
                _SmallActionButton(icon: Icons.edit_outlined),
                SizedBox(width: 12),
                _SmallActionButton(icon: Icons.delete_outline, danger: true),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SmallActionButton extends StatelessWidget {
  const _SmallActionButton({required this.icon, this.danger = false});

  final IconData icon;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _HomeColors.soft,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(
        icon,
        size: 17,
        color: danger ? _HomeColors.red : _HomeColors.grayBlue,
      ),
    );
  }
}

class _StaffPanel extends StatelessWidget {
  const _StaffPanel({required this.staff});

  final List<StaffAvailability> staff;

  @override
  Widget build(BuildContext context) {
    return _HomeCard(
      padding: EdgeInsets.zero,
      child: staff.isEmpty
          ? const _EmptyStaffPanel()
          : Column(
              children: [
                for (var i = 0; i < staff.length; i++)
                  _StaffRow(
                    staff: staff[i],
                    index: i,
                    isLast: i == staff.length - 1,
                  ),
              ],
            ),
    );
  }
}

class _EmptyStaffPanel extends StatelessWidget {
  const _EmptyStaffPanel();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Row(
        children: [
          const Icon(
            Icons.groups_outlined,
            color: _HomeColors.grayBlue,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Chưa có nhân viên trong tenant này.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: _HomeColors.muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _StaffRow extends StatelessWidget {
  const _StaffRow({
    required this.staff,
    required this.index,
    required this.isLast,
  });

  final StaffAvailability staff;
  final int index;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final normalizedStatus = staff.status.trim().toLowerCase();
    final inSession =
        normalizedStatus == 'in_session' ||
        (staff.inSession && normalizedStatus != 'available');
    final absent = normalizedStatus == 'absent';
    final available = !inSession && !absent;
    final color = available ? _HomeColors.staffGreen : _HomeColors.staffAmber;
    final label = switch ((absent, inSession)) {
      (true, _) => 'Vắng mặt',
      (_, true) => 'Trong phiên',
      _ => 'Sẵn sàng',
    };
    final role = switch (index) {
      0 => 'Chuyên gia da mặt',
      1 => 'Massage',
      2 => 'Chuyên gia da liễu',
      _ => 'Chăm sóc tóc',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isLast ? Colors.transparent : _HomeColors.divider,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 50,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  staff.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  role,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _HomeColors.lightText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: available
                  ? _HomeColors.staffGreenBg
                  : _HomeColors.staffAmberBg,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerPanel extends StatelessWidget {
  const _CustomerPanel({required this.overview});

  final CustomerOverview overview;

  @override
  Widget build(BuildContext context) {
    final total = overview.totalCustomers;
    final returning = overview.returningCustomers;
    final birthday = total > 2 ? 2 : total;
    final followUp = overview.needsFollowUpCustomers;

    return _HomeCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _HomeColors.tealDark,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.groups_outlined,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$total khách hàng',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: _HomeColors.ink,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Hồ sơ, liệu trình, sinh nhật & ghi chú',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: _HomeColors.muted),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: _HomeColors.grayBlue),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _CustomerChip(
                  icon: Icons.cake_outlined,
                  value: birthday,
                  label: 'Sinh nhật',
                  bg: const Color(0xFFFDECF6),
                  color: const Color(0xFFEC4899),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _CustomerChip(
                  icon: Icons.circle,
                  value: returning,
                  label: 'Liệu trình',
                  bg: const Color(0xFFEAF8F7),
                  color: _HomeColors.tealDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _CustomerChip(
                  icon: Icons.notifications_none,
                  value: followUp,
                  label: 'Tái khám',
                  bg: const Color(0xFFFFF3E8),
                  color: _HomeColors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CustomerChip extends StatelessWidget {
  const _CustomerChip({
    required this.icon,
    required this.value,
    required this.label,
    required this.bg,
    required this.color,
  });

  final IconData icon;
  final int value;
  final String label;
  final Color bg;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: icon == Icons.circle ? 10 : 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$value',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AiInsights extends StatelessWidget {
  const _AiInsights();

  @override
  Widget build(BuildContext context) {
    const insights = [
      _InsightData(
        icon: Icons.trending_up,
        title: 'Khách hàng mới tăng 15%',
        description:
            'Tháng này, tỉ lệ khách hàng mới tăng 15% so với tháng trước. Hãy duy trì chương trình giới thiệu hiện tại.',
        tag: 'Xu hướng',
        color: _HomeColors.green,
        bg: _HomeColors.greenBg,
      ),
      _InsightData(
        icon: Icons.access_time,
        title: 'Khung 13:00 thử lịch',
        description:
            'AI đề xuất chạy ưu đãi 15% trong khung giờ trống để tăng lấp đầy.',
        tag: 'Đề xuất',
        color: _HomeColors.orange,
        bg: _HomeColors.orangeBg,
      ),
    ];

    return SizedBox(
      height: 250,
      child: ListView.separated(
        clipBehavior: Clip.none,
        scrollDirection: Axis.horizontal,
        itemCount: insights.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, index) => _InsightCard(data: insights[index]),
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.data});

  final _InsightData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 326,
      child: _HomeCard(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: data.bg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(data.icon, color: data.color, size: 20),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: data.bg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    data.tag,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: data.color,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              data.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                color: _HomeColors.ink,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              data.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: _HomeColors.muted,
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Row(
              children: [
                Text(
                  'Xem thống kê',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: data.color,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right, size: 16, color: data.color),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InsightData {
  const _InsightData({
    required this.icon,
    required this.title,
    required this.description,
    required this.tag,
    required this.color,
    required this.bg,
  });

  final IconData icon;
  final String title;
  final String description;
  final String tag;
  final Color color;
  final Color bg;
}

class _HomeCard extends StatelessWidget {
  const _HomeCard({
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.minHeight,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double? minHeight;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: minHeight ?? 0),
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _HomeColors.border),
        boxShadow: _HomeShadow.card,
      ),
      child: child,
    );
  }
}

class _HomeColors {
  static const ink = Color(0xFF050505);
  static const muted = Color(0xFF7A7D85);
  static const lightText = Color(0xFFA4A5AA);
  static const soft = Color(0xFFF7F8FA);
  static const divider = Color(0x0D000000);
  static const border = Color(0x12000000);
  static const teal = Color(0xFF22AFC2);
  static const tealDark = Color(0xFF148A9C);
  static const tealWash = Color(0xFFE0F8FB);
  static const hotOrange = Color(0xFFF64404);
  static const orange = Color(0xFFFF6B1A);
  static const orangeBg = Color(0xFFFFF1E6);
  static const red = Color(0xFFFF5A63);
  static const green = Color(0xFF22C55E);
  static const greenBg = Color(0xFFE7F7EC);
  static const greenDot = Color(0xFF63CD5B);
  static const grayBlue = Color(0xFF8E99AA);
  static const staffGreen = Color(0xFF54C94E);
  static const staffGreenBg = Color(0xFFE1FFDE);
  static const staffAmber = Color(0xFFD29430);
  static const staffAmberBg = Color(0xFFFFE9AD);
}

class _HomeShadow {
  static final card = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.16),
      blurRadius: 7,
      offset: const Offset(0, 2),
    ),
  ];
}
