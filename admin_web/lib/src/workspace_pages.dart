import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'admin_services.dart';
import 'admin_dialog.dart';
import 'admin_shell.dart';
import 'admin_theme.dart';
import 'csv_export.dart';
import 'firebase_options.dart';
import 'platform_workspace.dart';

final _money = NumberFormat.currency(
  locale: 'vi_VN',
  symbol: '₫',
  decimalDigits: 0,
);
final _date = DateFormat('dd/MM/yyyy');
final _dateTime = DateFormat('HH:mm dd/MM/yyyy');

class WorkspacePage extends StatelessWidget {
  const WorkspacePage({
    required this.section,
    required this.snapshot,
    required this.filter,
    required this.api,
    required this.auth,
    required this.user,
    required this.onFilterChanged,
    required this.onRefresh,
    required this.showMenu,
    super.key,
  });

  final AdminSection section;
  final AsyncSnapshot<PlatformWorkspace> snapshot;
  final WorkspaceFilter filter;
  final AdminApi api;
  final AdminAuthService auth;
  final User user;
  final ValueChanged<WorkspaceFilter> onFilterChanged;
  final VoidCallback onRefresh;
  final bool showMenu;

  @override
  Widget build(BuildContext context) {
    final title = _title(section);
    return SafeArea(
      child: Column(
        children: [
          Container(
            height: 72,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            decoration: const BoxDecoration(
              color: AdminTheme.surface,
              border: Border(
                bottom: BorderSide(color: AdminTheme.strongBorder),
              ),
            ),
            child: Row(
              children: [
                if (showMenu) ...[
                  Builder(
                    builder: (context) => IconButton(
                      tooltip: 'Mở điều hướng',
                      onPressed: Scaffold.of(context).openDrawer,
                      icon: const Icon(Icons.menu),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    title.$1,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              key: ValueKey(section),
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1440),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        title.$1,
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        title.$2,
                        style: const TextStyle(color: AdminTheme.mutedInk),
                      ),
                      const SizedBox(height: 20),
                      if (_usesFilters(section) && snapshot.data != null) ...[
                        GlobalFilterBar(
                          value: filter,
                          workspace: snapshot.data!,
                          onApply: onFilterChanged,
                        ),
                        const SizedBox(height: 20),
                      ],
                      _body(context),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (snapshot.connectionState != ConnectionState.done) {
      return const LoadingState();
    }
    if (snapshot.hasError || snapshot.data == null) {
      return ErrorState(error: snapshot.error, onRetry: onRefresh);
    }
    final data = snapshot.data!;
    return switch (section) {
      AdminSection.dashboard => DashboardWorkspace(data: data),
      AdminSection.businesses => BusinessesWorkspace(
        data: data,
        api: api,
        onChanged: onRefresh,
      ),
      AdminSection.transactions => TransactionsWorkspace(
        data: data,
        api: api,
        onChanged: onRefresh,
      ),
      AdminSection.subscriptions => SubscriptionsWorkspace(
        data: data,
        api: api,
        onChanged: onRefresh,
      ),
      AdminSection.revenue => RevenueWorkspace(data: data),
      AdminSection.provinces => ProvinceWorkspace(data: data),
      AdminSection.plans => PlansWorkspace(
        data: data,
        api: api,
        onChanged: onRefresh,
      ),
      AdminSection.monitoring => MonitoringWorkspace(data: data),
      AdminSection.reports => ReportsWorkspace(data: data, filter: filter),
      AdminSection.admins => AdminUsersWorkspace(
        data: data,
        api: api,
        onChanged: onRefresh,
      ),
      AdminSection.settings => SettingsWorkspace(
        data: data,
        user: user,
        auth: auth,
      ),
    };
  }
}

(String, String) _title(AdminSection section) => switch (section) {
  AdminSection.dashboard => (
    'Tổng quan hệ thống',
    'Theo dõi sức khỏe kinh doanh của Schedula.',
  ),
  AdminSection.businesses => (
    'Doanh nghiệp',
    'Tìm kiếm, kiểm tra và kiểm soát tài khoản doanh nghiệp.',
  ),
  AdminSection.transactions => (
    'Giao dịch',
    'Đối soát giao dịch PayOS và thanh toán SaaS.',
  ),
  AdminSection.subscriptions => (
    'Gói đăng ký',
    'Theo dõi vòng đời và xử lý gia hạn thủ công.',
  ),
  AdminSection.revenue => (
    'Phân tích doanh thu',
    'Doanh thu thật từ các bản ghi thanh toán đã xác nhận.',
  ),
  AdminSection.provinces => (
    'Phân tích tỉnh thành',
    'So sánh mức độ sử dụng và doanh thu theo địa phương.',
  ),
  AdminSection.plans => (
    'Gói và bảng giá SaaS',
    'Quản lý giá, thời gian dùng thử và tính năng.',
  ),
  AdminSection.monitoring => (
    'Vận hành hệ thống',
    'Theo dõi webhook PayOS và nhật ký quản trị.',
  ),
  AdminSection.reports => (
    'Báo cáo',
    'Xuất dữ liệu đang được lọc để kiểm tra và phân tích.',
  ),
  AdminSection.admins => (
    'Quản trị viên',
    'Phân quyền và vô hiệu hóa quyền truy cập nội bộ.',
  ),
  AdminSection.settings => (
    'Cài đặt',
    'Thông tin môi trường và tài khoản quản trị.',
  ),
};

bool _usesFilters(AdminSection section) => !{
  AdminSection.plans,
  AdminSection.monitoring,
  AdminSection.admins,
  AdminSection.settings,
}.contains(section);

class GlobalFilterBar extends StatefulWidget {
  const GlobalFilterBar({
    required this.value,
    required this.workspace,
    required this.onApply,
    super.key,
  });

  final WorkspaceFilter value;
  final PlatformWorkspace workspace;
  final ValueChanged<WorkspaceFilter> onApply;

  @override
  State<GlobalFilterBar> createState() => _GlobalFilterBarState();
}

class _GlobalFilterBarState extends State<GlobalFilterBar> {
  late final search = TextEditingController(text: widget.value.query);
  late WorkspaceFilter draft = widget.value;

  @override
  void didUpdateWidget(covariant GlobalFilterBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      draft = widget.value;
      if (search.text != draft.query) search.text = draft.query;
    }
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provinces = _options(
      widget.workspace.businesses.map((item) => item.province),
      draft.province,
    );
    final plans = _options(
      widget.workspace.plans.map((item) => item.id),
      draft.plan,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 250,
              child: TextField(
                controller: search,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search, size: 20),
                  hintText: 'Tìm doanh nghiệp, chủ sở hữu...',
                  isDense: true,
                ),
                onSubmitted: (_) => _apply(),
              ),
            ),
            _Select(
              width: 150,
              value: _rangeValue(draft),
              label: 'Thời gian',
              items: const {
                '7': '7 ngày',
                '30': '30 ngày',
                '90': 'Quý gần nhất',
                '365': '12 tháng',
                'all': 'Toàn bộ dữ liệu',
                'custom': 'Tùy chọn',
              },
              onChanged: (value) async {
                if (value == 'custom') {
                  final selected = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime.now().subtract(
                      const Duration(days: 366),
                    ),
                    lastDate: DateTime.now().add(const Duration(days: 1)),
                    initialDateRange: DateTimeRange(
                      start: draft.start,
                      end: draft.end,
                    ),
                  );
                  if (selected != null) {
                    setState(
                      () => draft = draft.copyWith(
                        start: selected.start,
                        end: selected.end.add(
                          const Duration(hours: 23, minutes: 59),
                        ),
                      ),
                    );
                  }
                } else if (value == 'all') {
                  final end = DateTime.now();
                  setState(
                    () =>
                        draft = draft.copyWith(start: DateTime(2020), end: end),
                  );
                } else {
                  final days = int.parse(value);
                  final end = DateTime.now();
                  setState(
                    () => draft = draft.copyWith(
                      start: end.subtract(Duration(days: days - 1)),
                      end: end,
                    ),
                  );
                }
              },
            ),
            _Select(
              width: 190,
              value: draft.province,
              label: 'Tỉnh thành',
              items: {
                '': 'Tất cả tỉnh thành',
                for (final item in provinces) item: item,
              },
              onChanged: (value) =>
                  setState(() => draft = draft.copyWith(province: value)),
            ),
            _Select(
              width: 160,
              value: draft.plan,
              label: 'Gói',
              items: {
                '': 'Tất cả gói',
                for (final item in plans) item: item.toUpperCase(),
              },
              onChanged: (value) =>
                  setState(() => draft = draft.copyWith(plan: value)),
            ),
            _Select(
              width: 175,
              value: draft.transactionStatus,
              label: 'Thanh toán',
              items: const {
                '': 'Mọi trạng thái',
                'paid': 'Đã thanh toán',
                'pending': 'Đang chờ',
                'failed': 'Thất bại',
                'cancelled': 'Đã hủy',
                'refunded': 'Hoàn tiền',
                'superseded': 'Đã thay thế',
              },
              onChanged: (value) => setState(
                () => draft = draft.copyWith(transactionStatus: value),
              ),
            ),
            FilledButton.icon(
              onPressed: _apply,
              icon: const Icon(Icons.filter_alt_outlined, size: 18),
              label: const Text('Áp dụng'),
            ),
          ],
        ),
      ),
    );
  }

  void _apply() => widget.onApply(draft.copyWith(query: search.text));
}

