import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../domain/entities/dashboard_stats.dart';
import '../cubit/dashboard_cubit.dart';
import '../cubit/dashboard_state.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key, this.tenantId});

  static const routePath = '/statistics';
  static const routeName = 'statistics';

  final String? tenantId;

  @override
  Widget build(BuildContext context) {
    final tenantId = this.tenantId;
    if (tenantId == null || tenantId.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Tenant context is required to load statistics.'),
        ),
      );
    }

    return BlocProvider(
      create: (_) => getIt<DashboardCubit>()..load(tenantId),
      child: _StatisticsView(tenantId: tenantId),
    );
  }
}

class _StatisticsView extends StatefulWidget {
  const _StatisticsView({required this.tenantId});

  final String tenantId;

  @override
  State<_StatisticsView> createState() => _StatisticsViewState();
}

class _StatisticsViewState extends State<_StatisticsView> {
  int _rangeIndex = 1;
  int _tabIndex = 0;

  static const _ranges = ['Hôm nay', 'Tuần này', 'Tháng này', 'Năm nay'];
  static const _tabs = ['Vận hành', 'Tài nguyên', 'Nhân viên & KH'];

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _StatsColors.background,
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: _StatsColors.teal,
          onRefresh: () => context.read<DashboardCubit>().load(
            widget.tenantId,
            forceRefresh: true,
          ),
          child: BlocBuilder<DashboardCubit, DashboardState>(
            builder: (context, state) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 34),
                children: [
                  const _StatisticsHeader(),
                  const SizedBox(height: 20),
                  _Selector(
                    labels: _ranges,
                    selectedIndex: _rangeIndex,
                    compact: true,
                    onChanged: (index) => setState(() => _rangeIndex = index),
                  ),
                  const SizedBox(height: 18),
                  _Selector(
                    labels: _tabs,
                    selectedIndex: _tabIndex,
                    onChanged: (index) => setState(() => _tabIndex = index),
                  ),
                  const SizedBox(height: 24),
                  switch (state) {
                    DashboardInitial() ||
                    DashboardLoading() => const _LoadingStats(),
                    DashboardFailure(:final message) => _StatsError(
                      message: message,
                      tenantId: widget.tenantId,
                    ),
                    DashboardLoaded(:final stats) => AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: KeyedSubtree(
                        key: ValueKey(_tabIndex),
                        child: switch (_tabIndex) {
                          0 => _OperationsTab(stats: stats),
                          1 => _ResourcesTab(stats: stats),
                          _ => _PeopleTab(stats: stats),
                        },
                      ),
                    ),
                  },
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _StatisticsHeader extends StatelessWidget {
  const _StatisticsHeader();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: _StatsShadow.soft,
            ),
            child: const SizedBox(
              width: 48,
              height: 48,
              child: Icon(Icons.chevron_left, color: _StatsColors.ink),
            ),
          ),
        ),
        Text(
          'Thống Kê',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: _StatsColors.ink,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _Selector extends StatelessWidget {
  const _Selector({
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
    this.compact = false,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: compact ? EdgeInsets.zero : const EdgeInsets.all(6),
      decoration: compact
          ? null
          : BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _StatsColors.border),
              boxShadow: _StatsShadow.soft,
            ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(left: i == 0 ? 0 : 6),
                child: GestureDetector(
                  onTap: () => onChanged(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: compact ? 40 : 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selectedIndex == i
                          ? _StatsColors.tealDark
                          : Colors.white,
                      borderRadius: BorderRadius.circular(compact ? 20 : 15),
                      boxShadow: selectedIndex == i ? _StatsShadow.teal : null,
                    ),
                    child: Text(
                      labels[i],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: selectedIndex == i
                            ? Colors.white
                            : _StatsColors.muted,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LoadingStats extends StatelessWidget {
  const _LoadingStats();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 160),
      child: Center(child: CircularProgressIndicator(color: _StatsColors.teal)),
    );
  }
}

class _StatsError extends StatelessWidget {
  const _StatsError({required this.message, required this.tenantId});

  final String message;
  final String tenantId;

  @override
  Widget build(BuildContext context) {
    return _StatsCard(
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: _StatsColors.orange, size: 42),
          const SizedBox(height: 12),
          Text(
            'Không thể tải dữ liệu thống kê',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => context.read<DashboardCubit>().load(
              tenantId,
              forceRefresh: true,
            ),
            child: const Text('Thử lại'),
          ),
        ],
      ),
    );
  }
}

