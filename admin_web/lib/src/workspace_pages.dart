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
final _filterTime = DateFormat('HH:mm:ss');

String _filterDateTimeText(DateTime value) =>
    '${value.day} tháng ${value.month}, ${_filterTime.format(value)}';

String _shortVietnameseDate(DateTime value, {bool includeYear = false}) =>
    '${value.day} tháng ${value.month}${includeYear ? ', ${value.year}' : ''}';

String _planLabel(String value) => switch (value.trim().toLowerCase()) {
  'basic' => 'Cơ bản',
  'pro' || 'professional' => 'Chuyên nghiệp',
  'premium' || 'enterprise' => 'Doanh nghiệp',
  _ => value,
};

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
                    title,
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
                      if (_usesFilters(section) && snapshot.data != null) ...[
                        GlobalFilterBar(
                          key: ValueKey('filters-${section.name}'),
                          section: section,
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

String _title(AdminSection section) => switch (section) {
  AdminSection.dashboard => 'Tổng quan hệ thống',
  AdminSection.businesses => 'Doanh nghiệp',
  AdminSection.transactions => 'Giao dịch',
  AdminSection.subscriptions => 'Gói đăng ký',
  AdminSection.revenue => 'Phân tích doanh thu',
  AdminSection.plans => 'Gói và bảng giá SaaS',
  AdminSection.monitoring => 'Vận hành hệ thống',
  AdminSection.reports => 'Báo cáo',
  AdminSection.admins => 'Quản trị viên',
  AdminSection.settings => 'Cài đặt',
};

bool _usesFilters(AdminSection section) => !{
  AdminSection.plans,
  AdminSection.monitoring,
  AdminSection.admins,
  AdminSection.settings,
}.contains(section);

class GlobalFilterBar extends StatefulWidget {
  const GlobalFilterBar({
    this.section = AdminSection.dashboard,
    required this.value,
    required this.workspace,
    required this.onApply,
    super.key,
  });

  final AdminSection section;
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
    final showSearch = {
      AdminSection.businesses,
      AdminSection.transactions,
      AdminSection.subscriptions,
      AdminSection.reports,
    }.contains(widget.section);
    final showDate = {
      AdminSection.dashboard,
      AdminSection.transactions,
      AdminSection.revenue,
      AdminSection.reports,
    }.contains(widget.section);
    final showBusinessType = widget.section == AdminSection.businesses;
    final showSubscriptionStatus = {
      AdminSection.dashboard,
      AdminSection.businesses,
      AdminSection.subscriptions,
    }.contains(widget.section);
    final showTransactionStatus = {
      AdminSection.transactions,
      AdminSection.revenue,
      AdminSection.reports,
    }.contains(widget.section);
    final plans = _options(
      widget.workspace.plans.map((item) => item.id),
      draft.plan,
    );
    final businessTypes = _options(
      widget.workspace.businesses.map((item) => item.businessType),
      draft.businessType,
    );
    final controls = <Widget>[
      if (showSearch)
        SizedBox(
          width: 250,
          child: TextField(
            controller: search,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search, size: 20),
              hintText: widget.section == AdminSection.transactions
                  ? 'Tìm giao dịch, doanh nghiệp...'
                  : 'Tìm doanh nghiệp, chủ sở hữu...',
              isDense: true,
            ),
            onSubmitted: (_) => _apply(),
          ),
        ),
      if (showDate)
        _DateRangeField(
          value: draft,
          onChanged: (range) => setState(
            () => draft = draft.copyWith(start: range.start, end: range.end),
          ),
        ),
      if (showBusinessType)
        _Select(
          width: 175,
          value: draft.businessType,
          label: 'Loại hình',
          items: {
            '': 'Tất cả loại hình',
            for (final item in businessTypes) item: item,
          },
          onChanged: (value) =>
              setState(() => draft = draft.copyWith(businessType: value)),
        ),
      _Select(
        width: 160,
        value: draft.plan,
        label: 'Gói',
        items: {
          '': 'Tất cả gói',
          for (final item in plans) item: _planLabel(item),
        },
        onChanged: (value) =>
            setState(() => draft = draft.copyWith(plan: value)),
      ),
      if (showSubscriptionStatus)
        _Select(
          width: 175,
          value: draft.subscriptionStatus,
          label: 'Đăng ký',
          items: const {
            '': 'Mọi trạng thái',
            'trial': 'Dùng thử',
            'active': 'Hoạt động',
            'expired': 'Hết hạn',
            'cancelled': 'Đã hủy',
          },
          onChanged: (value) =>
              setState(() => draft = draft.copyWith(subscriptionStatus: value)),
        ),
      if (showTransactionStatus)
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
          onChanged: (value) =>
              setState(() => draft = draft.copyWith(transactionStatus: value)),
        ),
      SizedBox(
        height: 56,
        child: FilledButton.icon(
          onPressed: _apply,
          icon: const Icon(Icons.filter_alt_outlined, size: 18),
          label: const Text('Áp dụng'),
        ),
      ),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: SingleChildScrollView(
          key: const ValueKey('workspace-filter-strip'),
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final (index, control) in controls.indexed) ...[
                if (index > 0) const SizedBox(width: 12),
                control,
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _apply() {
    final businesses = widget.section == AdminSection.businesses;
    final subscriptions = widget.section == AdminSection.subscriptions;
    final transactions = {
      AdminSection.transactions,
      AdminSection.revenue,
      AdminSection.reports,
    }.contains(widget.section);
    widget.onApply(
      draft.copyWith(
        query:
            {
              AdminSection.businesses,
              AdminSection.transactions,
              AdminSection.subscriptions,
              AdminSection.reports,
            }.contains(widget.section)
            ? search.text
            : '',
        province: '',
        businessType: businesses ? draft.businessType : '',
        subscriptionStatus:
            businesses ||
                subscriptions ||
                widget.section == AdminSection.dashboard
            ? draft.subscriptionStatus
            : '',
        transactionStatus: transactions ? draft.transactionStatus : '',
      ),
    );
  }
}

class _DateRangeField extends StatefulWidget {
  const _DateRangeField({required this.value, required this.onChanged});

  final WorkspaceFilter value;
  final ValueChanged<DateTimeRange> onChanged;

  @override
  State<_DateRangeField> createState() => _DateRangeFieldState();
}

class _DateRangeFieldState extends State<_DateRangeField> {
  final _portal = OverlayPortalController();
  final _link = LayerLink();
  late DateTime _visibleMonth;
  late DateTime _start;
  DateTime? _end;
  bool _choosingEnd = false;

  DateTime get _lastDate {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return DateTime(tomorrow.year, tomorrow.month, tomorrow.day);
  }

  @override
  void initState() {
    super.initState();
    _resetDraft();
  }

  @override
  void didUpdateWidget(covariant _DateRangeField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && !_portal.isShowing) _resetDraft();
  }

  void _resetDraft() {
    _start = DateUtils.dateOnly(widget.value.start);
    _end = DateUtils.dateOnly(widget.value.end);
    _visibleMonth = DateTime(_start.year, _start.month);
    _choosingEnd = false;
  }

  void _open() {
    _resetDraft();
    _portal.show();
  }

  void _close() => _portal.hide();

  void _select(DateTime day) {
    if (day.isBefore(DateTime(2020)) || day.isAfter(_lastDate)) return;
    setState(() {
      if (!_choosingEnd) {
        _start = day;
        _end = null;
        _choosingEnd = true;
      } else {
        if (day.isBefore(_start)) {
          _end = _start;
          _start = day;
        } else {
          _end = day;
        }
        _choosingEnd = false;
      }
    });
  }

  void _apply() {
    final end = _end ?? _start;
    widget.onChanged(
      DateTimeRange(
        start: _start,
        end: DateTime(end.year, end.month, end.day, 23, 59, 59),
      ),
    );
    _close();
  }

  @override
  Widget build(BuildContext context) => CompositedTransformTarget(
    link: _link,
    child: OverlayPortal(
      controller: _portal,
      overlayLocation: OverlayChildLocation.rootOverlay,
      overlayChildBuilder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _close,
            ),
          ),
          CompositedTransformFollower(
            link: _link,
            showWhenUnlinked: false,
            targetAnchor: Alignment.bottomLeft,
            followerAnchor: Alignment.topLeft,
            offset: const Offset(0, 6),
            child: _DateRangeDropdown(
              visibleMonth: _visibleMonth,
              start: _start,
              end: _end,
              firstDate: DateTime(2020),
              lastDate: _lastDate,
              onPreviousMonth: () => setState(
                () => _visibleMonth = DateTime(
                  _visibleMonth.year,
                  _visibleMonth.month - 1,
                ),
              ),
              onNextMonth: () => setState(
                () => _visibleMonth = DateTime(
                  _visibleMonth.year,
                  _visibleMonth.month + 1,
                ),
              ),
              onSelect: _select,
              onCancel: _close,
              onApply: _apply,
            ),
          ),
        ],
      ),
      child: SizedBox(
        key: const ValueKey('workspace-date-range'),
        width: 350,
        height: 56,
        child: OutlinedButton(
          onPressed: _portal.isShowing ? _close : _open,
          style: OutlinedButton.styleFrom(
            foregroundColor: AdminTheme.ink,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            side: const BorderSide(color: AdminTheme.strongBorder),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.calendar_month_outlined, size: 19),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${_filterDateTimeText(widget.value.start)} – '
                  '${_filterDateTimeText(widget.value.end)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.expand_more, size: 19),
            ],
          ),
        ),
      ),
    ),
  );
}

