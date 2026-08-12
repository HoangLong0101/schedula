import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'admin_services.dart';
import 'admin_theme.dart';
import 'platform_workspace.dart';
import 'workspace_pages.dart';

enum AdminSection {
  dashboard,
  businesses,
  transactions,
  subscriptions,
  revenue,
  provinces,
  plans,
  monitoring,
  reports,
  admins,
  settings,
}

class AdminDestination {
  const AdminDestination(this.section, this.label, this.icon, this.permission);

  final AdminSection section;
  final String label;
  final IconData icon;
  final String? permission;
}

const adminDestinations = [
  AdminDestination(
    AdminSection.dashboard,
    'Tổng quan',
    Icons.grid_view_outlined,
    'dashboard.read',
  ),
  AdminDestination(
    AdminSection.businesses,
    'Doanh nghiệp',
    Icons.domain_outlined,
    'business.read',
  ),
  AdminDestination(
    AdminSection.transactions,
    'Giao dịch',
    Icons.receipt_long_outlined,
    'transaction.read',
  ),
  AdminDestination(
    AdminSection.subscriptions,
    'Gói đăng ký',
    Icons.autorenew_outlined,
    'business.read',
  ),
  AdminDestination(
    AdminSection.revenue,
    'Doanh thu',
    Icons.query_stats_outlined,
    'analytics.read',
  ),
  AdminDestination(
    AdminSection.provinces,
    'Tỉnh thành',
    Icons.map_outlined,
    'analytics.read',
  ),
  AdminDestination(
    AdminSection.plans,
    'Bảng giá SaaS',
    Icons.sell_outlined,
    'plan.write',
  ),
  AdminDestination(
    AdminSection.monitoring,
    'Vận hành',
    Icons.monitor_heart_outlined,
    'monitoring.read',
  ),
  AdminDestination(
    AdminSection.reports,
    'Báo cáo',
    Icons.summarize_outlined,
    'report.export',
  ),
  AdminDestination(
    AdminSection.admins,
    'Quản trị viên',
    Icons.admin_panel_settings_outlined,
    'admin.write',
  ),
  AdminDestination(AdminSection.settings, 'Cài đặt', Icons.tune_outlined, null),
];

class AdminShell extends StatefulWidget {
  const AdminShell({
    required this.user,
    required this.auth,
    required this.api,
    super.key,
  });

  final User user;
  final AdminAuthService auth;
  final AdminApi api;

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  AdminSection selected = AdminSection.dashboard;
  WorkspaceFilter filter = WorkspaceFilter.last30Days();
  late Future<PlatformWorkspace> workspace = widget.api.getWorkspace(filter);

  void refresh() => setState(() => workspace = widget.api.getWorkspace(filter));

  void updateFilter(WorkspaceFilter value) {
    filter = value;
    refresh();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PlatformWorkspace>(
      future: workspace,
      builder: (context, snapshot) {
        final actor = snapshot.data?.actor;
        final visible = adminDestinations
            .where(
              (item) =>
                  item.permission == null ||
                  actor?.can(item.permission!) != false,
            )
            .toList(growable: false);
        if (!visible.any((item) => item.section == selected)) {
          selected = AdminSection.dashboard;
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            final desktop = constraints.maxWidth >= 980;
            final navigation = _SideNavigation(
              items: visible,
              selected: selected,
              onSelected: (value) => setState(() => selected = value),
              user: widget.user,
              role: actor?.role ?? 'platform_admin',
            );
            return Scaffold(
              drawer: desktop
                  ? null
                  : Drawer(child: SafeArea(child: navigation)),
              body: Row(
                children: [
                  if (desktop) SizedBox(width: 256, child: navigation),
                  Expanded(
                    child: WorkspacePage(
                      section: selected,
                      snapshot: snapshot,
                      filter: filter,
                      api: widget.api,
                      auth: widget.auth,
                      user: widget.user,
                      onFilterChanged: updateFilter,
                      onRefresh: refresh,
                      showMenu: !desktop,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _SideNavigation extends StatelessWidget {
  const _SideNavigation({
    required this.items,
    required this.selected,
    required this.onSelected,
    required this.user,
    required this.role,
  });

  final List<AdminDestination> items;
  final AdminSection selected;
  final ValueChanged<AdminSection> onSelected;
  final User user;
  final String role;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AdminTheme.surface,
        border: Border(right: BorderSide(color: AdminTheme.strongBorder)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 20, 14, 18),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  Image.asset(
                    'assets/Icon.png',
                    width: 36,
                    height: 36,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Schedula',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final active = item.section == selected;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: ListTile(
                      selected: active,
                      selectedColor: AdminTheme.tealDark,
                      selectedTileColor: AdminTheme.teal.withValues(alpha: 0.1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      leading: Icon(item.icon, size: 20),
                      title: Text(
                        item.label,
                        style: TextStyle(
                          fontWeight: active
                              ? FontWeight.w700
                              : FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                      onTap: () {
                        onSelected(item.section);
                        if (Scaffold.maybeOf(context)?.hasDrawer == true) {
                          Navigator.maybePop(context);
                        }
                      },
                    ),
                  );
                },
              ),
            ),
            const Divider(),
            Tooltip(
              message:
                  'Phiên đăng nhập đang hoạt động\n${user.email ?? 'Quản trị viên'}\n${roleLabel(role)}',
              waitDuration: const Duration(milliseconds: 250),
              child: ListTile(
                dense: true,
                leading: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const CircleAvatar(
                      radius: 18,
                      backgroundColor: AdminTheme.tealDark,
                      child: Icon(
                        Icons.person_outline,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    Positioned(
                      right: -1,
                      bottom: -1,
                      child: Container(
                        width: 11,
                        height: 11,
                        decoration: BoxDecoration(
                          color: AdminTheme.success,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AdminTheme.surface,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                title: Text(
                  user.email ?? 'Quản trị viên',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                subtitle: Text(
                  roleLabel(role),
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String roleLabel(String role) => switch (role) {
  'super_admin' => 'Quản trị cấp cao',
  'finance_admin' => 'Quản trị tài chính',
  'support_admin' => 'Quản trị hỗ trợ',
  'sales_admin' => 'Quản trị kinh doanh',
  'analyst' => 'Chuyên viên phân tích',
  _ => 'Quản trị hệ thống',
};

class PageFrame extends StatelessWidget {
  const PageFrame({
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
    super.key,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1220),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.headlineLarge,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          subtitle,
                          style: const TextStyle(color: AdminTheme.mutedInk),
                        ),
                      ],
                    ),
                  ),
                  ?trailing,
                ],
              ),
              const SizedBox(height: 28),
              child,
            ],
          ),
        ),
      ),
    ),
  );
}

class DetailRow extends StatelessWidget {
  const DetailRow({required this.label, required this.value, super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 138,
          child: Text(
            label,
            style: const TextStyle(color: AdminTheme.mutedInk),
          ),
        ),
        Expanded(
          child: SelectableText(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}