class _Select extends StatelessWidget {
  const _Select({
    required this.width,
    required this.value,
    required this.label,
    required this.items,
    required this.onChanged,
  });

  final double width;
  final String value;
  final String label;
  final Map<String, String> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: DropdownMenu<String>(
      expandedInsets: EdgeInsets.zero,
      initialSelection: items.containsKey(value) ? value : items.keys.first,
      label: Text(label),
      dropdownMenuEntries: items.entries
          .map((item) => DropdownMenuEntry(value: item.key, label: item.value))
          .toList(growable: false),
      onSelected: (value) {
        if (value != null) onChanged(value);
      },
    ),
  );
}

class DashboardWorkspace extends StatelessWidget {
  const DashboardWorkspace({required this.data, super.key});

  final PlatformWorkspace data;

  @override
  Widget build(BuildContext context) {
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    final recentlyActive = data.businesses
        .where(
          (business) =>
              business.lastActiveAt != null &&
              business.lastActiveAt!.isAfter(cutoff),
        )
        .length;
    final usageRate = data.businesses.isEmpty
        ? 0.0
        : recentlyActive / data.businesses.length * 100;
    final planUsage = <String, num>{};
    for (final business in data.businesses) {
      planUsage[business.planTier] = (planUsage[business.planTier] ?? 0) + 1;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (data.transactionsTruncated || data.businessesTruncated)
          const _LimitNotice(),
        _ExecutiveSummary(
          data: data,
          usageRate: usageRate,
          recentlyActive: recentlyActive,
        ),
        const SizedBox(height: 16),
        _RevenueStory(data: data),
        const SizedBox(height: 16),
        _BusinessStory(data: data, usageRate: usageRate, planUsage: planUsage),
        const SizedBox(height: 24),
        SectionHeader(
          title: 'Giao dịch gần đây',
          caption: '${data.transactions.length} giao dịch trong bộ lọc',
        ),
        const SizedBox(height: 10),
        TransactionTable(rows: data.transactions.take(10).toList()),
      ],
    );
  }
}

class _ExecutiveSummary extends StatelessWidget {
  const _ExecutiveSummary({
    required this.data,
    required this.usageRate,
    required this.recentlyActive,
  });

  final PlatformWorkspace data;
  final double usageRate;
  final int recentlyActive;

  @override
  Widget build(BuildContext context) {
    final metrics = data.metrics;
    final items = [
      (
        'Doanh thu',
        _money.format(metrics.totalRevenue),
        'Tổng giao dịch đăng ký đã thanh toán trong kỳ lọc.',
        Icons.payments_outlined,
        metrics.revenueChangePercent,
      ),
      (
        'Tỷ lệ giao dịch thành công',
        '${metrics.transactionSuccessRate.toStringAsFixed(1)}%',
        'Số giao dịch PayOS thành công trên tổng lượt thanh toán PayOS.',
        Icons.verified_outlined,
        null,
      ),
      (
        'Doanh nghiệp đang sử dụng',
        '${usageRate.toStringAsFixed(1)}%',
        '$recentlyActive/${data.businesses.length} doanh nghiệp có hoạt động trong 30 ngày gần nhất.',
        Icons.domain_verification_outlined,
        null,
      ),
      (
        'Gói trả phí hoạt động',
        '${metrics.activeSubscriptions}',
        'Doanh nghiệp có trạng thái đăng ký đang hoạt động.',
        Icons.autorenew,
        null,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1100
            ? 4
            : constraints.maxWidth >= 620
            ? 2
            : 1;
        final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: items
              .map(
                (item) => SizedBox(
                  width: width,
                  child: KpiCard(
                    label: item.$1,
                    value: item.$2,
                    icon: item.$4,
                    trend: item.$5,
                    tooltip: item.$3,
                  ),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _RevenueStory extends StatelessWidget {
  const _RevenueStory({required this.data});

  final PlatformWorkspace data;

  @override
  Widget build(BuildContext context) {
    final metrics = data.metrics;
    return _StoryPanel(
      title: 'Doanh thu và hiệu quả giao dịch',
      caption:
          'Theo dõi doanh thu cùng tỷ lệ thanh toán, giá trị khách hàng và mức sử dụng gói.',
      tooltip:
          'Các chỉ số trong khối này dùng chung kỳ thời gian và bộ lọc ở đầu trang.',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final chart = RevenueTrendChart(values: data.analytics.revenueByDay);
          final relationships = _RelationshipGrid(
            items: [
              (
                'MRR',
                _money.format(metrics.mrr),
                'Doanh thu định kỳ hàng tháng từ các gói đang hoạt động.',
                false,
              ),
              (
                'ARR',
                _money.format(metrics.arr),
                'Doanh thu định kỳ năm, được ước tính bằng MRR nhân 12.',
                false,
              ),
              (
                'ARPU',
                _money.format(metrics.arpu),
                'Doanh thu trung bình trên mỗi doanh nghiệp có gói hoạt động.',
                false,
              ),
              (
                'Thanh toán thất bại',
                '${metrics.failedPayments} · ${_money.format(metrics.failedPaymentAmount)}',
                'Số lượng và tổng giá trị giao dịch thất bại trong kỳ.',
                metrics.failedPayments > 0,
              ),
            ],
          );
          if (constraints.maxWidth < 900) {
            return Column(
              children: [chart, const SizedBox(height: 20), relationships],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: chart),
              const SizedBox(width: 24),
              Expanded(flex: 2, child: relationships),
            ],
          );
        },
      ),
    );
  }
}

class _BusinessStory extends StatelessWidget {
  const _BusinessStory({
    required this.data,
    required this.usageRate,
    required this.planUsage,
  });

  final PlatformWorkspace data;
  final double usageRate;
  final Map<String, num> planUsage;

  @override
  Widget build(BuildContext context) {
    final metrics = data.metrics;
    return _StoryPanel(
      title: 'Doanh nghiệp, mức sử dụng và khu vực',
      caption:
          'Đặt quy mô khách hàng cạnh mức hoạt động, gói đang dùng và phân bố địa lý.',
      tooltip:
          'Mức sử dụng hiện tại tính từ lastActiveAt trong 30 ngày gần nhất. Doanh nghiệp chưa có lastActiveAt không được tính là đang sử dụng.',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final geography = MetricBarChart(
            title: 'Doanh nghiệp theo tỉnh thành',
            values: data.analytics.businessesByProvince,
            embedded: true,
          );
          final overview = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _RelationshipGrid(
                items: [
                  (
                    'Mức sử dụng 30 ngày',
                    '${usageRate.toStringAsFixed(1)}%',
                    'Tỷ lệ doanh nghiệp có hoạt động trong 30 ngày gần nhất.',
                    usageRate < 50 && data.businesses.isNotEmpty,
                  ),
                  (
                    'Doanh nghiệp mới',
                    '${metrics.newBusinesses}',
                    'Doanh nghiệp được tạo trong kỳ thời gian đang lọc.',
                    false,
                  ),
                  (
                    'Đang dùng thử',
                    '${metrics.trialBusinesses}',
                    'Doanh nghiệp chưa chuyển sang gói trả phí.',
                    false,
                  ),
                  (
                    'Đã rời bỏ',
                    '${metrics.churnedBusinesses}',
                    'Doanh nghiệp có đăng ký đã hủy hoặc hết hạn.',
                    metrics.churnedBusinesses > 0,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SegmentedBreakdown(
                title: 'Tỷ lệ gói đang được sử dụng',
                values: planUsage,
                tooltip:
                    'Tỷ trọng doanh nghiệp theo gói hiện tại. Di chuột lên từng phần để xem chi tiết.',
              ),
            ],
          );
          if (constraints.maxWidth < 900) {
            return Column(
              children: [overview, const SizedBox(height: 20), geography],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 2, child: overview),
              const SizedBox(width: 24),
              Expanded(flex: 3, child: geography),
            ],
          );
        },
      ),
    );
  }
}

class BusinessesWorkspace extends StatelessWidget {
  const BusinessesWorkspace({
    required this.data,
    required this.api,
    required this.onChanged,
    super.key,
  });
  final PlatformWorkspace data;
  final AdminApi api;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SectionHeader(
        title: '${data.businesses.length} doanh nghiệp',
        caption: 'Chọn một dòng để mở hồ sơ và thao tác',
      ),
      const SizedBox(height: 10),
      if (data.businesses.isEmpty)
        const EmptyState(
          icon: Icons.domain_disabled_outlined,
          title: 'Không tìm thấy doanh nghiệp',
          message: 'Thử thay đổi bộ lọc hoặc từ khóa tìm kiếm.',
        )
      else
        BusinessTable(rows: data.businesses, api: api, onChanged: onChanged),
    ],
  );
}

class TransactionsWorkspace extends StatelessWidget {
  const TransactionsWorkspace({
    required this.data,
    required this.api,
    required this.onChanged,
    super.key,
  });
  final PlatformWorkspace data;
  final AdminApi api;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          SizedBox(
            width: 260,
            child: KpiCard(
              label: 'Giá trị giao dịch',
              value: _money.format(
                data.transactions.fold<int>(
                  0,
                  (sum, item) => sum + item.amount,
                ),
              ),
              icon: Icons.account_balance_wallet_outlined,
            ),
          ),
          SizedBox(
            width: 260,
            child: KpiCard(
              label: 'Cần đối soát',
              value:
                  '${data.transactions.where((item) => item.reconciliationStatus != 'verified' && item.provider == 'payos').length}',
              icon: Icons.sync_problem_outlined,
              warning: true,
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      TransactionTable(rows: data.transactions, api: api, onChanged: onChanged),
    ],
  );
}