class _DateRangeDropdown extends StatelessWidget {
  const _DateRangeDropdown({
    required this.visibleMonth,
    required this.start,
    required this.end,
    required this.firstDate,
    required this.lastDate,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onSelect,
    required this.onCancel,
    required this.onApply,
  });

  final DateTime visibleMonth;
  final DateTime start;
  final DateTime? end;
  final DateTime firstDate;
  final DateTime lastDate;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final ValueChanged<DateTime> onSelect;
  final VoidCallback onCancel;
  final VoidCallback onApply;

  bool get _canGoPrevious =>
      visibleMonth.isAfter(DateTime(firstDate.year, firstDate.month));

  bool get _canGoNext => DateTime(
    visibleMonth.year,
    visibleMonth.month + 1,
  ).isBefore(DateTime(lastDate.year, lastDate.month + 1));

  @override
  Widget build(BuildContext context) {
    final secondMonth = DateTime(visibleMonth.year, visibleMonth.month + 1);
    final selectedEnd = end ?? start;
    return Material(
      key: const ValueKey('workspace-date-dropdown'),
      color: Colors.white,
      elevation: 8,
      shadowColor: AdminTheme.ink.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: Container(
        width: 736,
        decoration: BoxDecoration(
          border: Border.all(color: AdminTheme.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 10, 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Chọn khoảng ngày',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Đóng',
                    onPressed: onCancel,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    onPressed: _canGoPrevious ? onPreviousMonth : null,
                    icon: const Icon(Icons.chevron_left, size: 28),
                  ),
                  Expanded(
                    child: _CalendarMonth(
                      month: visibleMonth,
                      start: start,
                      end: end,
                      firstDate: firstDate,
                      lastDate: lastDate,
                      onSelect: onSelect,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _CalendarMonth(
                      month: secondMonth,
                      start: start,
                      end: end,
                      firstDate: firstDate,
                      lastDate: lastDate,
                      onSelect: onSelect,
                    ),
                  ),
                  IconButton(
                    onPressed: _canGoNext ? onNextMonth : null,
                    icon: const Icon(Icons.chevron_right, size: 28),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Đã chọn: ${_shortVietnameseDate(start)} – '
                      '${_shortVietnameseDate(selectedEnd, includeYear: true)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: const TextStyle(color: AdminTheme.mutedInk),
                    ),
                  ),
                  const SizedBox(width: 16),
                  OutlinedButton(
                    onPressed: onCancel,
                    child: const Text('Hủy'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: onApply,
                    child: const Text('Áp dụng'),
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

class _CalendarMonth extends StatelessWidget {
  const _CalendarMonth({
    required this.month,
    required this.start,
    required this.end,
    required this.firstDate,
    required this.lastDate,
    required this.onSelect,
  });

  final DateTime month;
  final DateTime start;
  final DateTime? end;
  final DateTime firstDate;
  final DateTime lastDate;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final firstOfMonth = DateTime(month.year, month.month);
    final firstCell = firstOfMonth.subtract(
      Duration(days: firstOfMonth.weekday - DateTime.monday),
    );
    const weekdays = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    return Column(
      children: [
        SizedBox(
          height: 44,
          child: Center(
            child: Text(
              'THÁNG ${month.month} ${month.year}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        Row(
          children: [
            for (final weekday in weekdays)
              Expanded(
                child: Center(
                  child: Text(
                    weekday,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AdminTheme.mutedInk,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 230,
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1.08,
            ),
            itemCount: 42,
            itemBuilder: (context, index) {
              final day = firstCell.add(Duration(days: index));
              final inMonth = day.month == month.month;
              final enabled =
                  !day.isBefore(firstDate) && !day.isAfter(lastDate);
              final isStart = DateUtils.isSameDay(day, start);
              final isEnd = end != null && DateUtils.isSameDay(day, end);
              final inRange =
                  end != null && !day.isBefore(start) && !day.isAfter(end!);
              return InkWell(
                onTap: enabled ? () => onSelect(day) : null,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  decoration: BoxDecoration(
                    color: inRange ? AdminTheme.inputBackground : null,
                    border: isStart || isEnd
                        ? Border.all(color: AdminTheme.orange, width: 1.5)
                        : null,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${day.day}',
                    style: TextStyle(
                      fontSize: 13,
                      color: enabled && inMonth
                          ? AdminTheme.ink
                          : AdminTheme.mutedInk.withValues(alpha: 0.42),
                      fontWeight: isStart || isEnd
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
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
    final recentlyActive = data.metrics.activeBusinesses30d;
    final usageRate = data.metrics.usageRate30d;
    final planUsage = <String, num>{};
    for (final business in data.businesses) {
      final label = _planLabel(business.planTier);
      planUsage[label] = (planUsage[label] ?? 0) + 1;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
        '$recentlyActive/${data.businesses.length} doanh nghiệp có hoạt động trong kỳ đã chọn.',
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
      tooltip:
          'Các chỉ số trong khối này dùng chung kỳ thời gian và bộ lọc ở đầu trang.',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final chart = _DailyTrendChart(
            title: 'Xu hướng doanh thu theo ngày',
            tooltip:
                'Di chuột lên từng cột để xem ngày và doanh thu chính xác.',
            values: data.analytics.revenueByDay,
            money: true,
            emptyMessage: 'Chưa có doanh thu trong kỳ',
          );
          final relationships = _RelationshipGrid(
            items: [
              (
                'MRR',
                _money.format(metrics.mrr),
                'Doanh thu định kỳ hàng tháng từ các gói đang hoạt động.',
                _MetricTone.neutral,
              ),
              (
                'ARR',
                _money.format(metrics.arr),
                'Doanh thu định kỳ năm, được ước tính bằng MRR nhân 12.',
                _MetricTone.neutral,
              ),
              (
                'ARPU',
                _money.format(metrics.arpu),
                'Doanh thu trung bình trên mỗi doanh nghiệp có gói hoạt động.',
                _MetricTone.neutral,
              ),
              (
                'Thanh toán thất bại',
                '${metrics.failedPayments} · ${_money.format(metrics.failedPaymentAmount)}',
                'Số lượng và tổng giá trị giao dịch thất bại trong kỳ.',
                metrics.failedPayments > 0
                    ? _MetricTone.danger
                    : _MetricTone.neutral,
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

enum _BusinessTrend { usage, newTenants, churnedTenants }

class _BusinessStory extends StatefulWidget {
  const _BusinessStory({
    required this.data,
    required this.usageRate,
    required this.planUsage,
  });

  final PlatformWorkspace data;
  final double usageRate;
  final Map<String, num> planUsage;

  @override
  State<_BusinessStory> createState() => _BusinessStoryState();
}

class _BusinessStoryState extends State<_BusinessStory> {
  _BusinessTrend selected = _BusinessTrend.usage;

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final metrics = data.metrics;
    final selectedIndex = switch (selected) {
      _BusinessTrend.usage => 0,
      _BusinessTrend.newTenants => 1,
      _BusinessTrend.churnedTenants => 3,
    };
    final chartTitle = switch (selected) {
      _BusinessTrend.usage => 'Tỷ lệ sử dụng trong kỳ đã chọn',
      _BusinessTrend.newTenants => 'Doanh nghiệp mới trong kỳ đã chọn',
      _BusinessTrend.churnedTenants => 'Doanh nghiệp rời bỏ trong kỳ đã chọn',
    };
    final chartTooltip = switch (selected) {
      _BusinessTrend.usage =>
        'Mỗi cột là tỷ lệ doanh nghiệp có ít nhất một lịch hẹn trong ngày.',
      _BusinessTrend.newTenants =>
        'Mỗi cột là số doanh nghiệp được tạo trong ngày.',
      _BusinessTrend.churnedTenants =>
        'Mỗi cột là số doanh nghiệp hết hạn hoặc hủy trong ngày.',
    };
    Widget chart(bool showTitle) => switch (selected) {
      _BusinessTrend.usage => _DailyTrendChart(
        key: const ValueKey(_BusinessTrend.usage),
        title: chartTitle,
        tooltip: chartTooltip,
        showTitle: showTitle,
        values: data.analytics.usageRateByDay,
        percent: true,
        emptyMessage: 'Chưa có hoạt động trong kỳ đã chọn',
      ),
      _BusinessTrend.newTenants => _DailyTrendChart(
        key: const ValueKey(_BusinessTrend.newTenants),
        title: chartTitle,
        tooltip: chartTooltip,
        showTitle: showTitle,
        values: data.analytics.newBusinessesByDay,
        color: AdminTheme.success,
        emptyMessage: 'Không có doanh nghiệp mới trong kỳ đã chọn',
      ),
      _BusinessTrend.churnedTenants => _DailyTrendChart(
        key: const ValueKey(_BusinessTrend.churnedTenants),
        title: chartTitle,
        tooltip: chartTooltip,
        showTitle: showTitle,
        values: data.analytics.churnedBusinessesByDay,
        color: AdminTheme.danger,
        emptyMessage: 'Không có doanh nghiệp rời bỏ trong kỳ đã chọn',
      ),
    };
    final overview = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RelationshipGrid(
          selectedIndex: selectedIndex,
          selectableIndices: const {0, 1, 3},
          onSelected: (index) => setState(() {
            selected = switch (index) {
              1 => _BusinessTrend.newTenants,
              3 => _BusinessTrend.churnedTenants,
              _ => _BusinessTrend.usage,
            };
          }),
          items: [
            (
              'Mức sử dụng trong kỳ',
              '${widget.usageRate.toStringAsFixed(1)}%',
              'Nhấn để xem tỷ lệ doanh nghiệp có hoạt động theo ngày.',
              widget.usageRate >= 70
                  ? _MetricTone.success
                  : widget.usageRate >= 40
                  ? _MetricTone.warning
                  : _MetricTone.danger,
            ),
            (
              'Doanh nghiệp mới',
              '+${metrics.newBusinesses}',
              'Nhấn để xem số doanh nghiệp mới theo ngày.',
              _MetricTone.success,
            ),
            (
              'Đang dùng thử',
              '${metrics.trialBusinesses}',
              'Doanh nghiệp chưa chuyển sang gói trả phí.',
              _MetricTone.neutral,
            ),
            (
              'Đã rời bỏ',
              '-${metrics.churnedBusinesses}',
              'Nhấn để xem số doanh nghiệp hết hạn hoặc hủy theo ngày.',
              _MetricTone.danger,
            ),
          ],
        ),
        const SizedBox(height: 20),
        SegmentedBreakdown(
          title: 'Tỷ lệ gói đang được sử dụng',
          values: widget.planUsage,
          tooltip:
              'Tỷ trọng doanh nghiệp theo gói hiện tại. Di chuột lên từng phần để xem chi tiết.',
        ),
      ],
    );
    return _StoryPanel(
      title: 'Doanh nghiệp và mức sử dụng',
      tooltip:
          'Biểu đồ dùng dữ liệu lịch hẹn, ngày tạo doanh nghiệp và ngày kết thúc đăng ký trong kỳ đã chọn.',
      rightTitle: chartTitle,
      rightTooltip: chartTooltip,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final trend = chart(constraints.maxWidth < 900);
          if (constraints.maxWidth < 900) {
            return Column(
              children: [overview, const SizedBox(height: 24), trend],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 2, child: overview),
              const SizedBox(width: 32),
              Expanded(flex: 3, child: trend),
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
                  DataCell(Text(_planLabel(business.planTier))),
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
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          const _HealthCard(
            label: 'Xác thực',
            detail: 'Firebase Authentication',
          ),
          const _HealthCard(
            label: 'Cơ sở dữ liệu',
            detail: 'Callable API hoạt động',
          ),
        ],
      ),
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
              DataColumn(label: Text('Số điện thoại')),
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
                          business.ownerPhone
                              .ifEmpty(business.phone)
                              .ifEmpty('Chưa cập nhật'),
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
                      DataCell(Text(_planLabel(business.planTier))),
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
                      DataCell(Text(_planLabel(transaction.planTier))),
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

class BusinessDetailDialog extends StatefulWidget {
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
  State<BusinessDetailDialog> createState() => _BusinessDetailDialogState();
}

class _BusinessDetailDialogState extends State<BusinessDetailDialog> {
  late Future<Map<Object?, Object?>> detail;
  String? expandedKind;

  @override
  void initState() {
    super.initState();
    detail = widget.api.getBusinessDetail(widget.business.id);
  }

  void reload() => setState(() {
    detail = widget.api.getBusinessDetail(widget.business.id);
  });

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Row(
      children: [
        Expanded(child: Text(widget.business.name)),
        IconButton(
          tooltip: 'Chỉnh sửa thông tin doanh nghiệp',
          onPressed: () => _editBusinessInfo(context),
          icon: const Icon(Icons.edit_outlined),
        ),
      ],
    ),
    content: SizedBox(
      width: 880,
      child: FutureBuilder<Map<Object?, Object?>>(
        future: detail,
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
          final liveBusiness = Map<Object?, Object?>.from(
            data['business'] as Map? ?? const {},
          );
          final usage = Map<Object?, Object?>.from(
            data['usage'] as Map? ?? const {},
          );
          final recordGroups = Map<Object?, Object?>.from(
            data['records'] as Map? ?? const {},
          );
          final payments = (data['payments'] as List? ?? const [])
              .whereType<Map>()
              .map((item) => Map<Object?, Object?>.from(item))
              .take(5)
              .toList();
          final activity = (data['activity'] as List? ?? const [])
              .whereType<Map>()
              .map((item) => Map<Object?, Object?>.from(item))
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
                          DetailRow(
                            label: 'Tenant ID',
                            value: widget.business.id,
                          ),
                          DetailRow(
                            label: 'Chủ sở hữu',
                            value: liveBusiness['ownerName'].toString().ifEmpty(
                              'Chưa cập nhật',
                            ),
                          ),
                          DetailRow(
                            label: 'Điện thoại',
                            value: liveBusiness['ownerPhone']
                                .toString()
                                .ifEmpty(liveBusiness['phone'].toString())
                                .ifEmpty('Chưa cập nhật'),
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
                            value: liveBusiness['address'].toString().ifEmpty(
                              'Chưa cập nhật',
                            ),
                          ),
                          DetailRow(
                            label: 'Tỉnh thành',
                            value: liveBusiness['province'].toString().ifEmpty(
                              'Chưa cập nhật',
                            ),
                          ),
                          DetailRow(
                            label: 'Gói hiện tại',
                            value: _planLabel(
                              liveBusiness['planTier']?.toString() ?? 'basic',
                            ),
                          ),
                          DetailRow(
                            label: 'Hết hạn',
                            value: formatDate(
                              _millisDate(liveBusiness['planExpiresAt']),
                            ),
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
                  children: _usageKinds.map((kind) {
                    final selected = expandedKind == kind;
                    return FilterChip(
                      key: ValueKey('tenant-record-card-$kind'),
                      selected: selected,
                      showCheckmark: false,
                      avatar: Icon(
                        selected
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        size: 18,
                      ),
                      label: Text('${usageLabel(kind)}: ${usage[kind] ?? 0}'),
                      onSelected: (_) => setState(() {
                        expandedKind = selected ? null : kind;
                      }),
                    );
                  }).toList(),
                ),
                if (expandedKind != null) ...[
                  const SizedBox(height: 12),
                  _TenantRecordsPanel(
                    tenantId: widget.business.id,
                    kind: expandedKind!,
                    records: _recordList(recordGroups[expandedKind]),
                    allRecords: recordGroups,
                    api: widget.api,
                    onChanged: () {
                      reload();
                      widget.onChanged();
                    },
                  ),
                ],
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
                      trailing: StatusBadge(
                        status: payment['status']?.toString() ?? 'pending',
                      ),
                    ),
                const Divider(height: 28),
                _BusinessActivity(activity: activity),
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
      if (widget.business.status == 'suspended')
        FilledButton.tonal(
          onPressed: () => _confirmedAction(
            context,
            widget.api,
            'business.reactivate',
            widget.business.id,
            'Kích hoạt lại doanh nghiệp?',
            widget.onChanged,
          ),
          child: const Text('Kích hoạt lại'),
        )
      else
        FilledButton.tonal(
          onPressed: () => _confirmedAction(
            context,
            widget.api,
            'business.suspend',
            widget.business.id,
            'Tạm ngưng doanh nghiệp?',
            widget.onChanged,
          ),
          child: const Text('Tạm ngưng'),
        ),
    ],
  );

  Future<void> _editBusinessInfo(BuildContext context) async {
    final saved = await showAdminDialog<bool>(
      context: context,
      builder: (_) =>
          _BusinessInfoEditor(business: widget.business, api: widget.api),
    );
    if (saved == true) {
      reload();
      widget.onChanged();
    }
  }
}

const _usageKinds = [
  'bookings',
  'customers',
  'staff',
  'services',
  'products',
  'equipment',
];

DateTime? _millisDate(Object? value) =>
    value is num ? DateTime.fromMillisecondsSinceEpoch(value.toInt()) : null;

List<Map<Object?, Object?>> _recordList(Object? value) =>
    (value as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<Object?, Object?>.from(item))
        .toList(growable: false);

class _BusinessInfoEditor extends StatefulWidget {
  const _BusinessInfoEditor({required this.business, required this.api});

  final PlatformBusinessRecord business;
  final AdminApi api;

  @override
  State<_BusinessInfoEditor> createState() => _BusinessInfoEditorState();
}

class _BusinessInfoEditorState extends State<_BusinessInfoEditor> {
  final form = GlobalKey<FormState>();
  late final controllers = <String, TextEditingController>{
    'name': TextEditingController(text: widget.business.name),
    'ownerName': TextEditingController(text: widget.business.ownerName),
    'phone': TextEditingController(
      text: widget.business.ownerPhone.ifEmpty(widget.business.phone),
    ),
    'address': TextEditingController(text: widget.business.address),
    'province': TextEditingController(text: widget.business.province),
    'businessType': TextEditingController(text: widget.business.businessType),
  };
  bool loading = false;

  @override
  void dispose() {
    for (final controller in controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Chỉnh sửa thông tin doanh nghiệp'),
    content: SizedBox(
      width: 520,
      child: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final field in const [
              ('name', 'Tên doanh nghiệp'),
              ('ownerName', 'Chủ sở hữu'),
              ('phone', 'Điện thoại'),
              ('address', 'Địa chỉ'),
              ('province', 'Tỉnh thành'),
              ('businessType', 'Loại hình'),
            ]) ...[
              TextFormField(
                controller: controllers[field.$1],
                decoration: InputDecoration(labelText: field.$2),
                validator: _requiredField,
              ),
              const SizedBox(height: 10),
            ],
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
        onPressed: loading ? null : save,
        child: Text(loading ? 'Đang lưu...' : 'Lưu'),
      ),
    ],
  );

  Future<void> save() async {
    if (form.currentState?.validate() != true) return;
    setState(() => loading = true);
    try {
      await widget.api.performAction(
        action: 'business.update_info',
        resourceId: widget.business.id,
        payload: {
          for (final entry in controllers.entries)
            entry.key: entry.value.text.trim(),
        },
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) _showError(context, error);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }
}

class _TenantRecordsPanel extends StatelessWidget {
  const _TenantRecordsPanel({
    required this.tenantId,
    required this.kind,
    required this.records,
    required this.allRecords,
    required this.api,
    required this.onChanged,
  });

  final String tenantId;
  final String kind;
  final List<Map<Object?, Object?>> records;
  final Map<Object?, Object?> allRecords;
  final AdminApi api;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => Container(
    key: ValueKey('tenant-record-list-$kind'),
    decoration: BoxDecoration(
      color: AdminTheme.loadingBackground,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AdminTheme.border),
    ),
    padding: const EdgeInsets.all(12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Danh sách ${usageLabel(kind).toLowerCase()}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            FilledButton.icon(
              onPressed: () => edit(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Thêm'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (records.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Text(
              'Chưa có bản ghi.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AdminTheme.mutedInk),
            ),
          )
        else
          ...records.map(
            (record) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(
                _recordTitle(kind, record),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(_recordSubtitle(kind, record)),
              trailing: Wrap(
                spacing: 2,
                children: [
                  IconButton(
                    tooltip: 'Chỉnh sửa',
                    onPressed: () => edit(context, record),
                    icon: const Icon(Icons.edit_outlined, size: 19),
                  ),
                  IconButton(
                    tooltip: 'Xóa',
                    onPressed: () => remove(context, record),
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 19,
                      color: AdminTheme.danger,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );

  Future<void> edit(
    BuildContext context, [
    Map<Object?, Object?>? record,
  ]) async {
    final saved = await showAdminDialog<bool>(
      context: context,
      builder: (_) => _TenantRecordEditor(
        tenantId: tenantId,
        kind: kind,
        record: record,
        allRecords: allRecords,
        api: api,
      ),
    );
    if (saved == true) onChanged();
  }

  Future<void> remove(
    BuildContext context,
    Map<Object?, Object?> record,
  ) async {
    final confirmed = await showAdminDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xóa bản ghi?'),
        content: Text(_recordTitle(kind, record)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await api.performAction(
        action: 'record.delete',
        resourceId: record['id'].toString(),
        payload: {'tenantId': tenantId, 'kind': kind},
      );
      onChanged();
    } catch (error) {
      if (context.mounted) _showError(context, error);
    }
  }
}

class _TenantRecordEditor extends StatefulWidget {
  const _TenantRecordEditor({
    required this.tenantId,
    required this.kind,
    required this.record,
    required this.allRecords,
    required this.api,
  });

  final String tenantId;
  final String kind;
  final Map<Object?, Object?>? record;
  final Map<Object?, Object?> allRecords;
  final AdminApi api;

  @override
  State<_TenantRecordEditor> createState() => _TenantRecordEditorState();
}

class _TenantRecordEditorState extends State<_TenantRecordEditor> {
  final form = GlobalKey<FormState>();
  late final fields = _recordFields(widget.kind);
  late final controllers = {
    for (final field in fields)
      field.key: TextEditingController(
        text: _recordFieldValue(widget.record, field.key),
      ),
  };
  late bool isVip = widget.record?['isVip'] == true;
  bool loading = false;

  @override
  void dispose() {
    for (final controller in controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      '${widget.record == null ? 'Thêm' : 'Chỉnh sửa'} ${usageLabel(widget.kind).toLowerCase()}',
    ),
    content: SizedBox(
      width: 560,
      child: SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final field in fields) ...[
                if (field.key == 'isVip')
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(field.label),
                    value: isVip,
                    onChanged: (value) => setState(() => isVip = value),
                  )
                else if (field.reference != null)
                  _referenceField(field)
                else if (field.options != null)
                  DropdownButtonFormField<String>(
                    initialValue: _optionValue(field),
                    decoration: InputDecoration(labelText: field.label),
                    items: field.options!.entries
                        .map(
                          (entry) => DropdownMenuItem(
                            value: entry.key,
                            child: Text(entry.value),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) =>
                        controllers[field.key]!.text = value ?? '',
                    validator: field.required ? _requiredField : null,
                  )
                else
                  TextFormField(
                    controller: controllers[field.key],
                    decoration: InputDecoration(
                      labelText: field.label,
                      hintText: field.dateTime ? '2026-08-13T14:30' : null,
                    ),
                    keyboardType: field.numeric
                        ? TextInputType.number
                        : TextInputType.text,
                    maxLines: field.longText ? 3 : 1,
                    validator: field.required ? _requiredField : null,
                  ),
                const SizedBox(height: 10),
              ],
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
        onPressed: loading ? null : save,
        child: Text(loading ? 'Đang lưu...' : 'Lưu'),
      ),
    ],
  );

  Widget _referenceField(_RecordField field) {
    final options = _recordList(widget.allRecords[field.reference]);
    final ids = options.map((item) => item['id'].toString()).toSet();
    final current = controllers[field.key]!.text;
    return DropdownButtonFormField<String>(
      initialValue: ids.contains(current) ? current : null,
      decoration: InputDecoration(labelText: field.label),
      items: [
        if (!field.required)
          const DropdownMenuItem(value: '', child: Text('Không chọn')),
        ...options.map(
          (item) => DropdownMenuItem(
            value: item['id'].toString(),
            child: Text(_recordTitle(field.reference!, item)),
          ),
        ),
      ],
      onChanged: (value) => controllers[field.key]!.text = value ?? '',
      validator: field.required ? _requiredField : null,
    );
  }

  String? _optionValue(_RecordField field) {
    final value = controllers[field.key]!.text;
    if (field.options!.containsKey(value)) return value;
    final fallback = field.options!.keys.first;
    controllers[field.key]!.text = fallback;
    return fallback;
  }

  Future<void> save() async {
    if (form.currentState?.validate() != true) return;
    setState(() => loading = true);
    try {
      final payload = <String, Object?>{
        'tenantId': widget.tenantId,
        'kind': widget.kind,
      };
      for (final field in fields) {
        final value = controllers[field.key]?.text.trim() ?? '';
        payload[field.key] = field.key == 'isVip'
            ? isVip
            : field.numeric
            ? int.tryParse(value) ?? 0
            : field.list
            ? value
                  .split(',')
                  .map((item) => item.trim())
                  .where((item) => item.isNotEmpty)
                  .toList()
            : field.key == 'resourceIds'
            ? (value.isEmpty ? <String>[] : [value])
            : value;
      }
      final result = await widget.api.performAction(
        action: 'record.save',
        resourceId: widget.record?['id']?.toString() ?? 'new',
        payload: payload,
      );
      if (!mounted) return;
      final password = result['temporaryPassword']?.toString();
      if (password != null && password.isNotEmpty) {
        await showAdminDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Mật khẩu tạm thời'),
            content: SelectableText(password),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Đã lưu'),
              ),
            ],
          ),
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) _showError(context, error);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }
}

class _RecordField {
  const _RecordField(
    this.key,
    this.label, {
    this.required = true,
    this.numeric = false,
    this.longText = false,
    this.list = false,
    this.dateTime = false,
    this.options,
    this.reference,
  });

  final String key;
  final String label;
  final bool required;
  final bool numeric;
  final bool longText;
  final bool list;
  final bool dateTime;
  final Map<String, String>? options;
  final String? reference;
}

List<_RecordField> _recordFields(String kind) => switch (kind) {
  'bookings' => const [
    _RecordField('customerId', 'Khách hàng', reference: 'customers'),
    _RecordField('staffId', 'Nhân viên', reference: 'staff'),
    _RecordField('serviceId', 'Dịch vụ', reference: 'services'),
    _RecordField(
      'resourceIds',
      'Thiết bị (tùy chọn)',
      required: false,
      reference: 'equipment',
    ),
    _RecordField('startTime', 'Bắt đầu', dateTime: true),
    _RecordField('endTime', 'Kết thúc', dateTime: true),
    _RecordField(
      'status',
      'Trạng thái',
      options: {
        'pending': 'Chờ xác nhận',
        'confirmed': 'Đã xác nhận',
        'in_progress': 'Đang thực hiện',
        'completed': 'Hoàn thành',
        'cancelled': 'Đã hủy',
        'no_show': 'Không đến',
      },
    ),
    _RecordField('notes', 'Ghi chú', required: false, longText: true),
  ],
  'customers' => const [
    _RecordField('name', 'Tên khách hàng'),
    _RecordField('phone', 'Điện thoại'),
    _RecordField('email', 'Email', required: false),
    _RecordField('birthday', 'Ngày sinh', required: false),
    _RecordField('notes', 'Ghi chú', required: false, longText: true),
    _RecordField(
      'allergies',
      'Dị ứng / lưu ý',
      required: false,
      longText: true,
    ),
    _RecordField('visitCount', 'Số lần ghé', numeric: true),
    _RecordField('isVip', 'Khách VIP', required: false),
  ],
  'staff' => const [
    _RecordField('name', 'Tên nhân viên'),
    _RecordField('phone', 'Điện thoại'),
    _RecordField('email', 'Email'),
    _RecordField('roleTitle', 'Chức danh'),
    _RecordField(
      'specialties',
      'Chuyên môn (phân cách bằng dấu phẩy)',
      required: false,
      list: true,
    ),
    _RecordField(
      'status',
      'Trạng thái',
      options: {
        'available': 'Sẵn sàng',
        'in_session': 'Trong phiên',
        'absent': 'Vắng mặt',
      },
    ),
  ],
  'services' => const [
    _RecordField('name', 'Tên dịch vụ'),
    _RecordField('category', 'Danh mục'),
    _RecordField('price', 'Giá', numeric: true),
    _RecordField('duration', 'Thời lượng (phút)', numeric: true),
  ],
  'products' => const [
    _RecordField('name', 'Tên sản phẩm'),
    _RecordField('category', 'Danh mục'),
    _RecordField('price', 'Giá', numeric: true),
    _RecordField('unit', 'Đơn vị'),
  ],
  'equipment' => const [
    _RecordField('name', 'Tên thiết bị'),
    _RecordField('location', 'Vị trí', required: false),
    _RecordField('quantity', 'Số lượng', numeric: true),
    _RecordField('lastMaintenance', 'Bảo trì gần nhất', required: false),
    _RecordField(
      'status',
      'Trạng thái',
      options: {
        'available': 'Sẵn sàng',
        'in_use': 'Đang sử dụng',
        'maintenance': 'Bảo trì',
      },
    ),
  ],
  _ => const [],
};

String _recordFieldValue(Map<Object?, Object?>? record, String key) {
  final value = record == null
      ? null
      : key == 'roleTitle'
      ? record['role_title']
      : record[key];
  if (key == 'resourceIds' && value is List) {
    return value.isEmpty ? '' : value.first.toString();
  }
  if (value is List) return value.join(', ');
  if ((key == 'startTime' || key == 'endTime') && value is num) {
    final date = DateTime.fromMillisecondsSinceEpoch(value.toInt());
    String two(int part) => part.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)}T${two(date.hour)}:${two(date.minute)}';
  }
  return value?.toString() ?? '';
}

String? _requiredField(String? value) =>
    value == null || value.trim().isEmpty ? 'Vui lòng nhập trường này' : null;

String _recordTitle(
  String kind,
  Map<Object?, Object?> record,
) => switch (kind) {
  'bookings' =>
    '${record['customerName'] ?? 'Lịch hẹn'} · ${record['serviceName'] ?? ''}',
  _ => record['name']?.toString().ifEmpty('Chưa đặt tên') ?? 'Chưa đặt tên',
};

String _recordSubtitle(
  String kind,
  Map<Object?, Object?> record,
) => switch (kind) {
  'bookings' =>
    '${formatDateTime(_millisDate(record['startTime']))} · ${record['staffName'] ?? ''} · ${_statusLabel(record['status'])}',
  'customers' =>
    '${record['phone'] ?? ''}${record['isVip'] == true ? ' · VIP' : ''}',
  'staff' =>
    '${record['role_title'] ?? 'Nhân viên'} · ${_statusLabel(record['status'])}',
  'services' =>
    '${_money.format(record['price'] ?? 0)} · ${record['duration'] ?? record['durationMin'] ?? 0} phút',
  'products' =>
    '${_money.format(record['price'] ?? 0)} · ${record['unit'] ?? ''}',
  'equipment' =>
    '${record['location'] ?? ''} · ${_statusLabel(record['status'])} · SL ${record['quantity'] ?? 1}',
  _ => '',
};

String _statusLabel(Object? value) => switch (value?.toString()) {
  'pending' => 'Chờ xác nhận',
  'confirmed' => 'Đã xác nhận',
  'in_progress' => 'Đang thực hiện',
  'completed' => 'Hoàn thành',
  'cancelled' => 'Đã hủy',
  'no_show' => 'Không đến',
  'available' => 'Sẵn sàng',
  'in_use' => 'Đang sử dụng',
  'in_session' => 'Trong phiên',
  'maintenance' => 'Bảo trì',
  'absent' => 'Vắng mặt',
  _ => value?.toString() ?? '',
};

class _BusinessActivity extends StatefulWidget {
  const _BusinessActivity({required this.activity});

  final List<Map<Object?, Object?>> activity;

  @override
  State<_BusinessActivity> createState() => _BusinessActivityState();
}

class _BusinessActivityState extends State<_BusinessActivity> {
  static const ranges = [1, 3, 7, 15, 30];
  int days = 30;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final cutoff = DateTime(
      today.year,
      today.month,
      today.day,
    ).subtract(Duration(days: days - 1));
    final activity = widget.activity.where((event) {
      final createdAt = _activityDate(event['createdAt']);
      return createdAt != null && !createdAt.isBefore(cutoff);
    }).toList();
    final activityByDay = <String, num>{};
    for (var offset = 0; offset < days; offset++) {
      final date = cutoff.add(Duration(days: offset));
      activityByDay[_activityDateKey(date)] = 0;
    }
    for (final event in activity) {
      final createdAt = _activityDate(event['createdAt']);
      if (createdAt == null) continue;
      final key = _activityDateKey(createdAt);
      activityByDay[key] = (activityByDay[key] ?? 0) + 1;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Hoạt động gần đây',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const Text(
              'Khoảng ngày',
              style: TextStyle(color: AdminTheme.mutedInk, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          children: ranges
              .map(
                (value) => ChoiceChip(
                  label: Text('$value ngày'),
                  selected: days == value,
                  onSelected: (_) => setState(() => days = value),
                ),
              )
              .toList(growable: false),
        ),
        const SizedBox(height: 16),
        _DailyTrendChart(
          key: ValueKey('business-activity-trend-$days'),
          title: 'Mức độ sử dụng theo ngày',
          tooltip:
              'Số thao tác được ghi nhận theo từng ngày trong khoảng đã chọn.',
          values: activityByDay,
          emptyMessage: 'Chưa có hoạt động trong khoảng đã chọn.',
        ),
        const SizedBox(height: 12),
        Text(
          '${activity.length} hoạt động thêm, chỉnh sửa hoặc xóa trong $days ngày gần nhất.',
          style: const TextStyle(color: AdminTheme.mutedInk),
        ),
        const SizedBox(height: 8),
        if (activity.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Chưa có hoạt động trong khoảng đã chọn.',
              style: TextStyle(color: AdminTheme.mutedInk),
            ),
          )
        else
          ...activity.map(
            (event) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(
                _activityIcon(event['action']),
                size: 18,
                color: AdminTheme.tealDark,
              ),
              title: Text(
                '${_activityAction(event['action'])} · ${_activityEntity(event['type'])}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(formatDateTime(_activityDate(event['createdAt']))),
              trailing: StatusBadge(
                status: event['status']?.toString() ?? 'succeeded',
              ),
            ),
          ),
      ],
    );
  }
}

DateTime? _activityDate(Object? value) =>
    value is num ? DateTime.fromMillisecondsSinceEpoch(value.toInt()) : null;

String _activityDateKey(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

String _activityAction(Object? value) {
  final action = value?.toString().toLowerCase() ?? '';
  if (action.contains('delete')) return 'Xóa';
  if (action.contains('create') || action.contains('add')) return 'Thêm';
  return 'Chỉnh sửa';
}

IconData _activityIcon(Object? value) => switch (_activityAction(value)) {
  'Thêm' => Icons.add_circle_outline,
  'Xóa' => Icons.delete_outline,
  _ => Icons.edit_outlined,
};

String _activityEntity(Object? value) =>
    const {
      'booking': 'Lịch hẹn',
      'customer': 'Khách hàng',
      'user': 'Nhân viên',
      'service': 'Dịch vụ',
      'product': 'Sản phẩm',
      'equipment': 'Thiết bị',
      'tenant': 'Doanh nghiệp',
      'campaign': 'Chiến dịch',
    }[value?.toString()] ??
    'Hệ thống';

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
              value: '${_planLabel(item.planTier)} ${item.billingPeriod}',
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
    required this.tooltip,
    required this.child,
    this.rightTitle,
    this.rightTooltip,
  });

  final String title;
  final String tooltip;
  final Widget child;
  final String? rightTitle;
  final String? rightTooltip;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (rightTitle != null && constraints.maxWidth >= 900)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: _InfoTitle(title: title, tooltip: tooltip),
                  ),
                  const SizedBox(width: 32),
                  Expanded(
                    flex: 3,
                    child: _InfoTitle(
                      title: rightTitle!,
                      tooltip: rightTooltip ?? '',
                    ),
                  ),
                ],
              )
            else
              _InfoTitle(title: title, tooltip: tooltip),
            const SizedBox(height: 24),
            child,
          ],
        ),
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

enum _MetricTone { neutral, success, warning, danger }

class _RelationshipGrid extends StatelessWidget {
  const _RelationshipGrid({
    required this.items,
    this.selectedIndex,
    this.selectableIndices = const {},
    this.onSelected,
  });

  final List<(String, String, String, _MetricTone)> items;
  final int? selectedIndex;
  final Set<int> selectableIndices;
  final ValueChanged<int>? onSelected;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 420 ? 2 : 1;
      final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: items.indexed
            .map(
              (entry) => SizedBox(
                width: width,
                child: _RelationshipMetric(
                  selected: selectedIndex == entry.$1,
                  onTap: selectableIndices.contains(entry.$1)
                      ? () => onSelected?.call(entry.$1)
                      : null,
                  label: entry.$2.$1,
                  value: entry.$2.$2,
                  tooltip: entry.$2.$3,
                  tone: entry.$2.$4,
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
    required this.tone,
    this.selected = false,
    this.onTap,
  });

  final String label;
  final String value;
  final String tooltip;
  final _MetricTone tone;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      _MetricTone.success => AdminTheme.success,
      _MetricTone.warning => AdminTheme.orange,
      _MetricTone.danger => AdminTheme.danger,
      _MetricTone.neutral => AdminTheme.tealDark,
    };
    final card = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        mouseCursor: onTap == null
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        child: Container(
          key: ValueKey('metric-card-$label'),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.055),
            border: Border.all(
              color: color.withValues(alpha: selected ? 0.7 : 0.14),
              width: selected ? 2 : 1,
            ),
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
                    color: tone == _MetricTone.neutral ? null : color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 250),
      child: card,
    );
  }
}

class _DailyTrendChart extends StatelessWidget {
  const _DailyTrendChart({
    required this.title,
    required this.tooltip,
    required this.values,
    required this.emptyMessage,
    this.money = false,
    this.percent = false,
    this.color = AdminTheme.teal,
    this.showTitle = true,
    super.key,
  });

  final String title;
  final String tooltip;
  final Map<String, num> values;
  final String emptyMessage;
  final bool money;
  final bool percent;
  final Color color;
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    final entries = values.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final visible = entries;
    final max = visible.fold<double>(
      0,
      (current, entry) =>
          entry.value > current ? entry.value.toDouble() : current,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showTitle) ...[
          _InfoTitle(title: title, tooltip: tooltip),
          const SizedBox(height: 18),
        ],
        if (visible.isEmpty || max <= 0)
          SizedBox(
            height: 190,
            child: Center(
              child: Text(
                emptyMessage,
                style: const TextStyle(color: AdminTheme.mutedInk),
              ),
            ),
          )
        else
          Container(
            key: ValueKey('trend-chart-body-$title'),
            height: 190,
            padding: const EdgeInsets.fromLTRB(10, 14, 10, 8),
            decoration: BoxDecoration(
              color: AdminTheme.teal.withValues(alpha: 0.035),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(
                  key: const ValueKey('trend-line'),
                  painter: _TrendLinePainter(
                    values: visible
                        .map((entry) => entry.value.toDouble())
                        .toList(growable: false),
                    maxValue: percent ? 100 : max,
                    color: color,
                  ),
                ),
                Row(
                  children: visible
                      .map(
                        (entry) => Expanded(
                          child: Tooltip(
                            message:
                                '${entry.key}\n${money ? _money.format(entry.value) : '${entry.value}${percent ? '%' : ''}'}',
                            waitDuration: const Duration(milliseconds: 150),
                            child: SizedBox.expand(
                              key: ValueKey('trend-point-${entry.key}'),
                            ),
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
              ],
            ),
          ),
        if (visible.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _shortDate(visible.first.key),
                style: const TextStyle(fontSize: 10),
              ),
              Text(
                _shortDate(visible.last.key),
                style: const TextStyle(fontSize: 10),
              ),
            ],
          ),
        ],
      ],
    );
  }

  String _shortDate(String value) {
    final parts = value.split('-');
    return parts.length == 3 ? '${parts[2]}/${parts[1]}' : value;
  }
}

class _TrendLinePainter extends CustomPainter {
  const _TrendLinePainter({
    required this.values,
    required this.maxValue,
    required this.color,
  });

  final List<double> values;
  final double maxValue;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = AdminTheme.mutedInk.withValues(alpha: 0.12)
      ..strokeWidth = 1;
    for (var index = 0; index < 4; index++) {
      final y = size.height * index / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final usableHeight = size.height - 8;
    final step = values.length == 1 ? 0.0 : size.width / (values.length - 1);
    final points = values.indexed
        .map(
          (entry) => Offset(
            values.length == 1 ? size.width / 2 : entry.$1 * step,
            4 + usableHeight * (1 - (entry.$2 / maxValue).clamp(0, 1)),
          ),
        )
        .toList(growable: false);
    final line = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      line.lineTo(point.dx, point.dy);
    }
    final area = Path.from(line)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.02)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );
    for (final point in points) {
      canvas.drawCircle(point, 4.5, Paint()..color = Colors.white);
      canvas.drawCircle(point, 3, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_TrendLinePainter oldDelegate) =>
      oldDelegate.values != values ||
      oldDelegate.maxValue != maxValue ||
      oldDelegate.color != color;
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
              values: {
                for (final item in data.analytics.revenueByPlan.entries)
                  _planLabel(item.key): item.value,
              },
              money: true,
              highlight: true,
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
      'active' || 'paid' || 'verified' || 'succeeded' => AdminTheme.success,
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
  const EventTable({required this.events, super.key});
  final List<PlatformEvent> events;
  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return EmptyState(
        icon: Icons.policy_outlined,
        title: 'Chưa có thao tác kiểm toán',
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
                  DataCell(Text(event.actor.ifEmpty('Hệ thống'))),
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
                  _planLabel(plan.id),
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

class _HealthCard extends StatelessWidget {
  const _HealthCard({required this.label, required this.detail});
  final String label;
  final String detail;
  @override
  Widget build(BuildContext context) {
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
                decoration: const BoxDecoration(
                  color: AdminTheme.success,
                  shape: BoxShape.circle,
                ),
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
                  (item) => DropdownMenuItem(
                    value: item.id,
                    child: Text(_planLabel(item.id)),
                  ),
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
        _planLabel(row.planTier),
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
            row.ownerPhone.ifEmpty(row.phone),
            row.businessType,
            row.province,
            _planLabel(row.planTier),
            row.subscriptionStatus,
            row.status,
            row.createdAt?.toIso8601String() ?? '',
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
      'succeeded': 'Thành công',
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