class _OperationsTab extends StatelessWidget {
  const _OperationsTab({required this.stats});

  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final revenue = stats.totalRevenue;
    final average = stats.completedBookings == 0
        ? 0
        : revenue ~/ stats.completedBookings;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RevenueCard(
          revenue: revenue,
          collected: stats.completedBookings,
          pending: stats.upcomingBookings,
          average: average,
        ),
        const SizedBox(height: 20),
        Text(
          'Tổng quan lịch hẹn',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: _StatsColors.muted,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _MetricTile(
                icon: Icons.calendar_month_outlined,
                color: _StatsColors.teal,
                bg: _StatsColors.tealWash,
                value: '${stats.totalBookings}',
                suffix: 'ca',
                label: 'Tổng lịch hẹn',
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _MetricTile(
                icon: Icons.check_circle_outline,
                color: _StatsColors.green,
                bg: _StatsColors.greenWash,
                value: '${stats.completedBookings}',
                suffix: 'ca',
                label: 'Đã hoàn thành',
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _BusyHoursCard(stats: stats),
        const SizedBox(height: 20),
        _CancellationReasonsCard(stats: stats),
      ],
    );
  }
}

class _ResourcesTab extends StatelessWidget {
  const _ResourcesTab({required this.stats});

  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final usage = stats.completedBookings + stats.upcomingBookings;
    final activeRate = stats.totalBookings == 0
        ? 0
        : ((usage / stats.totalBookings) * 100).round().clamp(0, 100).toInt();
    final completedRate = stats.totalBookings == 0
        ? 0
        : ((stats.completedBookings / stats.totalBookings) * 100)
              .round()
              .clamp(0, 100)
              .toInt();
    final cancelledRate = (stats.cancellationRate * 100)
        .round()
        .clamp(0, 100)
        .toInt();
    return Column(
      children: [
        _ProgressCard(
          icon: Icons.bed_outlined,
          title: 'Giường sử dụng nhiều nhất',
          rows: [
            _ProgressRow(rank: 1, label: 'Dang hoat dong', value: activeRate),
            _ProgressRow(
              rank: 2,
              label: 'Da hoan thanh',
              value: completedRate,
            ),
          ],
        ),
        const SizedBox(height: 20),
        _ProgressCard(
          icon: Icons.bed_outlined,
          iconColor: _StatsColors.orange,
          title: 'Giường ít sử dụng',
          rows: [
            _ProgressRow(
              label: 'Ty le huy',
              value: cancelledRate,
              color: _StatsColors.orange,
            ),
          ],
          notice: 'Có thể tối ưu phân ca để cân bằng tần suất sử dụng giường.',
        ),
        const SizedBox(height: 20),
        _MaintenanceCard(progress: activeRate),
      ],
    );
  }
}

class _PeopleTab extends StatelessWidget {
  const _PeopleTab({required this.stats});

  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final overview = stats.customerOverview;
    final returningRate = overview.totalCustomers == 0
        ? 0.0
        : overview.returningCustomers / overview.totalCustomers;
    final newCustomers = (overview.totalCustomers - overview.returningCustomers)
        .clamp(0, 99);

    return Column(
      children: [
        _TopStaffCard(staff: stats.staffAvailability),
        const SizedBox(height: 20),
        _ReturnCustomerCard(
          newCustomers: newCustomers,
          returningRate: returningRate,
        ),
        const SizedBox(height: 20),
        const _RatingCard(),
      ],
    );
  }
}