class SubscriptionsWorkspace extends StatelessWidget {
  const SubscriptionsWorkspace({
    required this.data,
    required this.api,
    required this.onChanged,
    super.key,
  });
  final PlatformWorkspace data;
  final AdminApi api;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    if (data.businesses.isEmpty) {
      return const EmptyState(
        icon: Icons.autorenew,
        title: 'Không có gói đăng ký',
        message: 'Không có doanh nghiệp phù hợp với bộ lọc.',
      );
    }
    return _TableCard(
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Doanh nghiệp')),
          DataColumn(label: Text('Gói')),
          DataColumn(label: Text('Trạng thái')),
          DataColumn(label: Text('Ngày hết hạn')),
          DataColumn(label: Text('Thao tác')),
        ],
        rows: data.businesses
            .map(
              (business) => DataRow(
                cells: [
                  DataCell(
                    Text(
                      business.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  DataCell(Text(business.planTier.toUpperCase())),
                  DataCell(StatusBadge(status: business.subscriptionStatus)),
                  DataCell(Text(formatDate(business.planExpiresAt))),
                  DataCell(
                    PopupMenuButton<String>(
                      tooltip: 'Thao tác gói',
                      onSelected: (action) => _subscriptionAction(
                        context,
                        action,
                        business,
                        data.plans,
                        api,
                        onChanged,
                      ),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'change', child: Text('Đổi gói')),
                        PopupMenuItem(value: 'extend', child: Text('Gia hạn')),
                        PopupMenuItem(
                          value: 'reactivate',
                          child: Text('Kích hoạt lại'),
                        ),
                        PopupMenuItem(value: 'cancel', child: Text('Hủy gói')),
                      ],
                    ),
                  ),
                ],
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class RevenueWorkspace extends StatelessWidget {
  const RevenueWorkspace({required this.data, super.key});
  final PlatformWorkspace data;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          SizedBox(
            width: 270,
            child: KpiCard(
              label: 'Doanh thu',
              value: _money.format(data.metrics.totalRevenue),
              icon: Icons.payments_outlined,
              trend: data.metrics.revenueChangePercent,
            ),
          ),
          SizedBox(
            width: 270,
            child: KpiCard(
              label: 'MRR',
              value: _money.format(data.metrics.mrr),
              icon: Icons.calendar_month_outlined,
            ),
          ),
          SizedBox(
            width: 270,
            child: KpiCard(
              label: 'ARR',
              value: _money.format(data.metrics.arr),
              icon: Icons.trending_up,
            ),
          ),
          SizedBox(
            width: 270,
            child: KpiCard(
              label: 'Thanh toán lỗi',
              value: _money.format(data.metrics.failedPaymentAmount),
              icon: Icons.warning_amber,
              warning: data.metrics.failedPaymentAmount > 0,
            ),
          ),
        ],
      ),
      const SizedBox(height: 20),
      _ChartGrid(data: data),
    ],
  );
}

class ProvinceWorkspace extends StatelessWidget {
  const ProvinceWorkspace({required this.data, super.key});
  final PlatformWorkspace data;

  @override
  Widget build(BuildContext context) {
    final provinces =
        <String>{
              ...data.analytics.businessesByProvince.keys,
              ...data.analytics.revenueByProvince.keys,
            }
            .map(
              (name) => (
                name,
                data.analytics.businessesByProvince[name]?.toInt() ?? 0,
                data.analytics.revenueByProvince[name]?.toInt() ?? 0,
              ),
            )
            .toList()
          ..sort((a, b) => b.$3.compareTo(a.$3));
    if (provinces.isEmpty) {
      return const EmptyState(
        icon: Icons.map_outlined,
        title: 'Chưa có dữ liệu tỉnh thành',
        message:
            'Cập nhật trường tỉnh thành trong hồ sơ doanh nghiệp để bật phân tích địa lý.',
      );
    }
    return Column(
      children: [
        MetricBarChart(
          title: 'Doanh thu theo tỉnh',
          values: data.analytics.revenueByProvince,
          money: true,
          highlight: true,
        ),
        const SizedBox(height: 16),
        _TableCard(
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Xếp hạng')),
              DataColumn(label: Text('Tỉnh thành')),
              DataColumn(label: Text('Doanh nghiệp')),
              DataColumn(label: Text('Doanh thu')),
              DataColumn(label: Text('ARPU')),
            ],
            rows: [
              for (var i = 0; i < provinces.length; i++)
                DataRow(
                  cells: [
                    DataCell(Text('#${i + 1}')),
                    DataCell(
                      Text(
                        provinces[i].$1,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    DataCell(Text('${provinces[i].$2}')),
                    DataCell(Text(_money.format(provinces[i].$3))),
                    DataCell(
                      Text(
                        _money.format(
                          provinces[i].$2 == 0
                              ? 0
                              : provinces[i].$3 ~/ provinces[i].$2,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class PlansWorkspace extends StatelessWidget {
  const PlansWorkspace({
    required this.data,
    required this.api,
    required this.onChanged,
    super.key,
  });
  final PlatformWorkspace data;
  final AdminApi api;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final plans = [...data.plans]
      ..sort((a, b) => a.monthlyPrice.compareTo(b.monthlyPrice));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: () => showAdminDialog<void>(
              context: context,
              builder: (_) => PlanDialog(api: api, onChanged: onChanged),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Tạo gói'),
          ),
        ),
        const SizedBox(height: 14),
        if (plans.isEmpty)
          const EmptyState(
            icon: Icons.sell_outlined,
            title: 'Chưa có cấu hình gói',
            message: 'Tạo gói đầu tiên để quản lý giá mà không sửa mã nguồn.',
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth >= 900
                  ? (constraints.maxWidth - 24) / 3
                  : constraints.maxWidth >= 560
                  ? (constraints.maxWidth - 12) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: plans
                    .map(
                      (plan) => SizedBox(
                        width: width,
                        child: _PlanCard(
                          plan: plan,
                          api: api,
                          onChanged: onChanged,
                        ),
                      ),
                    )
                    .toList(growable: false),
              );
            },
          ),
      ],
    );
  }
}

class MonitoringWorkspace extends StatelessWidget {
  const MonitoringWorkspace({required this.data, super.key});
  final PlatformWorkspace data;

  @override
  Widget build(BuildContext context) {
    final failedWebhooks = data.webhookEvents
        .where((event) => event.status != 'verified')
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            const _HealthCard(
              label: 'Xác thực',
              detail: 'Firebase Authentication',
              ok: true,
            ),
            const _HealthCard(
              label: 'Cơ sở dữ liệu',
              detail: 'Callable API hoạt động',
              ok: true,
            ),
            _HealthCard(
              label: 'Thanh toán',
              detail: failedWebhooks == 0
                  ? 'Webhook gần đây hợp lệ'
                  : '$failedWebhooks sự kiện cần kiểm tra',
              ok: failedWebhooks == 0,
            ),
            const _HealthCard(
              label: 'Cloud Monitoring',
              detail: 'Chưa kết nối Google Cloud Logging',
              ok: null,
            ),
          ],
        ),
        const SizedBox(height: 20),
        SectionHeader(
          title: 'Webhook PayOS',
          caption: 'Lịch sử xác minh từ backend',
        ),
        const SizedBox(height: 10),
        EventTable(events: data.webhookEvents, webhook: true),
        const SizedBox(height: 20),
        SectionHeader(
          title: 'Nhật ký kiểm toán',
          caption: 'Các thao tác quản trị nhạy cảm, chỉ đọc',
        ),
        const SizedBox(height: 10),
        EventTable(events: data.auditEvents),
      ],
    );
  }
}

class ReportsWorkspace extends StatelessWidget {
  const ReportsWorkspace({required this.data, required this.filter, super.key});
  final PlatformWorkspace data;
  final WorkspaceFilter filter;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'CSV giữ nguyên bộ lọc hiện tại. Excel và PDF được hoãn vì dự án chưa có thư viện xuất an toàn.',
        style: TextStyle(color: AdminTheme.mutedInk),
      ),
      const SizedBox(height: 16),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _ExportCard(
            title: 'Báo cáo giao dịch',
            count: data.transactions.length,
            icon: Icons.receipt_long_outlined,
            onExport: () => _exportTransactions(data.transactions),
          ),
          _ExportCard(
            title: 'Báo cáo doanh nghiệp',
            count: data.businesses.length,
            icon: Icons.domain_outlined,
            onExport: () => _exportBusinesses(data.businesses),
          ),
          _ExportCard(
            title: 'Báo cáo tỉnh thành',
            count: data.analytics.revenueByProvince.length,
            icon: Icons.map_outlined,
            onExport: () => _exportProvinces(data.analytics),
          ),
          _ExportCard(
            title: 'Nhật ký kiểm toán',
            count: data.auditEvents.length,
            icon: Icons.policy_outlined,
            onExport: () => _exportEvents(data.auditEvents),
          ),
        ],
      ),
    ],
  );
}

