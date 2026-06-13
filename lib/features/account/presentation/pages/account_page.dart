import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../dashboard/presentation/cubit/dashboard_cubit.dart';
import '../../../dashboard/presentation/cubit/dashboard_state.dart';
import '../../domain/entities/business_info.dart';
import '../cubit/account_cubit.dart';

// Import các trang con (nhớ kiểm tra lại đường dẫn import cho khớp cấu trúc dự án của bạn)
import './account_info_page.dart';
import '../../../staff/presentation/pages/staff_page.dart';
import '../../../customer/presentation/pages/customer_page.dart';
import '../../../equipment/presentation/pages/equipment_page.dart';

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  static const routePath = '/account';

  @override
  Widget build(BuildContext context) {
    // Trích xuất tenantId từ AuthBloc
    final authState = context.read<AuthBloc>().state;
    final tenantId = authState is Authenticated ? authState.user.tenantId : '';

    if (tenantId.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('Lỗi: Không tìm thấy mã cơ sở (Tenant ID)')),
      );
    }

    return MultiBlocProvider(
      providers: [
        BlocProvider(
          // Dùng GetIt để tiêm UseCases và gọi hàm init(tenantId)
          create: (_) => getIt<AccountCubit>()..init(tenantId),
        ),
        BlocProvider(create: (_) => getIt<DashboardCubit>()..load(tenantId)),
      ],
      child: const _AccountView(),
    );
  }
}

class _AccountView extends StatelessWidget {
  const _AccountView();

