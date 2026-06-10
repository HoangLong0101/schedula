import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/injection.dart';
import '../../../booking/presentation/pages/booking_page.dart';
import '../../../customer/presentation/pages/customer_page.dart';
import '../../../staff/presentation/pages/staff_page.dart';
import '../../domain/entities/dashboard_stats.dart';
import '../cubit/dashboard_cubit.dart';
import '../cubit/dashboard_state.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key, this.tenantId});

  static const routePath = '/dashboard';
  static const routeName = 'dashboard';

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
    return const Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('Tenant context is required to load the dashboard.'),
          ),
        ),
      ),
    );
  }
}

class _DashboardView extends StatelessWidget {
  const _DashboardView({required this.tenantId});

  final String tenantId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tổng quan')),
      body: RefreshIndicator(
        onRefresh: () => context.read<DashboardCubit>().load(tenantId),
        child: BlocBuilder<DashboardCubit, DashboardState>(
          builder: (context, state) {
            return switch (state) {
              DashboardInitial() || DashboardLoading() => const _LoadingView(),
              DashboardFailure(:final message) => _ErrorView(
                message: message,
                tenantId: tenantId,
              ),
              DashboardLoaded(:final stats) => _DashboardContent(stats: stats),
            };
          },
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
        Center(child: CircularProgressIndicator()),
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
    final theme = Theme.of(context);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 96),
        Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
        const SizedBox(height: 12),
        Text(
          'Không thể tải dữ liệu tổng quan',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        Center(
          child: FilledButton(
            onPressed: () => context.read<DashboardCubit>().load(tenantId),
            child: const Text('Thử lại'),
          ),
        ),
      ],
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({required this.stats});

  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Hoạt động kinh doanh',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Số liệu tổng hợp từ các lượt đặt lịch của toàn bộ chi nhánh.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 20),
        _KpiGrid(stats: stats),
        const SizedBox(height: 24),
        _TodayAppointmentsSection(stats: stats),
        const SizedBox(height: 24),
        _TrendChartCard(stats: stats),
        const SizedBox(height: 24),
        _HeatmapCard(stats: stats),
        const SizedBox(height: 24),
        _StaffStatusCard(stats: stats),
        const SizedBox(height: 24),
        _CustomerOverviewCard(stats: stats),
        const SizedBox(height: 24),
        Text(
          'Truy cập nhanh',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        const _QuickLinks(),
      ],
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.stats});

  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final cancellationRate =
        '${(stats.cancellationRate * 100).toStringAsFixed(1)}%';

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _KpiCard(
          icon: Icons.event_note_outlined,
          label: 'Tổng lượt đặt',
          value: '${stats.totalBookings}',
          color: colorScheme.primary,
        ),
        _KpiCard(
          icon: Icons.upcoming_outlined,
          label: 'Sắp tới',
          value: '${stats.upcomingBookings}',
          color: colorScheme.tertiary,
        ),
        _KpiCard(
          icon: Icons.check_circle_outline,
          label: 'Hoàn thành',
          value: '${stats.completedBookings}',
          color: colorScheme.secondary,
        ),
        _KpiCard(
          icon: Icons.person_off_outlined,
          label: 'Không đến',
          value: '${stats.noShowBookings}',
          color: colorScheme.onErrorContainer,
        ),
        _KpiCard(
          icon: Icons.cancel_outlined,
          label: 'Tỉ lệ huỷ',
          value: cancellationRate,
          color: colorScheme.error,
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayAppointmentsSection extends StatelessWidget {
  const _TodayAppointmentsSection({required this.stats});

  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appointments = stats.todayAppointments;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Lịch hẹn hôm nay',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          appointments.isEmpty
              ? 'Không có lịch hẹn nào được lên lịch hôm nay.'
              : '${appointments.length} lượt đặt được lên lịch hôm nay.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        if (appointments.isNotEmpty)
          SizedBox(
            height: 132,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: appointments.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) =>
                  _AppointmentCard(appointment: appointments[index]),
            ),
          ),
      ],
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
      width: 200,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.event_outlined,
                      size: 18,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    DateFormat.Hm().format(appointment.startTime),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                appointment.customerName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                appointment.serviceName.isEmpty
                    ? 'Dịch vụ'
                    : appointment.serviceName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
              const Spacer(),
              Text(
                appointment.staffName.isEmpty ? '—' : appointment.staffName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrendChartCard extends StatelessWidget {
  const _TrendChartCard({required this.stats});

  final DashboardStats stats;

  static const _weekdayLabels = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
  static const _chartHeight = 90.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final peak = stats.peakDailyTrendCount;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Lượt đặt theo ngày',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tổng số lượt đặt trong 7 ngày gần nhất',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            if (stats.dailyTrend.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Chưa có đủ dữ liệu để hiển thị.',
                  style: theme.textTheme.bodyMedium,
                ),
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final point in stats.dailyTrend)
                    Expanded(
                      child: _TrendBar(
                        point: point,
                        peak: peak,
                        maxBarHeight: _chartHeight,
                        color: theme.colorScheme.primary,
                        label: _weekdayLabels[point.date.weekday - 1],
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _TrendBar extends StatelessWidget {
  const _TrendBar({
    required this.point,
    required this.peak,
    required this.maxBarHeight,
    required this.color,
    required this.label,
  });

  final BookingTrendPoint point;
  final int peak;
  final double maxBarHeight;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ratio = peak == 0 ? 0.0 : point.count / peak;
    final barHeight = point.count == 0
        ? 2.0
        : (maxBarHeight * ratio).clamp(4.0, maxBarHeight);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${point.count}', style: theme.textTheme.labelSmall),
          const SizedBox(height: 4),
          Container(
            height: barHeight,
            decoration: BoxDecoration(
              color: point.count == 0 ? color.withValues(alpha: 0.12) : color,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(height: 6),
          Text(label, style: theme.textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _HeatmapCard extends StatelessWidget {
  const _HeatmapCard({required this.stats});

  final DashboardStats stats;

  static const _weekdayLabels = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
  static const _periodLabels = ['Sáng', 'Chiều', 'Tối'];

  int _countFor(int weekday, BookingPeriod period) {
    for (final cell in stats.heatmap) {
      if (cell.weekday == weekday && cell.period == period) {
        return cell.count;
      }
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final peak = stats.peakHeatmapCount;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Khung giờ bận rộn',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Số lượt đặt theo ngày trong 30 ngày gần nhất',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            if (stats.heatmap.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Chưa có đủ dữ liệu để hiển thị.',
                  style: theme.textTheme.bodyMedium,
                ),
              )
            else ...[
              Row(
                children: [
                  const SizedBox(width: 32),
                  for (final label in _periodLabels)
                    Expanded(
                      child: Center(
                        child: Text(label, style: theme.textTheme.labelSmall),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              for (var weekday = 1; weekday <= 7; weekday++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 32,
                        child: Text(
                          _weekdayLabels[weekday - 1],
                          style: theme.textTheme.labelMedium,
                        ),
                      ),
                      for (final period in BookingPeriod.values)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: _HeatmapCell(
                              count: _countFor(weekday, period),
                              peak: peak,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HeatmapCell extends StatelessWidget {
  const _HeatmapCell({
    required this.count,
    required this.peak,
    required this.color,
  });

  final int count;
  final int peak;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final intensity = peak == 0 ? 0.0 : count / peak;
    final background = count == 0
        ? color.withValues(alpha: 0.05)
        : color.withValues(alpha: 0.15 + intensity * 0.65);

    return Container(
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: intensity > 0.55 ? Colors.white : color,
        ),
      ),
    );
  }
}

class _StaffStatusCard extends StatelessWidget {
  const _StaffStatusCard({required this.stats});

  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final staff = stats.staffAvailability;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nhân viên',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Trạng thái làm việc hiện tại',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            if (staff.isEmpty)
              Text(
                'Chưa có hồ sơ nhân viên nào.',
                style: theme.textTheme.bodyMedium,
              )
            else
              for (var i = 0; i < staff.length; i++)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: i == staff.length - 1 ? 0 : 10,
                  ),
                  child: _StaffStatusRow(staff: staff[i]),
                ),
          ],
        ),
      ),
    );
  }
}

class _StaffStatusRow extends StatelessWidget {
  const _StaffStatusRow({required this.staff});

  final StaffAvailability staff;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = staff.inSession
        ? theme.colorScheme.tertiary
        : theme.colorScheme.secondary;
    final label = staff.inSession ? 'Đang phục vụ' : 'Sẵn sàng';

    return Row(
      children: [
        Container(
          width: 4,
          height: 36,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            staff.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _CustomerOverviewCard extends StatelessWidget {
  const _CustomerOverviewCard({required this.stats});

  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final overview = stats.customerOverview;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => context.go(CustomerPage.routePath),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.groups_outlined,
                      color: theme.colorScheme.onPrimary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${overview.totalCustomers} khách hàng',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Hồ sơ và lịch sử khách hàng',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: theme.colorScheme.outline),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _CustomerStatChip(
                      icon: Icons.repeat,
                      label: 'Khách quay lại',
                      value: overview.returningCustomers,
                      color: theme.colorScheme.secondary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _CustomerStatChip(
                      icon: Icons.notifications_outlined,
                      label: 'Cần chăm sóc lại',
                      value: overview.needsFollowUpCustomers,
                      color: theme.colorScheme.tertiary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomerStatChip extends StatelessWidget {
  const _CustomerStatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$value',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickLinks extends StatelessWidget {
  const _QuickLinks();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _ActionCard(
          title: 'Lịch đặt',
          subtitle: 'Xem và quản lý các lượt đặt.',
          icon: Icons.calendar_month_outlined,
          onTap: () => context.go(BookingPage.routePath),
        ),
        _ActionCard(
          title: 'Nhân viên',
          subtitle: 'Hồ sơ, ca làm và phân công.',
          icon: Icons.groups_outlined,
          onTap: () => context.go(StaffPage.routePath),
        ),
        _ActionCard(
          title: 'Khách hàng',
          subtitle: 'Hồ sơ và lịch sử khách hàng.',
          icon: Icons.person_outline,
          onTap: () => context.go(CustomerPage.routePath),
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 28),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