class AdminUsersWorkspace extends StatelessWidget {
  const AdminUsersWorkspace({
    required this.data,
    required this.api,
    required this.onChanged,
    super.key,
  });
  final PlatformWorkspace data;
  final AdminApi api;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: () => showAdminDialog<void>(
              context: context,
              builder: (_) => AddAdminDialog(api: api, onChanged: onChanged),
            ),
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('Thêm quản trị viên'),
          ),
        ),
        const SizedBox(height: 14),
        if (data.admins.isEmpty)
          const EmptyState(
            icon: Icons.admin_panel_settings_outlined,
            title: 'Không có dữ liệu quản trị viên',
            message:
                'Nhập Firebase UID của một tài khoản đã tồn tại để cấp quyền.',
          )
        else
          _TableCard(
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Quản trị viên')),
                DataColumn(label: Text('Vai trò')),
                DataColumn(label: Text('Trạng thái')),
                DataColumn(label: Text('Thao tác')),
              ],
              rows: data.admins
                  .map(
                    (admin) => DataRow(
                      cells: [
                        DataCell(
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                admin.name.isEmpty ? admin.email : admin.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                admin.email,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AdminTheme.mutedInk,
                                ),
                              ),
                            ],
                          ),
                        ),
                        DataCell(Text(roleLabel(admin.role))),
                        DataCell(
                          StatusBadge(
                            status: admin.active ? 'active' : 'inactive',
                          ),
                        ),
                        DataCell(
                          IconButton(
                            tooltip: 'Sửa quyền',
                            icon: const Icon(Icons.manage_accounts_outlined),
                            onPressed: () => showAdminDialog<void>(
                              context: context,
                              builder: (_) => AdminRoleDialog(
                                admin: admin,
                                api: api,
                                onChanged: onChanged,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
      ],
    );
  }
}

class SettingsWorkspace extends StatelessWidget {
  const SettingsWorkspace({
    required this.data,
    required this.user,
    required this.auth,
    super.key,
  });
  final PlatformWorkspace data;
  final User user;
  final AdminAuthService auth;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 760),
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Môi trường', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            DetailRow(
              label: 'Firebase project',
              value: DefaultFirebaseOptions.projectId,
            ),
            const DetailRow(
              label: 'Dữ liệu',
              value: 'Callable Cloud Functions',
            ),
            const DetailRow(label: 'Thanh toán', value: 'PayOS server-side'),
            const Divider(height: 32),
            Text('Tài khoản', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            DetailRow(label: 'Email', value: user.email ?? 'Chưa cập nhật'),
            DetailRow(label: 'Firebase UID', value: user.uid),
            DetailRow(label: 'Vai trò', value: roleLabel(data.actor.role)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: user.email == null
                      ? null
                      : () async {
                          await auth.sendPasswordReset(user.email!);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Đã gửi email đặt lại mật khẩu.'),
                              ),
                            );
                          }
                        },
                  icon: const Icon(Icons.lock_reset),
                  label: const Text('Đặt lại mật khẩu'),
                ),
                FilledButton.tonalIcon(
                  onPressed: auth.signOut,
                  icon: const Icon(Icons.logout),
                  label: const Text('Đăng xuất'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class BusinessTable extends StatefulWidget {
  const BusinessTable({
    required this.rows,
    required this.api,
    required this.onChanged,
    super.key,
  });
  final List<PlatformBusinessRecord> rows;
  final AdminApi api;
  final VoidCallback onChanged;

  @override
  State<BusinessTable> createState() => _BusinessTableState();
}

class _BusinessTableState extends State<BusinessTable> {
  int page = 0;
  static const pageSize = 15;

  @override
  void didUpdateWidget(covariant BusinessTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (page * pageSize >= widget.rows.length) page = 0;
  }

  @override
  Widget build(BuildContext context) {
    final rows = widget.rows.skip(page * pageSize).take(pageSize).toList();
    return Column(
      children: [
        _TableCard(
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Doanh nghiệp')),
              DataColumn(label: Text('Chủ sở hữu')),
              DataColumn(label: Text('Loại / tỉnh')),
              DataColumn(label: Text('Gói')),
              DataColumn(label: Text('Đăng ký')),
              DataColumn(label: Text('Tài khoản')),
            ],
            rows: rows
                .map(
                  (business) => DataRow(
                    onSelectChanged: (_) => showAdminDialog<void>(
                      context: context,
                      builder: (_) => BusinessDetailDialog(
                        business: business,
                        api: widget.api,
                        onChanged: widget.onChanged,
                      ),
                    ),
                    cells: [
                      DataCell(
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              business.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              business.id,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AdminTheme.mutedInk,
                              ),
                            ),
                          ],
                        ),
                      ),
                      DataCell(
                        Text(
                          business.ownerEmail.isEmpty
                              ? 'Chưa cập nhật'
                              : business.ownerEmail,
                        ),
                      ),
                      DataCell(
                        Text(
                          [business.businessType, business.province]
                              .where((item) => item.isNotEmpty)
                              .join(' · ')
                              .ifEmpty('Chưa cập nhật'),
                        ),
                      ),
                      DataCell(Text(business.planTier.toUpperCase())),
                      DataCell(
                        StatusBadge(status: business.subscriptionStatus),
                      ),
                      DataCell(StatusBadge(status: business.status)),
                    ],
                  ),
                )
                .toList(growable: false),
          ),
        ),
        _Pagination(
          page: page,
          pageSize: pageSize,
          total: widget.rows.length,
          onChanged: (value) => setState(() => page = value),
        ),
      ],
    );
  }
}

class TransactionTable extends StatefulWidget {
  const TransactionTable({
    required this.rows,
    this.api,
    this.onChanged,
    super.key,
  });
  final List<PlatformTransaction> rows;
  final AdminApi? api;
  final VoidCallback? onChanged;

  @override
  State<TransactionTable> createState() => _TransactionTableState();
}

class _TransactionTableState extends State<TransactionTable> {
  int page = 0;
  static const pageSize = 20;

  @override
  void didUpdateWidget(covariant TransactionTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (page * pageSize >= widget.rows.length) page = 0;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.rows.isEmpty) {
      return const EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'Không có giao dịch',
        message: 'Không có giao dịch trong bộ lọc hiện tại.',
      );
    }
    final rows = widget.rows.skip(page * pageSize).take(pageSize).toList();
    return Column(
      children: [
        _TableCard(
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Mã / PayOS')),
              DataColumn(label: Text('Doanh nghiệp')),
              DataColumn(label: Text('Gói')),
              DataColumn(label: Text('Số tiền'), numeric: true),
              DataColumn(label: Text('Nhà cung cấp')),
              DataColumn(label: Text('Ngày')),
              DataColumn(label: Text('Trạng thái')),
            ],
            rows: rows
                .map(
                  (transaction) => DataRow(
                    onSelectChanged: widget.api == null
                        ? null
                        : (_) => showAdminDialog<void>(
                            context: context,
                            builder: (_) => TransactionDialog(
                              transaction: transaction,
                              api: widget.api!,
                              onChanged: widget.onChanged!,
                            ),
                          ),
                    cells: [
                      DataCell(
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              transaction.id,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              transaction.orderCode.isEmpty
                                  ? 'Không có orderCode'
                                  : transaction.orderCode,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AdminTheme.mutedInk,
                              ),
                            ),
                          ],
                        ),
                      ),
                      DataCell(
                        Text(
                          transaction.businessName.isEmpty
                              ? transaction.tenantId
                              : transaction.businessName,
                        ),
                      ),
                      DataCell(Text(transaction.planTier.toUpperCase())),
                      DataCell(Text(_money.format(transaction.amount))),
                      DataCell(Text(transaction.provider.toUpperCase())),
                      DataCell(Text(formatDate(transaction.createdAt))),
                      DataCell(StatusBadge(status: transaction.status)),
                    ],
                  ),
                )
                .toList(growable: false),
          ),
        ),
        if (widget.rows.length > pageSize)
          _Pagination(
            page: page,
            pageSize: pageSize,
            total: widget.rows.length,
            onChanged: (value) => setState(() => page = value),
          ),
      ],
    );
  }
}