class _RevenueCard extends StatelessWidget {
  const _RevenueCard({
    required this.revenue,
    required this.collected,
    required this.pending,
    required this.average,
  });

  final int revenue;
  final int collected;
  final int pending;
  final int average;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 254,
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: _StatsColors.tealDark,
        borderRadius: BorderRadius.circular(28),
        boxShadow: _StatsShadow.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Badge(
                icon: Icons.attach_money,
                color: Colors.white,
                bg: Colors.white.withValues(alpha: 0.16),
              ),
              const SizedBox(width: 12),
              Text(
                'Doanh thu tuần này',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  '↗ 15%',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            _formatCompactCurrency(revenue),
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
              color: Colors.white,
              fontSize: 40,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 24),
          Divider(color: Colors.white.withValues(alpha: 0.16), height: 1),
          const SizedBox(height: 24),
          Row(
            children: [
              _RevenueMeta(value: '$collected', label: 'Đã thu'),
              _RevenueMeta(value: '$pending', label: 'Chờ thu'),
              _RevenueMeta(
                value: _formatShortCurrency(average),
                label: 'TB/ca',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RevenueMeta extends StatelessWidget {
  const _RevenueMeta({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.82),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.color,
    required this.bg,
    required this.value,
    required this.suffix,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final Color bg;
  final String value;
  final String suffix;
  final String label;

  @override
  Widget build(BuildContext context) {
    return _StatsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Badge(icon: icon, color: color, bg: bg),
          const SizedBox(height: 30),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    color: _StatsColors.ink,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                TextSpan(
                  text: ' $suffix',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _StatsColors.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: _StatsColors.muted)),
        ],
      ),
    );
  }
}

class _BusyHoursCard extends StatelessWidget {
  const _BusyHoursCard({required this.stats});

  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final counts = stats.hourlyBookingCounts.isEmpty
        ? List<int>.filled(12, 0)
        : stats.hourlyBookingCounts;
    final peak = counts.reduce((a, b) => a > b ? a : b);