  static const _tealColor = Color(0xFF148a9c);
  static const _tealGradient = LinearGradient(
    colors: [Color(0xFF22AFC2), Color(0xFF148a9c)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static String _planLabel(String planTier) {
    return switch (planTier.toLowerCase()) {
      'basic' => 'Gói Cơ bản',
      'professional' || 'pro' => 'Gói Chuyên Nghiệp',
      'premium' => 'Gói Cao cấp',
      _ => 'Gói ${planTier.toUpperCase()}',
    };
  }

  static String _formatDate(DateTime? date) {
    if (date == null) {
      return 'Chưa có';
    }

    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    // Lấy thông tin User thực tế từ AuthBloc
    final authState = context.watch<AuthBloc>().state;
    final userName = authState is Authenticated
        ? authState.user.email.split('@')[0]
        : 'Người dùng';
    final userEmail = authState is Authenticated ? authState.user.email : '';
    final initial = userName.isNotEmpty ? userName[0].toUpperCase() : 'U';

    return Scaffold(
      backgroundColor: const Color(0xFFFCFCFD), // Nền chuẩn của app
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(
            bottom: 120,
          ), // Tránh bị lấp bởi Global Navbar
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Row(
                  children: [
                    const SizedBox(width: 36),
                    const Expanded(
                      child: Text(
                        'Tài Khoản',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),
                    const SizedBox(width: 36),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: BlocBuilder<AccountCubit, BusinessInfo>(
                  builder: (context, business) {
                    final planLabel = _planLabel(business.planTier);

                    return Column(
                      children: [
                        // Profile Card
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: _tealGradient,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 64,
                                    height: 64,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.2,
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      initial,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          userName,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        Text(
                                          userEmail,
                                          style: TextStyle(
                                            color: Colors.white.withValues(
                                              alpha: 0.8,
                                            ),
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.workspace_premium,
                                              color: Color(0xFFFDE047),
                                              size: 14,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              planLabel,
                                              style: const TextStyle(
                                                color: Color(0xFFFDE047),
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Container(
                                height: 1,
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                              const SizedBox(height: 16),
                              BlocBuilder<DashboardCubit, DashboardState>(
                                builder: (context, state) {
                                  final totalBookings = state is DashboardLoaded
                                      ? state.stats.totalBookings.toString()
                                      : '...';
                                  final totalCustomers =
                                      state is DashboardLoaded
                                      ? state
                                            .stats
                                            .customerOverview
                                            .totalCustomers
                                            .toString()
                                      : '...';

                                  return Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceAround,
                                    children: [
                                      _StatItem(
                                        value: totalBookings,
                                        label: 'Lịch hẹn',
                                      ),
                                      _StatItem(
                                        value: totalCustomers,
                                        label: 'Khách hàng',
                                      ),
                                      const _StatItem(
                                        value: '-',
                                        label: 'Đánh giá',
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Subscription Status
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade100),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        planLabel,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Hết hạn: ${_formatDate(business.planExpiresAt)}',
                                        style: TextStyle(
                                          color: Colors.grey.shade500,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF8B5CF6),
                                          Color(0xFF7C3AED),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text(
                                      'Quản lý',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              BlocBuilder<DashboardCubit, DashboardState>(
                                builder: (context, state) {
                                  final usedBookings = state is DashboardLoaded
                                      ? state.stats.totalBookings.toString()
                                      : '...';

                                  return Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Lịch hẹn đã dùng tháng này',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      Text(
                                        '$usedBookings/∞',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: _tealColor,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(99),
                                child: LinearProgressIndicator(
                                  value: 0,
                                  backgroundColor: Colors.grey.shade100,
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                        _tealColor,
                                      ),
                                  minHeight: 8,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Business Info Card
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade100),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  14,
                                  16,
                                  14,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: _tealColor.withValues(
                                              alpha: 0.1,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.domain,
                                            color: _tealColor,
                                            size: 16,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        const Text(
                                          'Thông tin doanh nghiệp',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                    IconButton(
                                      onPressed: () => _showEditBusinessSheet(
                                        context,
                                        business,
                                      ),
                                      icon: const Icon(
                                        Icons.edit_outlined,
                                        size: 18,
                                        color: Colors.grey,
                                      ),
                                      style: IconButton.styleFrom(
                                        backgroundColor: Colors.grey.shade50,
                                      ),
                                      constraints: const BoxConstraints(
                                        minWidth: 32,
                                        minHeight: 32,
                                      ),
                                      padding: EdgeInsets.zero,
                                    ),
                                  ],
                                ),
                              ),
                              Divider(height: 1, color: Colors.grey.shade100),
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _InfoRow(
                                      icon: Icons.business,
                                      label: 'Tên doanh nghiệp',
                                      value: business.name,
                                    ),
                                    const SizedBox(height: 12),
                                    _InfoRow(
                                      icon: Icons.location_on_outlined,
                                      label: 'Địa chỉ',
                                      value: business.address,
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _InfoRow(
                                            icon: Icons.phone_outlined,
                                            label: 'Điện thoại',
                                            value: business.phone,
                                          ),
                                        ),
                                        Expanded(
                                          child: _InfoRow(
                                            icon: Icons.language,
                                            label: 'Website',
                                            value: business.website,
                                            valueColor: _tealColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    _InfoRow(
                                      icon: Icons.access_time,
                                      label: 'Giờ hoạt động',
                                      value:
                                          'T2–T6: ${business.hoursWeekday}\nT7–CN: ${business.hoursWeekend}',
                                    ),
                                    const SizedBox(height: 16),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: _tealGradient,
                                        borderRadius: BorderRadius.circular(99),
                                      ),
                                      child: Text(
                                        business.type,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        _MenuSection(
                          title: 'Cài đặt Tổng quan & Bảo mật',
                          items: [
                            _MenuItem(
                              icon: Icons.person_outline,
                              label: 'Thông tin tài khoản & Bảo mật',
                              hint: 'Hồ sơ, mật khẩu, FaceID/Vân tay, 2FA',
                              color: const Color(0xFF148a9c),
                              onTap: () =>
                                  context.push(AccountInfoPage.routePath),
                            ),
                            _MenuItem(
                              icon: Icons.keyboard_alt_outlined,
                              label: 'Phím tắt & Trợ giúp',
                              hint: 'Phím tắt PC/Tablet, hướng dẫn nhanh',
                              color: const Color(0xFF8b5cf6),
                            ),
                          ],
                        ),
                        _MenuSection(
                          title: 'Quản lý',
                          items: [
                            _MenuItem(
                              icon: Icons.people_outline,
                              label: 'Quản lý nhân viên',
                              color: const Color(0xFF148a9c),
                              onTap: () => context.push(StaffPage.routePath),
                            ),
                            _MenuItem(
                              icon: Icons.account_circle_outlined,
                              label: 'Quản lý khách hàng',
                              color: const Color(0xFF14b8a6),
                              onTap: () => context.push(CustomerPage.routePath),
                            ),
                            _MenuItem(
                              icon: Icons.inventory_2_outlined,
                              label: 'Quản lý thiết bị',
                              color: const Color(0xFF22AFC2),
                              onTap: () =>
                                  context.push(EquipmentPage.routePath),
                            ),
                            _MenuItem(
                              icon: Icons.grid_view,
                              label: 'Danh mục SP & Dịch vụ',
                              color: const Color(0xFF8b5cf6),
                              onTap: () =>
                                  context.push('/catalog'), // <-- Thêm dòng này
                            ),
                            _MenuItem(
                              icon: Icons.auto_awesome,
                              label: 'Trợ lý AI Schedula',
                              color: const Color(0xFFf97316),
                              isNew: true,
                            ),
                          ],
                        ),
                        _MenuSection(
                          title: 'Cài đặt hệ thống',
                          items: [
                            _MenuItem(
                              icon: Icons.edit_calendar_outlined,
                              label: 'Quy tắc đặt lịch',
                              color: const Color(0xFF22AFC2),
                            ),
                            _MenuItem(
                              icon: Icons.admin_panel_settings_outlined,
                              label: 'Phân quyền truy cập',
                              color: const Color(0xFF148a9c),
                            ),
                            _MenuItem(
                              icon: Icons.notifications_outlined,
                              label: 'Thông báo & Âm thanh',
                              color: const Color(0xFFf97316),
                            ),
                            _MenuItem(
                              icon: Icons.message_outlined,
                              label: 'SMS / Zalo ZNS',
                              color: const Color(0xFF3b82f6),
                            ),
                          ],
                        ),
                        _MenuSection(
                          title: 'Thanh toán',
                          items: [
                            _MenuItem(
                              icon: Icons.credit_card_outlined,
                              label: 'Quản lý thanh toán',
                              color: const Color(0xFF14b8a6),
                            ),
                            _MenuItem(
                              icon: Icons.workspace_premium_outlined,
                              label: 'Nâng cấp gói dịch vụ',
                              color: const Color(0xFFeab308),
                            ),
                            _MenuItem(
                              icon: Icons.star_outline,
                              label: 'Lịch sử giao dịch',
                              color: const Color(0xFFec4899),
                            ),
                          ],
                        ),
                        _MenuSection(
                          title: 'Hỗ trợ',
                          items: [
                            _MenuItem(
                              icon: Icons.logout,
                              label: 'Đăng xuất',
                              color: const Color(0xFFef4444),
                              isDestructive: true,
                              onTap: () {
                                context.read<AuthBloc>().add(
                                  const AuthSignOutRequested(),
                                );
                              },
                            ),
                          ],
                        ),

                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                            'Schedula v1.0.0 · © 2026 Schedula Inc.',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditBusinessSheet(BuildContext context, BusinessInfo currentInfo) {
    // Trích xuất Cubit hiện tại để pass vào BottomSheet (vì BottomSheet nằm ngoài widget tree hiện tại)
    final cubit = context.read<AccountCubit>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EditBusinessSheet(
        initialInfo: currentInfo,
        onSave: (newInfo) {
          cubit.updateBusinessInfo(newInfo);
          Navigator.pop(context);
        },
      ),
    );
  }
}

// CÁC WIDGET PHỤ TRỢ (HELPER WIDGETS)

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  const _StatItem({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade400),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  color: valueColor ?? Colors.grey.shade800,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MenuSection extends StatelessWidget {
  final String title;
  final List<_MenuItem> items;
  const _MenuSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 8, top: 8),
          child: Text(
            title,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Column(
            children: items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return Column(
                children: [
                  item,
                  if (index != items.length - 1)
                    Divider(height: 1, indent: 56, color: Colors.grey.shade100),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? hint;
  final Color color;
  final bool isNew;
  final bool isDestructive;
  final VoidCallback? onTap;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.color,
    this.hint,
    this.isNew = false,
    this.isDestructive = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap ?? () {},
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDestructive
                              ? Colors.red
                              : Colors.grey.shade800,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (isNew) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF22AFC2), Color(0xFF148a9c)],
                            ),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: const Text(
                            'MỚI',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (hint != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      hint!,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 20, color: Colors.grey.shade300),
          ],
        ),
      ),
    );
  }
}

// WIDGET BOTTOM SHEET CHỈNH SỬA DOANH NGHIỆP
class _EditBusinessSheet extends StatefulWidget {
  final BusinessInfo initialInfo;
  final Function(BusinessInfo) onSave;

  const _EditBusinessSheet({required this.initialInfo, required this.onSave});

  @override
  State<_EditBusinessSheet> createState() => _EditBusinessSheetState();
}

class _EditBusinessSheetState extends State<_EditBusinessSheet> {
  late TextEditingController nameCtrl;
  late TextEditingController addressCtrl;
  late TextEditingController phoneCtrl;
  late TextEditingController websiteCtrl;
  late TextEditingController hWeekdayCtrl;
  late TextEditingController hWeekendCtrl;
  late TextEditingController descCtrl;
  String selectedType = '';

  final List<String> businessTypes = [
    "Spa & Làm đẹp",
    "Phòng khám da liễu",
    "Salon tóc",
    "Nail & Thẩm mỹ",
    "Massage & Thư giãn",
    "Phòng khám đa khoa",
    "Yoga & Fitness",
    "Khác",
  ];

  @override
  void initState() {
    super.initState();
    nameCtrl = TextEditingController(text: widget.initialInfo.name);
    addressCtrl = TextEditingController(text: widget.initialInfo.address);
    phoneCtrl = TextEditingController(text: widget.initialInfo.phone);
    websiteCtrl = TextEditingController(text: widget.initialInfo.website);
    hWeekdayCtrl = TextEditingController(text: widget.initialInfo.hoursWeekday);
    hWeekendCtrl = TextEditingController(text: widget.initialInfo.hoursWeekend);
    descCtrl = TextEditingController(text: widget.initialInfo.description);
    selectedType = widget.initialInfo.type;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom:
            MediaQuery.of(context).viewInsets.bottom + 24, // Tránh bàn phím che
        top: 24,
        left: 24,
        right: 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Chỉnh sửa doanh nghiệp',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.grey.shade100,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildTextField('Tên doanh nghiệp', nameCtrl),
            const SizedBox(height: 12),
            _buildDropdown('Loại hình doanh nghiệp'),
            const SizedBox(height: 12),
            _buildTextField('Địa chỉ', addressCtrl),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildTextField('Điện thoại', phoneCtrl)),
                const SizedBox(width: 12),
                Expanded(child: _buildTextField('Website', websiteCtrl)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildTextField('Giờ T2–T6', hWeekdayCtrl)),
                const SizedBox(width: 12),
                Expanded(child: _buildTextField('Giờ T7–CN', hWeekendCtrl)),
              ],
            ),
            const SizedBox(height: 12),
            _buildTextField('Mô tả ngắn', descCtrl, maxLines: 3),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.grey.shade100,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Hủy',
                      style: TextStyle(color: Colors.black87),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      widget.onSave(
                        widget.initialInfo.copyWith(
                          name: nameCtrl.text,
                          type: selectedType,
                          address: addressCtrl.text,
                          phone: phoneCtrl.text,
                          website: websiteCtrl.text,
                          hoursWeekday: hWeekdayCtrl.text,
                          hoursWeekend: hWeekendCtrl.text,
                          description: descCtrl.text,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: const Color(0xFF22AFC2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.check, size: 18, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          'Lưu thay đổi',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController ctrl, {
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          maxLines: maxLines,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF22AFC2)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown(String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: selectedType,
              items: businessTypes
                  .map(
                    (t) => DropdownMenuItem(
                      value: t,
                      child: Text(t, style: const TextStyle(fontSize: 14)),
                    ),
                  )
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => selectedType = val);
              },
            ),
          ),
        ),
      ],
    );
  }
}