class BusinessDetailDialog extends StatelessWidget {
  const BusinessDetailDialog({
    required this.business,
    required this.api,
    required this.onChanged,
    super.key,
  });
  final PlatformBusinessRecord business;
  final AdminApi api;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(business.name),
    content: SizedBox(
      width: 760,
      child: FutureBuilder<Map<Object?, Object?>>(
        future: api.getBusinessDetail(business.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const SizedBox(
              height: 260,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return ErrorState(
              error: snapshot.error,
              onRetry: () => Navigator.pop(context),
            );
          }
          final data = snapshot.data!;
          final usage = Map<Object?, Object?>.from(
            data['usage'] as Map? ?? const {},
          );
          final payments = (data['payments'] as List? ?? const [])
              .whereType<Map>()
              .map((item) => Map<Object?, Object?>.from(item))
              .take(5)
              .toList();
          final activity = (data['activity'] as List? ?? const [])
              .whereType<Map>()
              .map((item) => Map<Object?, Object?>.from(item))
              .take(5)
              .toList();
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 20,
                  runSpacing: 4,
                  children: [
                    SizedBox(
                      width: 340,
                      child: Column(
                        children: [
                          DetailRow(label: 'Tenant ID', value: business.id),
                          DetailRow(
                            label: 'Chủ sở hữu',
                            value: business.ownerName.ifEmpty('Chưa cập nhật'),
                          ),
                          DetailRow(
                            label: 'Email',
                            value: business.ownerEmail.ifEmpty('Chưa cập nhật'),
                          ),
                          DetailRow(
                            label: 'Điện thoại',
                            value: business.phone.ifEmpty('Chưa cập nhật'),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 340,
                      child: Column(
                        children: [
                          DetailRow(
                            label: 'Địa chỉ',
                            value: business.address.ifEmpty('Chưa cập nhật'),
                          ),
                          DetailRow(
                            label: 'Tỉnh thành',
                            value: business.province.ifEmpty('Chưa cập nhật'),
                          ),
                          DetailRow(
                            label: 'Gói hiện tại',
                            value: business.planTier.toUpperCase(),
                          ),
                          DetailRow(
                            label: 'Hết hạn',
                            value: formatDate(business.planExpiresAt),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 28),
                Text(
                  'Mức sử dụng',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: usage.entries
                      .map(
                        (item) => Chip(
                          label: Text(
                            '${usageLabel(item.key.toString())}: ${item.value}',
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 12),
                DetailRow(
                  label: 'Doanh thu trọn đời',
                  value: data['lifetimeRevenueAvailable'] == false
                      ? 'Đang chuẩn bị chỉ mục dữ liệu'
                      : _money.format(data['lifetimeRevenue'] ?? 0),
                ),
                const Divider(height: 28),
                Text(
                  'Thanh toán gần đây',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (payments.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Chưa có thanh toán SaaS.',
                      style: TextStyle(color: AdminTheme.mutedInk),
                    ),
                  )
                else
                  for (final payment in payments)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(
                        _money.format(payment['amount'] ?? 0),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text('PayOS ${payment['orderCode'] ?? ''}'),
                      trailing: StatusBadge(
                        status: payment['status']?.toString() ?? 'pending',
                      ),
                    ),
                const Divider(height: 28),
                Text(
                  'Hoạt động gần đây',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (activity.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Chưa có hoạt động được ghi nhận.',
                      style: TextStyle(color: AdminTheme.mutedInk),
                    ),
                  )
                else
                  for (final event in activity)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: const Icon(Icons.history, size: 18),
                      title: Text(event['action']?.toString() ?? 'Hoạt động'),
                      subtitle: Text(
                        event['actorId']?.toString() ?? 'Hệ thống',
                      ),
                    ),
              ],
            ),
          );
        },
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Đóng'),
      ),
      if (business.status == 'suspended')
        FilledButton.tonal(
          onPressed: () => _confirmedAction(
            context,
            api,
            'business.reactivate',
            business.id,
            'Kích hoạt lại doanh nghiệp?',
            onChanged,
          ),
          child: const Text('Kích hoạt lại'),
        )
      else
        FilledButton.tonal(
          onPressed: () => _confirmedAction(
            context,
            api,
            'business.suspend',
            business.id,
            'Tạm ngưng doanh nghiệp?',
            onChanged,
          ),
          child: const Text('Tạm ngưng'),
        ),
    ],
  );
}

class TransactionDialog extends StatefulWidget {
  const TransactionDialog({
    required this.transaction,
    required this.api,
    required this.onChanged,
    super.key,
  });
  final PlatformTransaction transaction;
  final AdminApi api;
  final VoidCallback onChanged;

  @override
  State<TransactionDialog> createState() => _TransactionDialogState();
}

class _TransactionDialogState extends State<TransactionDialog> {
  bool loading = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.transaction;
    return AlertDialog(
      title: const Text('Chi tiết giao dịch'),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DetailRow(label: 'Transaction ID', value: item.id),
            DetailRow(
              label: 'PayOS orderCode',
              value: item.orderCode.ifEmpty('Không có'),
            ),
            DetailRow(
              label: 'Doanh nghiệp',
              value: item.businessName.ifEmpty(item.tenantId),
            ),
            DetailRow(
              label: 'Gói / kỳ hạn',
              value: '${item.planTier.toUpperCase()} ${item.billingPeriod}',
            ),
            DetailRow(label: 'Số tiền', value: _money.format(item.amount)),
            DetailRow(label: 'Trạng thái', value: statusLabel(item.status)),
            DetailRow(
              label: 'PayOS status',
              value: item.providerStatus.ifEmpty('Chưa kiểm tra'),
            ),
            DetailRow(
              label: 'Đối soát',
              value: reconciliationLabel(item.reconciliationStatus),
            ),
            DetailRow(label: 'Tạo lúc', value: formatDateTime(item.createdAt)),
            DetailRow(
              label: 'Hoàn thành',
              value: formatDateTime(item.completedAt),
            ),
            if (item.internalNote.isNotEmpty)
              DetailRow(label: 'Ghi chú', value: item.internalNote),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: loading ? null : () => Navigator.pop(context),
          child: const Text('Đóng'),
        ),
        if (item.provider == 'payos')
          FilledButton.icon(
            onPressed: loading ? null : _reconcile,
            icon: const Icon(Icons.sync),
            label: Text(loading ? 'Đang kiểm tra...' : 'Kiểm tra PayOS'),
          ),
      ],
    );
  }

  Future<void> _reconcile() async {
    setState(() => loading = true);
    try {
      await widget.api.reconcileTransaction(widget.transaction.id);
      widget.onChanged();
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) _showError(context, error);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }
}

class PlanDialog extends StatefulWidget {
  const PlanDialog({
    this.plan,
    required this.api,
    required this.onChanged,
    super.key,
  });
  final PlatformPlan? plan;
  final AdminApi api;
  final VoidCallback onChanged;

  @override
  State<PlanDialog> createState() => _PlanDialogState();
}

class _PlanDialogState extends State<PlanDialog> {
  late final id = TextEditingController(text: widget.plan?.id ?? '');
  late final name = TextEditingController(text: widget.plan?.name ?? '');
  late final monthly = TextEditingController(
    text: '${widget.plan?.monthlyPrice ?? 0}',
  );
  late final annual = TextEditingController(
    text: '${widget.plan?.annualPrice ?? 0}',
  );
  late final trial = TextEditingController(
    text: '${widget.plan?.trialDays ?? 0}',
  );
  late final description = TextEditingController(
    text: widget.plan?.description ?? '',
  );
  late final features = TextEditingController(
    text: widget.plan?.features.join(', ') ?? '',
  );
  final form = GlobalKey<FormState>();
  bool loading = false;

  @override
  void dispose() {
    for (final controller in [
      id,
      name,
      monthly,
      annual,
      trial,
      description,
      features,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.plan == null ? 'Tạo gói SaaS' : 'Sửa gói SaaS'),
    content: SizedBox(
      width: 560,
      child: Form(
        key: form,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextFormField(
                controller: id,
                enabled: widget.plan == null,
                decoration: const InputDecoration(labelText: 'Mã gói'),
                validator: _planId,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Tên gói'),
                validator: _required,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: monthly,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Giá tháng (VND)',
                      ),
                      validator: (value) =>
                          _integerRange(value, label: 'Giá tháng', min: 0),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: annual,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Giá năm (VND)',
                      ),
                      validator: (value) =>
                          _integerRange(value, label: 'Giá năm', min: 0),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: trial,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Số ngày dùng thử',
                ),
                validator: (value) => _integerRange(
                  value,
                  label: 'Số ngày dùng thử',
                  min: 0,
                  max: 365,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: description,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Mô tả'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: features,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Tính năng, cách nhau bằng dấu phẩy',
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: loading ? null : () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      FilledButton(
        onPressed: loading ? null : _save,
        child: Text(loading ? 'Đang lưu...' : 'Lưu'),
      ),
    ],
  );

  Future<void> _save() async {
    if (!form.currentState!.validate()) return;
    setState(() => loading = true);
    try {
      await widget.api.performAction(
        action: 'plan.save',
        resourceId: id.text.trim().toLowerCase(),
        payload: {
          'name': name.text.trim(),
          'monthlyPrice': int.parse(monthly.text),
          'annualPrice': int.parse(annual.text),
          'trialDays': int.parse(trial.text),
          'description': description.text.trim(),
          'features': features.text
              .split(',')
              .map((item) => item.trim())
              .where((item) => item.isNotEmpty)
              .toList(),
          'status': widget.plan?.status ?? 'active',
        },
      );
      widget.onChanged();
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) _showError(context, error);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }
}

class AdminRoleDialog extends StatefulWidget {
  const AdminRoleDialog({
    required this.admin,
    required this.api,
    required this.onChanged,
    super.key,
  });
  final PlatformAdminRecord admin;
  final AdminApi api;
  final VoidCallback onChanged;
  @override
  State<AdminRoleDialog> createState() => _AdminRoleDialogState();
}

class _AdminRoleDialogState extends State<AdminRoleDialog> {
  late String role = widget.admin.role;
  late bool active = widget.admin.active;
  bool loading = false;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.admin.email),
    content: SizedBox(
      width: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: role,
            decoration: const InputDecoration(labelText: 'Vai trò'),
            items:
                const {
                      'super_admin': 'Quản trị cấp cao',
                      'finance_admin': 'Tài chính',
                      'support_admin': 'Hỗ trợ',
                      'sales_admin': 'Kinh doanh',
                      'analyst': 'Phân tích',
                    }.entries
                    .map(
                      (item) => DropdownMenuItem(
                        value: item.key,
                        child: Text(item.value),
                      ),
                    )
                    .toList(),
            onChanged: (value) => setState(() => role = value!),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Cho phép truy cập'),
            value: active,
            onChanged: (value) => setState(() => active = value),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: loading ? null : () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      FilledButton(
        onPressed: loading ? null : _save,
        child: Text(loading ? 'Đang lưu...' : 'Xác nhận'),
      ),
    ],
  );

  Future<void> _save() async {
    setState(() => loading = true);
    try {
      await widget.api.performAction(
        action: 'admin.update',
        resourceId: widget.admin.id,
        payload: {'role': role, 'active': active},
      );
      widget.onChanged();
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) _showError(context, error);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }
}

class AddAdminDialog extends StatefulWidget {
  const AddAdminDialog({required this.api, required this.onChanged, super.key});

