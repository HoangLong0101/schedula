import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'admin_shell.dart';
import 'admin_theme.dart';
import 'admin_dialog.dart';
import 'platform_dashboard.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({
    required this.future,
    required this.onRefresh,
    super.key,
  });

  final Future<PlatformDashboard> future;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      title: 'Tổng quan hệ thống',
      subtitle: 'Theo dõi hoạt động của các doanh nghiệp trên Schedula.',
      trailing: IconButton.filledTonal(
        tooltip: 'Làm mới dữ liệu',
        onPressed: onRefresh,
        icon: const Icon(Icons.refresh),
      ),
      child: FutureBuilder<PlatformDashboard>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const DashboardSkeleton();
          }
          if (snapshot.hasError) return ErrorState(onRetry: onRefresh);
          final dashboard = snapshot.data!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _MetricSummary(metrics: dashboard.metrics),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Doanh nghiệp mới',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  Text(
                    'Cập nhật ${DateFormat('HH:mm, dd/MM/yyyy').format(dashboard.generatedAt)}',
                    style: const TextStyle(
                      color: AdminTheme.mutedInk,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              BusinessTable(businesses: dashboard.recentBusinesses),
            ],
          );
        },
      ),
    );
  }
}

class BusinessesPage extends StatelessWidget {
  const BusinessesPage({
    required this.future,
    required this.onRefresh,
    super.key,
  });

  final Future<PlatformDashboard> future;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      title: 'Doanh nghiệp',
      subtitle: 'Danh sách doanh nghiệp đăng ký gần đây.',
      trailing: IconButton.filledTonal(
        onPressed: onRefresh,
        tooltip: 'Làm mới dữ liệu',
        icon: const Icon(Icons.refresh),
      ),
      child: FutureBuilder<PlatformDashboard>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const DashboardSkeleton(compact: true);
          }
          if (snapshot.hasError) return ErrorState(onRetry: onRefresh);
          return BusinessTable(businesses: snapshot.data!.recentBusinesses);
        },
      ),
    );
  }
}

class _MetricSummary extends StatelessWidget {
  const _MetricSummary({required this.metrics});

  final PlatformMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final secondary = [
      ('Người dùng', metrics.totalUsers, Icons.group_outlined),
      (
        'Lịch hẹn tháng này',
        metrics.bookingsThisMonth,
        Icons.calendar_today_outlined,
      ),
      ('Giao dịch', metrics.totalPayments, Icons.receipt_long_outlined),
      ('Sắp hết hạn', metrics.expiringSubscriptions, Icons.schedule_outlined),
    ];
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 680;
            final total = _PrimaryMetric(
              value: metrics.totalBusinesses,
              detail:
                  '${metrics.newBusinessesThisMonth} đăng ký mới trong tháng',
            );
            final status = _StatusSummary(metrics: metrics);
            if (!wide) {
              return Column(
                children: [total, const SizedBox(height: 12), status],
              );
            }
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 3, child: total),
                  const SizedBox(width: 16),
                  Expanded(flex: 2, child: status),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 900
                ? 4
                : constraints.maxWidth >= 500
                ? 2
                : 1;
            final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: secondary
                  .map(
                    (item) => SizedBox(
                      width: width,
                      child: _SmallMetric(
                        label: item.$1,
                        value: item.$2,
                        icon: item.$3,
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

class _PrimaryMetric extends StatelessWidget {
  const _PrimaryMetric({required this.value, required this.detail});

  final int value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AdminTheme.ink,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Tổng doanh nghiệp',
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '$value',
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
              color: Colors.white,
              fontSize: 42,
            ),
          ),
          const SizedBox(height: 8),
          Text(detail, style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }
}

class _StatusSummary extends StatelessWidget {
  const _StatusSummary({required this.metrics});

  final PlatformMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Trạng thái sử dụng',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 18),
            _StatusLine(
              label: 'Đang hoạt động',
              value: metrics.activeBusinesses,
              color: AdminTheme.tealDark,
            ),
            const SizedBox(height: 12),
            _StatusLine(
              label: 'Đang tạm ngưng',
              value: metrics.suspendedBusinesses,
              color: AdminTheme.danger,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: AdminTheme.mutedInk),
          ),
        ),
        Text('$value', style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}