    return _StatsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle(
            icon: Icons.access_time,
            title: 'Khung giờ đông khách nhất',
          ),
          const SizedBox(height: 82),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < counts.length; i++)
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '${counts[i]}',
                        style: TextStyle(
                          fontSize: 10,
                          color: counts[i] == peak
                              ? _StatsColors.tealDark
                              : _StatsColors.muted,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 4,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: counts[i] == peak
                              ? _StatsColors.tealDark
                              : _StatsColors.tealWash,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('${8 + i}h', style: const TextStyle(fontSize: 10)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: const [
              Expanded(
                child: _MiniInsight(
                  icon: Icons.trending_up,
                  label: 'Cao điểm',
                  value: '17:00 - 19:00',
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: _MiniInsight(
                  icon: Icons.trending_down,
                  label: 'Ít khách',
                  value: '13:00 - 15:00',
                  muted: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniInsight extends StatelessWidget {
  const _MiniInsight({
    required this.icon,
    required this.label,
    required this.value,
    this.muted = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: muted ? _StatsColors.softPanel : _StatsColors.tealWash,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: muted ? _StatsColors.grayBlue : _StatsColors.tealDark,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: _StatsColors.muted,
                    fontSize: 11,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _StatsColors.ink,
                    fontWeight: FontWeight.w900,
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

class _CancellationReasonsCard extends StatelessWidget {
  const _CancellationReasonsCard({required this.stats});

  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    return _StatsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _CardTitle(
            icon: Icons.cancel_outlined,
            iconColor: _StatsColors.orange,
            title: 'Lý do hủy phổ biến',
          ),
          SizedBox(height: 18),
          _ReasonBar(label: 'Khách bận đột xuất', value: 45),
          _ReasonBar(label: 'Đổi giờ hẹn', value: 30),
          _ReasonBar(label: 'Quên lịch', value: 25),
        ],
      ),
    );
  }
}

class _ReasonBar extends StatelessWidget {
  const _ReasonBar({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          Row(
            children: [
              Text(label),
              const Spacer(),
              Text(
                '$value%',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _Meter(value: value / 100),
        ],
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.icon,
    required this.title,
    required this.rows,
    this.iconColor = _StatsColors.tealDark,
    this.notice,
  });

  final IconData icon;
  final String title;
  final List<_ProgressRow> rows;
  final Color iconColor;
  final String? notice;

  @override
  Widget build(BuildContext context) {
    return _StatsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle(icon: icon, iconColor: iconColor, title: title),
          const SizedBox(height: 18),
          for (final row in rows) row,
          if (notice != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _StatsColors.orangeWash,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: _StatsColors.orange,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      notice!,
                      style: const TextStyle(
                        color: _StatsColors.orange,
                        fontWeight: FontWeight.w700,
                      ),
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

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({
    required this.label,
    required this.value,
    this.rank,
    this.color = _StatsColors.tealDark,
  });

  final int? rank;
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        children: [
          Row(
            children: [
              if (rank != null) ...[
                CircleAvatar(
                  radius: 13,
                  backgroundColor: _StatsColors.tealDark,
                  child: Text(
                    '$rank',
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(label, style: const TextStyle(fontSize: 16)),
              ),
              Text(
                '$value%',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _Meter(value: value / 100, color: color),
        ],
      ),
    );
  }
}

class _MaintenanceCard extends StatelessWidget {
  const _MaintenanceCard({required this.progress});

  final int progress;

  @override
  Widget build(BuildContext context) {
    return _StatsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle(
            icon: Icons.build_outlined,
            iconColor: _StatsColors.orange,
            title: 'Cảnh báo bảo trì',
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFCED),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFFE6A3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(child: Text('Máy xông tinh dầu A')),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: _StatsColors.amber,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'Sắp bảo trì',
                        style: TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text('Đã sử dụng: $progress/100 giờ'),
                const SizedBox(height: 12),
                _Meter(value: progress / 100, color: _StatsColors.amber),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopStaffCard extends StatelessWidget {
  const _TopStaffCard({required this.staff});

  final List<StaffAvailability> staff;

  @override
  Widget build(BuildContext context) {
    final ranked = [...staff]..sort(
      (a, b) => b.bookingCount.compareTo(a.bookingCount),
    );
    final topStaff = ranked.where((item) => item.bookingCount > 0).take(3);
    final names = topStaff.map((item) => item.name).toList();
    final values = topStaff.map((item) => item.bookingCount).toList();

    return _StatsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle(
            icon: Icons.groups_outlined,
            title: 'Nhân viên nhiều ca nhất',
          ),
          const SizedBox(height: 18),
          if (names.isEmpty)
            Text(
              'Chưa có dữ liệu nhân viên.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: _StatsColors.muted),
            )
          else
            for (var i = 0; i < names.length; i++)
              _RankedStaffRow(
                rank: i + 1,
                name: names[i],
                value: values[i],
                max: values.first == 0 ? 1 : values.first,
              ),
        ],
      ),
    );
  }
}

class _RankedStaffRow extends StatelessWidget {
  const _RankedStaffRow({
    required this.rank,
    required this.name,
    required this.value,
    required this.max,
  });

  final int rank;
  final String name;
  final int value;
  final int max;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: rank == 3
                ? _StatsColors.tealSoft
                : _StatsColors.tealDark,
            child: Text('$rank', style: const TextStyle(color: Colors.white)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                    Text(
                      '$value ca',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _Meter(value: value / max),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReturnCustomerCard extends StatelessWidget {
  const _ReturnCustomerCard({
    required this.newCustomers,
    required this.returningRate,
  });

  final int newCustomers;
  final double returningRate;

  @override
  Widget build(BuildContext context) {
    return _StatsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle(icon: Icons.sync_alt, title: 'Tỷ lệ khách quay lại'),
          const SizedBox(height: 18),
          _ReturnStat(
            label: 'Khách hàng mới',
            value: '+$newCustomers%',
            bg: _StatsColors.greenWash,
            color: _StatsColors.green,
          ),
          const SizedBox(height: 14),
          _ReturnStat(
            label: 'Quay lại lần 2',
            value: '${(returningRate * 100).round()}%',
            bg: _StatsColors.tealWash,
          ),
          const SizedBox(height: 14),
          _ReturnStat(
            label: 'Quay lại từ 3 lần trở lên',
            value: '${(returningRate * 65).round()}%',
            bg: _StatsColors.tealWash,
          ),
        ],
      ),
    );
  }
}

class _ReturnStat extends StatelessWidget {
  const _ReturnStat({
    required this.label,
    required this.value,
    required this.bg,
    this.color = _StatsColors.tealDark,
  });

  final String label;
  final String value;
  final Color bg;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 22,
            ),
          ),
        ],
      ),
    );
  }
}

class _RatingCard extends StatelessWidget {
  const _RatingCard();

  @override
  Widget build(BuildContext context) {
    return _StatsCard(
      child: Row(
        children: const [
          Icon(Icons.star_border_rounded, color: _StatsColors.amber),
          SizedBox(width: 10),
          Expanded(child: Text('Đánh giá trung bình nhân viên')),
          Text('Chưa có', style: TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle({
    required this.icon,
    required this.title,
    this.iconColor = _StatsColors.tealDark,
  });

  final IconData icon;
  final String title;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 21, color: iconColor),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.color, required this.bg});

  final IconData icon;
  final Color color;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 21, color: color),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _StatsColors.border),
        boxShadow: _StatsShadow.soft,
      ),
      child: child,
    );
  }
}

class _Meter extends StatelessWidget {
  const _Meter({required this.value, this.color = _StatsColors.tealDark});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        minHeight: 8,
        value: value.clamp(0.0, 1.0),
        backgroundColor: _StatsColors.track,
        valueColor: AlwaysStoppedAnimation<Color>(color),
      ),
    );
  }
}