  final AdminApi api;
  final VoidCallback onChanged;

  @override
  State<AddAdminDialog> createState() => _AddAdminDialogState();
}

class _AddAdminDialogState extends State<AddAdminDialog> {
  final uid = TextEditingController();
  final form = GlobalKey<FormState>();
  String role = 'analyst';
  bool loading = false;

  @override
  void dispose() {
    uid.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Thêm quản trị viên'),
    content: SizedBox(
      width: 440,
      child: Form(
        key: form,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: uid,
              decoration: const InputDecoration(
                labelText: 'Firebase Auth UID',
                helperText:
                    'Tài khoản phải tồn tại trong Firebase Authentication.',
              ),
              validator: _firebaseUid,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: role,
              decoration: const InputDecoration(labelText: 'Vai trò'),
              items:
                  const {
                        'super_admin': 'Quản trị cấp cao',
                        'finance_admin': 'Tài chính',
                        'support_admin': 'Hỗ trợ',
                        'sales_admin': 'Kinh doanh',
                        'analyst': 'Phân tích',
                      }.entries
                      .map(
                        (item) => DropdownMenuItem(
                          value: item.key,
                          child: Text(item.value),
                        ),
                      )
                      .toList(),
              onChanged: (value) => setState(() => role = value!),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: loading ? null : () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      FilledButton(
        onPressed: loading ? null : _save,
        child: Text(loading ? 'Đang cấp quyền...' : 'Cấp quyền'),
      ),
    ],
  );

  Future<void> _save() async {
    if (!form.currentState!.validate()) return;
    setState(() => loading = true);
    try {
      await widget.api.performAction(
        action: 'admin.create',
        resourceId: uid.text.trim(),
        payload: {'role': role},
      );
      widget.onChanged();
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) _showError(context, error);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }
}

class _StoryPanel extends StatelessWidget {
  const _StoryPanel({
    required this.title,
    required this.caption,
    required this.tooltip,
    required this.child,
  });

  final String title;
  final String caption;
  final String tooltip;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _InfoTitle(title: title, tooltip: tooltip),
          const SizedBox(height: 5),
          Text(
            caption,
            style: const TextStyle(color: AdminTheme.mutedInk, fontSize: 12),
          ),
          const SizedBox(height: 24),
          child,
        ],
      ),
    ),
  );
}

class _InfoTitle extends StatelessWidget {
  const _InfoTitle({required this.title, required this.tooltip});

  final String title;
  final String tooltip;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Flexible(
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      ),
      const SizedBox(width: 6),
      Tooltip(
        message: tooltip,
        waitDuration: const Duration(milliseconds: 250),
        child: const Icon(
          Icons.info_outline,
          size: 16,
          color: AdminTheme.mutedInk,
        ),
      ),
    ],
  );
}

class _RelationshipGrid extends StatelessWidget {
  const _RelationshipGrid({required this.items});

  final List<(String, String, String, bool)> items;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 420 ? 2 : 1;
      final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: items
            .map(
              (item) => SizedBox(
                width: width,
                child: _RelationshipMetric(
                  label: item.$1,
                  value: item.$2,
                  tooltip: item.$3,
                  warning: item.$4,
                ),
              ),
            )
            .toList(growable: false),
      );
    },
  );
}

class _RelationshipMetric extends StatelessWidget {
  const _RelationshipMetric({
    required this.label,
    required this.value,
    required this.tooltip,
    required this.warning,
  });