class _SmallMetric extends StatelessWidget {
  const _SmallMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final int value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AdminTheme.teal.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AdminTheme.tealDark, size: 20),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$value', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AdminTheme.mutedInk,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BusinessTable extends StatelessWidget {
  const BusinessTable({required this.businesses, super.key});

  final List<PlatformBusiness> businesses;

  @override
  Widget build(BuildContext context) {
    if (businesses.isEmpty) {
      return const EmptyState(
        icon: Icons.domain_disabled_outlined,
        title: 'Chưa có doanh nghiệp',
        message: 'Doanh nghiệp mới sẽ xuất hiện tại đây.',
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 720) {
          return Column(
            children: businesses
                .map(
                  (business) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Card(
                      child: ListTile(
                        title: Text(
                          business.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          business.ownerEmail.isEmpty
                              ? business.id
                              : business.ownerEmail,
                        ),
                        trailing: StatusBadge(
                          active: business.status == 'active',
                        ),
                        onTap: () => _showBusiness(context, business),
                      ),
                    ),
                  ),
                )
                .toList(),
          );
        }
        return Card(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(
                    AdminTheme.background,
                  ),
                  horizontalMargin: 20,
                  columnSpacing: 28,
                  columns: const [
                    DataColumn(label: Text('Doanh nghiệp')),
                    DataColumn(label: Text('Chủ sở hữu')),
                    DataColumn(label: Text('Gói')),
                    DataColumn(label: Text('Trạng thái')),
                    DataColumn(label: Text('Ngày đăng ký')),
                  ],
                  rows: businesses
                      .map(
                        (business) => DataRow(
                          onSelectChanged: (_) {
                            _showBusiness(context, business);
                          },
                          cells: [
                            DataCell(
                              Text(
                                business.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                business.ownerEmail.isEmpty
                                    ? 'Chưa cập nhật'
                                    : business.ownerEmail,
                              ),
                            ),
                            DataCell(Text(business.planTier.toUpperCase())),
                            DataCell(
                              StatusBadge(active: business.status == 'active'),
                            ),
                            DataCell(Text(formatDate(business.createdAt))),
                          ],
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showBusiness(BuildContext context, PlatformBusiness business) {
    showAdminDialog<void>(
      context: context,
      builder: (_) => _BusinessDialog(business: business),
    );
  }
}

class _BusinessDialog extends StatelessWidget {
  const _BusinessDialog({required this.business});

  final PlatformBusiness business;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(business.name),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DetailRow(label: 'Mã doanh nghiệp', value: business.id),
            DetailRow(
              label: 'Chủ sở hữu',
              value: business.ownerName.isEmpty
                  ? 'Chưa cập nhật'
                  : business.ownerName,
            ),
            DetailRow(
              label: 'Email',
              value: business.ownerEmail.isEmpty
                  ? 'Chưa cập nhật'
                  : business.ownerEmail,
            ),
            DetailRow(
              label: 'Gói dịch vụ',
              value: business.planTier.toUpperCase(),
            ),
            DetailRow(
              label: 'Ngày đăng ký',
              value: formatDate(business.createdAt),
            ),
            DetailRow(
              label: 'Ngày hết hạn',
              value: formatDate(business.planExpiresAt),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Đóng'),
        ),
      ],
    );
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({required this.active, super.key});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? AdminTheme.tealDark : AdminTheme.danger;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          active ? 'Hoạt động' : 'Tạm ngưng',
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({this.compact = false, super.key});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (!compact) ...[
          const Row(
            children: [
              Expanded(flex: 3, child: _Skeleton(height: 168)),
              SizedBox(width: 16),
              Expanded(flex: 2, child: _Skeleton(height: 168)),
            ],
          ),
          const SizedBox(height: 24),
        ],
        const _Skeleton(height: 280),
      ],
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AdminTheme.skeleton,
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({required this.onRetry, super.key});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.cloud_off_outlined,
      title: 'Không tải được dữ liệu',
      message: 'Kiểm tra quyền quản trị và kết nối Firebase.',
      action: FilledButton.tonal(
        onPressed: onRetry,
        child: const Text('Thử lại'),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 54),
        child: Column(
          children: [
            Icon(icon, size: 34, color: AdminTheme.mutedInk),
            const SizedBox(height: 14),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AdminTheme.mutedInk),
            ),
            if (action != null) ...[const SizedBox(height: 18), action!],
          ],
        ),
      ),
    );
  }
}

String formatDate(DateTime? value) {
  return value == null
      ? 'Chưa cập nhật'
      : DateFormat('dd/MM/yyyy').format(value);
}