class _StatsColors {
  static const background = Color(0xFFF7F8FA);
  static const ink = Color(0xFF111827);
  static const muted = Color(0xFF7B8494);
  static const border = Color(0x14000000);
  static const track = Color(0xFFF0F2F5);
  static const softPanel = Color(0xFFF7F8FA);
  static const teal = Color(0xFF22AFC2);
  static const tealDark = Color(0xFF1593A3);
  static const tealSoft = Color(0xFF58D8E3);
  static const tealWash = Color(0xFFDDF7FB);
  static const green = Color(0xFF16A34A);
  static const greenWash = Color(0xFFE4F8EA);
  static const orange = Color(0xFFFF6B1A);
  static const orangeWash = Color(0xFFFFF1E7);
  static const amber = Color(0xFFFF9F0A);
  static const grayBlue = Color(0xFF94A3B8);
}

class _StatsShadow {
  static final soft = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  static final teal = [
    BoxShadow(
      color: _StatsColors.tealDark.withValues(alpha: 0.22),
      blurRadius: 8,
      offset: const Offset(0, 3),
    ),
  ];
}

String _formatCompactCurrency(int amount) {
  if (amount >= 1000000) {
    final value = amount / 1000000;
    return '${value.toStringAsFixed(value >= 10 ? 1 : 2)}M đ';
  }
  return '${(amount / 1000).round()}K đ';
}

String _formatShortCurrency(int amount) {
  if (amount >= 1000000) {
    return '${(amount / 1000000).toStringAsFixed(1)}M';
  }
  return '${(amount / 1000).round()}K';
}