  final String label;
  final String value;
  final String tooltip;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final color = warning ? AdminTheme.orange : AdminTheme.tealDark;
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 250),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.055),
          border: Border.all(color: color.withValues(alpha: 0.14)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AdminTheme.mutedInk,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  Icon(Icons.info_outline, size: 13, color: color),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: warning ? AdminTheme.orange : null,
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

class RevenueTrendChart extends StatelessWidget {
  const RevenueTrendChart({required this.values, super.key});

  final Map<String, num> values;

  @override
  Widget build(BuildContext context) {
    final entries = values.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final visible = entries.length > 30
        ? entries.sublist(entries.length - 30)
        : entries;
    final max = visible.fold<double>(
      0,
      (current, entry) =>
          entry.value > current ? entry.value.toDouble() : current,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _InfoTitle(
          title: 'Xu hướng doanh thu theo ngày',
          tooltip: 'Di chuột lên từng cột để xem ngày và doanh thu chính xác.',
        ),
        const SizedBox(height: 18),
        if (visible.isEmpty || max <= 0)
          const SizedBox(
            height: 190,
            child: Center(
              child: Text(
                'Chưa có doanh thu trong kỳ',
                style: TextStyle(color: AdminTheme.mutedInk),
              ),
            ),
          )
        else
          Container(
            height: 190,
            padding: const EdgeInsets.fromLTRB(10, 14, 10, 8),
            decoration: BoxDecoration(
              color: AdminTheme.teal.withValues(alpha: 0.035),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: visible
                  .map(
                    (entry) => Expanded(
                      child: Tooltip(
                        message: '${entry.key}\n${_money.format(entry.value)}',
                        waitDuration: const Duration(milliseconds: 150),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: FractionallySizedBox(
                              heightFactor: (entry.value / max)
                                  .clamp(0.02, 1)
                                  .toDouble(),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: AdminTheme.teal,
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(5),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
        if (visible.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(visible.first.key, style: const TextStyle(fontSize: 10)),
              Text(visible.last.key, style: const TextStyle(fontSize: 10)),
            ],
          ),
        ],
      ],
    );
  }
}

class SegmentedBreakdown extends StatelessWidget {
  const SegmentedBreakdown({
    required this.title,
    required this.values,
    required this.tooltip,
    super.key,
  });

  final String title;
  final Map<String, num> values;
  final String tooltip;

  static const colors = [
    AdminTheme.tealDark,
    AdminTheme.teal,
    Color(0xFF78CDD7),
    AdminTheme.orange,
  ];

  @override
  Widget build(BuildContext context) {
    final entries = values.entries.where((entry) => entry.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<num>(0, (sum, entry) => sum + entry.value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _InfoTitle(title: title, tooltip: tooltip),
        const SizedBox(height: 14),
        if (entries.isEmpty)
          const Text(
            'Chưa có dữ liệu gói',
            style: TextStyle(color: AdminTheme.mutedInk, fontSize: 12),
          )
        else ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: SizedBox(
              height: 14,
              child: Row(
                children: [
                  for (var index = 0; index < entries.length; index++)
                    Expanded(
                      flex: entries[index].value
                          .round()
                          .clamp(1, 1000000)
                          .toInt(),
                      child: Tooltip(
                        message:
                            '${entries[index].key}: ${entries[index].value} (${(entries[index].value / total * 100).toStringAsFixed(1)}%)',
                        child: ColoredBox(color: colors[index % colors.length]),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              for (var index = 0; index < entries.length; index++)
                Tooltip(
                  message:
                      '${(entries[index].value / total * 100).toStringAsFixed(1)}% doanh nghiệp',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: colors[index % colors.length],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${entries[index].key} (${entries[index].value})',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class KpiCard extends StatelessWidget {
  const KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    this.trend,
    this.warning = false,
    this.tooltip,
    super.key,
  });
  final String label;
  final String value;
  final IconData icon;
  final double? trend;
  final bool warning;
  final String? tooltip;
  @override
  Widget build(BuildContext context) {
    final color = warning ? AdminTheme.orange : AdminTheme.tealDark;
    return Card(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 154),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const Spacer(),
                  if (trend != null) TrendBadge(value: trend!),
                  if (tooltip != null) ...[
                    if (trend != null) const SizedBox(width: 8),
                    Tooltip(
                      message: tooltip!,
                      waitDuration: const Duration(milliseconds: 250),
                      child: const Icon(
                        Icons.info_outline,
                        size: 16,
                        color: AdminTheme.mutedInk,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  color: AdminTheme.mutedInk,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TrendBadge extends StatelessWidget {
  const TrendBadge({required this.value, super.key});
  final double value;
  @override
  Widget build(BuildContext context) {
    final positive = value >= 0;
    final color = positive ? AdminTheme.success : AdminTheme.danger;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          '${positive ? '+' : ''}${value.toStringAsFixed(1)}%',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}

class MetricBarChart extends StatelessWidget {
  const MetricBarChart({
    required this.title,
    required this.values,
    this.money = false,
    this.highlight = false,
    this.embedded = false,
    super.key,
  });
  final String title;
  final Map<String, num> values;
  final bool money;
  final bool highlight;
  final bool embedded;
  @override
  Widget build(BuildContext context) {
    final entries = values.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final visible = entries.take(8).toList();
    final max = visible.isEmpty
        ? 1.0
        : visible.first.value.toDouble().clamp(1, double.infinity);
    final content = Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 18),
          if (visible.isEmpty)
            const SizedBox(
              height: 140,
              child: Center(
                child: Text(
                  'Chưa có dữ liệu',
                  style: TextStyle(color: AdminTheme.mutedInk),
                ),
              ),
            )
          else
            for (final entry in visible)
              Tooltip(
                message:
                    '${entry.key}: ${money ? _money.format(entry.value) : entry.value}',
                waitDuration: const Duration(milliseconds: 150),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 11),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 112,
                        child: Text(
                          entry.key,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) => Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              width: constraints.maxWidth * entry.value / max,
                              height: 10,
                              decoration: BoxDecoration(
                                color: highlight
                                    ? AdminTheme.orange
                                    : AdminTheme.teal,
                                borderRadius: BorderRadius.circular(99),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 94,
                        child: Text(
                          money ? _money.format(entry.value) : '${entry.value}',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
    return embedded ? content : Card(child: content);
  }
}

class _ChartGrid extends StatelessWidget {
  const _ChartGrid({required this.data});
  final PlatformWorkspace data;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth >= 850
          ? (constraints.maxWidth - 12) / 2
          : constraints.maxWidth;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          SizedBox(
            width: width,
            child: MetricBarChart(
              title: 'Doanh thu theo ngày',
              values: data.analytics.revenueByDay,
              money: true,
            ),
          ),
          SizedBox(
            width: width,
            child: MetricBarChart(
              title: 'Doanh thu theo gói',
              values: data.analytics.revenueByPlan,
              money: true,
              highlight: true,
            ),
          ),
          SizedBox(
            width: width,
            child: MetricBarChart(
              title: 'Doanh thu theo tỉnh',
              values: data.analytics.revenueByProvince,
              money: true,
            ),
          ),
          SizedBox(
            width: width,
            child: MetricBarChart(
              title: 'Trạng thái giao dịch',
              values: data.analytics.transactionStatus,
              highlight: true,
            ),
          ),
        ],
      );
    },
  );
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({required this.status, super.key});
  final String status;
  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'active' || 'paid' || 'verified' => AdminTheme.success,
      'pending' || 'processing' || 'trial' || 'unchecked' => AdminTheme.orange,
      'suspended' ||
      'failed' ||
      'cancelled' ||
      'expired' ||
      'inactive' => AdminTheme.danger,
      _ => AdminTheme.mutedInk,
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Text(
          statusLabel(status),
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}

class EventTable extends StatelessWidget {
  const EventTable({required this.events, this.webhook = false, super.key});
  final List<PlatformEvent> events;
  final bool webhook;
  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return EmptyState(
        icon: webhook ? Icons.webhook_outlined : Icons.policy_outlined,
        title: webhook ? 'Chưa có webhook' : 'Chưa có thao tác kiểm toán',
        message: 'Các sự kiện mới sẽ xuất hiện tại đây.',
      );
    }
    return _TableCard(
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Thời gian')),
          DataColumn(label: Text('Tác nhân / nguồn')),
          DataColumn(label: Text('Hành động')),
          DataColumn(label: Text('Đối tượng')),
          DataColumn(label: Text('Trạng thái')),
        ],
        rows: events
            .map(
              (event) => DataRow(
                cells: [
                  DataCell(Text(formatDateTime(event.createdAt))),
                  DataCell(
                    Text(event.actor.ifEmpty(webhook ? 'PayOS' : 'Hệ thống')),
                  ),
                  DataCell(Text(event.action.ifEmpty(event.status))),
                  DataCell(
                    Text('${event.entityType} ${event.entityId}'.trim()),
                  ),
                  DataCell(
                    StatusBadge(status: event.status.ifEmpty('verified')),
                  ),
                ],
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({required this.title, required this.caption, super.key});
  final String title;
  final String caption;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.headlineMedium),
      ),
      Text(
        caption,
        style: const TextStyle(color: AdminTheme.mutedInk, fontSize: 12),
      ),
    ],
  );
}

class LoadingState extends StatelessWidget {
  const LoadingState({super.key});
  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var i = 0; i < 3; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            height: i == 2 ? 300 : 86,
            decoration: BoxDecoration(
              color: AdminTheme.skeleton,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
    ],
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    super.key,
  });
  final IconData icon;
  final String title;
  final String message;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 50),
      child: Column(
        children: [
          Icon(icon, size: 34, color: AdminTheme.mutedInk),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 5),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AdminTheme.mutedInk),
          ),
        ],
      ),
    ),
  );
}

class ErrorState extends StatelessWidget {
  const ErrorState({required this.error, required this.onRetry, super.key});
  final Object? error;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(34),
      child: Column(
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            color: AdminTheme.danger,
            size: 34,
          ),
          const SizedBox(height: 12),
          Text(
            'Không tải được dữ liệu',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          const Text(
            'Kiểm tra quyền quản trị, chỉ mục Firestore và kết nối Firebase.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AdminTheme.mutedInk),
          ),
          const SizedBox(height: 16),
          FilledButton.tonal(onPressed: onRetry, child: const Text('Thử lại')),
        ],
      ),
    ),
  );
}

class _TableCard extends StatelessWidget {
  const _TableCard({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Card(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: child,
          ),
        ),
      ),
    ),
  );
}

class _Pagination extends StatelessWidget {
  const _Pagination({
    required this.page,
    required this.pageSize,
    required this.total,
    required this.onChanged,
  });
  final int page;
  final int pageSize;
  final int total;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) {
    final pages = (total / pageSize).ceil();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            '${page * pageSize + 1}-${((page + 1) * pageSize).clamp(0, total)} / $total',
            style: const TextStyle(color: AdminTheme.mutedInk),
          ),
          IconButton(
            onPressed: page > 0 ? () => onChanged(page - 1) : null,
            icon: const Icon(Icons.chevron_left),
          ),
          IconButton(
            onPressed: page + 1 < pages ? () => onChanged(page + 1) : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.api,
    required this.onChanged,
  });
  final PlatformPlan plan;
  final AdminApi api;
  final VoidCallback onChanged;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  plan.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              StatusBadge(status: plan.status),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${_money.format(plan.monthlyPrice)} / tháng',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _PlanBadge(
                icon: Icons.calendar_today_outlined,
                label: '${_money.format(plan.annualPrice)} / năm',
              ),
              _PlanBadge(
                icon: Icons.hourglass_bottom_rounded,
                label: '${plan.trialDays} ngày dùng thử',
                highlight: plan.trialDays > 0,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            plan.description.ifEmpty('Chưa có mô tả'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AdminTheme.mutedInk),
          ),
          const Divider(height: 28),
          const Text(
            'Quyền lợi trong gói',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 10),
          if (plan.features.isEmpty)
            const Text(
              'Chưa có quyền lợi được cấu hình.',
              style: TextStyle(color: AdminTheme.mutedInk, fontSize: 13),
            )
          else
            ...plan.features.map(
              (feature) => Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      color: AdminTheme.success,
                      size: 17,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        feature,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              OutlinedButton(
                onPressed: () => showAdminDialog<void>(
                  context: context,
                  builder: (_) =>
                      PlanDialog(plan: plan, api: api, onChanged: onChanged),
                ),
                child: const Text('Chỉnh sửa'),
              ),
              const Spacer(),
              PopupMenuButton<String>(
                onSelected: (action) => _confirmedAction(
                  context,
                  api,
                  'plan.$action',
                  plan.id,
                  'Xác nhận thay đổi trạng thái gói?',
                  onChanged,
                ),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'activate', child: Text('Kích hoạt')),
                  PopupMenuItem(value: 'deactivate', child: Text('Tạm ngưng')),
                  PopupMenuItem(value: 'archive', child: Text('Lưu trữ')),
                ],
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _PlanBadge extends StatelessWidget {
  const _PlanBadge({
    required this.icon,
    required this.label,
    this.highlight = false,
  });

  final IconData icon;
  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: highlight
          ? AdminTheme.orange.withValues(alpha: 0.1)
          : AdminTheme.teal.withValues(alpha: 0.09),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
        color: highlight
            ? AdminTheme.orange.withValues(alpha: 0.35)
            : AdminTheme.teal.withValues(alpha: 0.3),
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: highlight ? AdminTheme.orange : AdminTheme.tealDark,
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
}

class _HealthCard extends StatelessWidget {
  const _HealthCard({
    required this.label,
    required this.detail,
    required this.ok,
  });
  final String label;
  final String detail;
  final bool? ok;
  @override
  Widget build(BuildContext context) {
    final color = ok == true
        ? AdminTheme.success
        : ok == false
        ? AdminTheme.danger
        : AdminTheme.mutedInk;
    return SizedBox(
      width: 270,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      detail,
                      style: const TextStyle(
                        color: AdminTheme.mutedInk,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LimitNotice extends StatelessWidget {
  const _LimitNotice();
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AdminTheme.orange.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(10),
    ),
    child: const Row(
      children: [
        Icon(Icons.info_outline, color: AdminTheme.orange),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'Dữ liệu vượt giới hạn đọc an toàn. Các số liệu nhóm chỉ phản ánh phần dữ liệu đã tải; hãy thu hẹp bộ lọc thời gian.',
          ),
        ),
      ],
    ),
  );
}

class _ExportCard extends StatelessWidget {
  const _ExportCard({
    required this.title,
    required this.count,
    required this.icon,
    required this.onExport,
  });
  final String title;
  final int count;
  final IconData icon;
  final Future<void> Function() onExport;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 310,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(icon, color: AdminTheme.tealDark, size: 28),
            const SizedBox(height: 14),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            Text(
              '$count dòng theo bộ lọc',
              style: const TextStyle(color: AdminTheme.mutedInk),
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: count == 0 ? null : onExport,
              icon: const Icon(Icons.download),
              label: const Text('Xuất CSV'),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _subscriptionAction(
  BuildContext context,
  String action,
  PlatformBusinessRecord business,
  List<PlatformPlan> plans,
  AdminApi api,
  VoidCallback onChanged,
) async {
  if (action == 'change') {
    final activePlans = plans
        .where((item) => item.status == 'active')
        .toList(growable: false);
    String? plan = activePlans.any((item) => item.id == business.planTier)
        ? business.planTier
        : null;
    final form = GlobalKey<FormState>();
    final confirmed = await showAdminDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đổi gói SaaS'),
        content: Form(
          key: form,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: DropdownButtonFormField<String>(
            initialValue: plan,
            decoration: const InputDecoration(labelText: 'Gói SaaS'),
            items: activePlans
                .map(
                  (item) =>
                      DropdownMenuItem(value: item.id, child: Text(item.name)),
                )
                .toList(),
            onChanged: (value) => plan = value,
            validator: _required,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
    if (!context.mounted) return;
    if (confirmed == true) {
      await _runAction(context, api, 'subscription.change_plan', business.id, {
        'planTier': plan!,
      }, onChanged);
    }
    return;
  }
  if (action == 'extend') {
    final controller = TextEditingController(text: '30');
    final form = GlobalKey<FormState>();
    final confirmed = await showAdminDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gia hạn thủ công'),
        content: Form(
          key: form,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: TextFormField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Số ngày'),
            validator: (value) =>
                _integerRange(value, label: 'Số ngày', min: 1, max: 3650),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
    final days = int.tryParse(controller.text);
    controller.dispose();
    if (!context.mounted) return;
    if (confirmed == true && days != null) {
      await _runAction(context, api, 'subscription.extend', business.id, {
        'days': days,
      }, onChanged);
    }
    return;
  }
  await _confirmedAction(
    context,
    api,
    'subscription.$action',
    business.id,
    action == 'cancel' ? 'Hủy gói đăng ký này?' : 'Kích hoạt lại gói đăng ký?',
    onChanged,
  );
}

Future<void> _confirmedAction(
  BuildContext context,
  AdminApi api,
  String action,
  String id,
  String message,
  VoidCallback onChanged,
) async {
  final confirmed = await showAdminDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Xác nhận thao tác'),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Không'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Xác nhận'),
        ),
      ],
    ),
  );
  if (confirmed == true && context.mounted) {
    await _runAction(context, api, action, id, const {}, onChanged);
  }
}

Future<void> _runAction(
  BuildContext context,
  AdminApi api,
  String action,
  String id,
  Map<String, Object?> payload,
  VoidCallback onChanged,
) async {
  try {
    await api.performAction(action: action, resourceId: id, payload: payload);
    onChanged();
    if (context.mounted) {
      Navigator.maybePop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã cập nhật và ghi nhật ký kiểm toán.')),
      );
    }
  } catch (error) {
    if (context.mounted) _showError(context, error);
  }
}

void _showError(BuildContext context, Object error) =>
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Không thể thực hiện: $error'),
        backgroundColor: AdminTheme.danger,
      ),
    );

Future<void> _exportTransactions(List<PlatformTransaction> rows) => downloadCsv(
  'schedula-transactions.csv',
  _csv([
    [
      'transactionId',
      'orderCode',
      'business',
      'tenantId',
      'province',
      'plan',
      'amount',
      'provider',
      'method',
      'status',
      'createdAt',
    ],
    for (final row in rows)
      [
        row.id,
        row.orderCode,
        row.businessName,
        row.tenantId,
        row.province,
        row.planTier,
        row.amount,
        row.provider,
        row.method,
        row.status,
        row.createdAt?.toIso8601String() ?? '',
      ],
  ]),
);
Future<void> _exportBusinesses(List<PlatformBusinessRecord> rows) =>
    downloadCsv(
      'schedula-businesses.csv',
      _csv([
        [
          'tenantId',
          'name',
          'owner',
          'email',
          'phone',
          'type',
          'province',
          'plan',
          'subscriptionStatus',
          'accountStatus',
          'createdAt',
        ],
        for (final row in rows)
          [
            row.id,
            row.name,
            row.ownerName,
            row.ownerEmail,
            row.phone,
            row.businessType,
            row.province,
            row.planTier,
            row.subscriptionStatus,
            row.status,
            row.createdAt?.toIso8601String() ?? '',
          ],
      ]),
    );
Future<void> _exportProvinces(PlatformAnalytics analytics) => downloadCsv(
  'schedula-provinces.csv',
  _csv([
    ['province', 'businesses', 'revenue'],
    for (final province in {
      ...analytics.businessesByProvince.keys,
      ...analytics.revenueByProvince.keys,
    })
      [
        province,
        analytics.businessesByProvince[province] ?? 0,
        analytics.revenueByProvince[province] ?? 0,
      ],
  ]),
);
Future<void> _exportEvents(List<PlatformEvent> rows) => downloadCsv(
  'schedula-audit-log.csv',
  _csv([
    ['id', 'createdAt', 'actor', 'action', 'entityType', 'entityId', 'status'],
    for (final row in rows)
      [
        row.id,
        row.createdAt?.toIso8601String() ?? '',
        row.actor,
        row.action,
        row.entityType,
        row.entityId,
        row.status,
      ],
  ]),
);

String _csv(List<List<Object?>> rows) => rows
    .map(
      (row) => row
          .map((cell) => '"${cell.toString().replaceAll('"', '""')}"')
          .join(','),
    )
    .join('\r\n');
List<String> _options(Iterable<String> values, String current) => {
  ...values.where((item) => item.isNotEmpty),
  if (current.isNotEmpty) current,
}.toList()..sort();
String _rangeValue(WorkspaceFilter filter) {
  final days = filter.end.difference(filter.start).inDays + 1;
  if (days > 365) return 'all';
  return [7, 30, 90, 365].contains(days) ? '$days' : 'custom';
}

String formatDate(DateTime? value) =>
    value == null ? 'Chưa cập nhật' : _date.format(value);
String formatDateTime(DateTime? value) =>
    value == null ? 'Chưa cập nhật' : _dateTime.format(value);
String statusLabel(String status) =>
    const {
      'active': 'Hoạt động',
      'paid': 'Đã thanh toán',
      'pending': 'Đang chờ',
      'failed': 'Thất bại',
      'cancelled': 'Đã hủy',
      'refunded': 'Hoàn tiền',
      'superseded': 'Đã thay thế',
      'processing': 'Đang xử lý',
      'trial': 'Dùng thử',
      'expired': 'Hết hạn',
      'suspended': 'Tạm ngưng',
      'inactive': 'Vô hiệu',
      'verified': 'Đã xác minh',
      'unchecked': 'Chưa kiểm tra',
      'mismatch': 'Không khớp',
      'archived': 'Lưu trữ',
    }[status] ??
    status;
String reconciliationLabel(String value) =>
    const {
      'verified': 'Đã khớp với PayOS',
      'mismatch': 'Sai lệch dữ liệu',
      'unchecked': 'Chưa kiểm tra',
    }[value] ??
    value;
String usageLabel(String value) =>
    const {
      'bookings': 'Lịch hẹn',
      'customers': 'Khách hàng',
      'staff': 'Nhân viên',
      'services': 'Dịch vụ',
      'products': 'Sản phẩm',
      'equipment': 'Thiết bị',
    }[value] ??
    value;
String? _required(String? value) =>
    value == null || value.trim().isEmpty ? 'Vui lòng nhập trường này' : null;
String? _planId(String? value) {
  final input = value?.trim() ?? '';
  if (input.isEmpty) return 'Vui lòng nhập mã gói';
  return RegExp(r'^[a-z0-9][a-z0-9_-]*$').hasMatch(input)
      ? null
      : 'Chỉ dùng chữ thường, số, dấu gạch ngang hoặc gạch dưới';
}

String? _firebaseUid(String? value) {
  final input = value?.trim() ?? '';
  if (input.isEmpty) return 'Vui lòng nhập Firebase Auth UID';
  return RegExp(r'^[A-Za-z0-9_-]{20,128}$').hasMatch(input)
      ? null
      : 'Firebase Auth UID không hợp lệ';
}

String? _integerRange(
  String? value, {
  required String label,
  required int min,
  int? max,
}) {
  final number = int.tryParse(value?.trim() ?? '');
  if (number == null) return '$label phải là số nguyên';
  if (number < min || (max != null && number > max)) {
    return max == null
        ? '$label phải từ $min trở lên'
        : '$label phải nằm trong khoảng $min đến $max';
  }
  return null;
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
