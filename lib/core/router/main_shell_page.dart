import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/bloc/auth_state.dart';
import '../../features/booking/presentation/widgets/booking_form_sheet.dart';

class MainShellPage extends StatelessWidget {
  const MainShellPage({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  // Lấy mã màu từ DESIGN.md
  static const Color tealBg = Color(0xFF58D8E3);
  static const Color tealPlus = Color(0xFF22AFC2);

  void _onItemTapped(int index, BuildContext context) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  void _onAddPressed(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    if (authState is Authenticated) {
      // Giả định state Authenticated chứa thông tin user
      // Nếu thuộc tính khác, bạn điều chỉnh lại biến .user.tenantId cho khớp nhé
      final tenantId = authState.user.tenantId;
      BookingFormSheet.show(context, tenantId: tenantId);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lỗi: Không tìm thấy thông tin Tenant.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: const Color(0xFFFCFCFD),
      body: navigationShell,
      // CỐ ĐỊNH CHIỀU CAO TẠI ĐÂY, NGĂN ALIGN CHIẾM TOÀN MÀN HÌNH
      bottomNavigationBar: SizedBox(
        height: 84 + bottomPadding,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Padding(
              padding: EdgeInsets.only(bottom: bottomPadding),
              child: SizedBox(
                height: 84,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  clipBehavior: Clip.none,
                  children: [
                    // Main Navbar Background
                    Container(
                      height: 64,
                      decoration: const BoxDecoration(
                        color: tealBg,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(10),
                          topRight: Radius.circular(10),
                        ),
                      ),
                      child: Column(
                        children: [
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _NavBarItem(
                                  icon: Icons.home_outlined,
                                  label: 'Trang chủ',
                                  isSelected: navigationShell.currentIndex == 0,
                                  onTap: () => _onItemTapped(0, context),
                                ),
                                _NavBarItem(
                                  icon: Icons.calendar_month_outlined,
                                  label: 'Lịch hẹn',
                                  isSelected: navigationShell.currentIndex == 1,
                                  onTap: () => _onItemTapped(1, context),
                                ),
                                const SizedBox(
                                  width: 80,
                                ), // Khoảng trống cho nút +
                                _NavBarItem(
                                  icon: Icons.bar_chart_outlined,
                                  label: 'Thống kê',
                                  isSelected: navigationShell.currentIndex == 2,
                                  onTap: () => _onItemTapped(2, context),
                                ),
                                _NavBarItem(
                                  icon: Icons.person_outline,
                                  label: 'Tài khoản',
                                  isSelected: navigationShell.currentIndex == 3,
                                  onTap: () => _onItemTapped(3, context),
                                ),
                              ],
                            ),
                          ),
                          // iPhone Home Indicator Spacer
                          Container(
                            height: 5,
                            width: 134,
                            margin: const EdgeInsets.only(bottom: 8, top: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Floating Add Button
                    Positioned(
                      top: -12, // Đẩy nút nổi lên trên bar
                      child: GestureDetector(
                        onTap: () => _onAddPressed(context),
                        child: Container(
                          width: 88,
                          height: 88,
                          decoration: const BoxDecoration(
                            color: tealBg,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.add,
                              color: tealPlus,
                              size: 32,
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
      ),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  const _NavBarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isSelected
        ? Colors.white
        : Colors.white.withValues(alpha: 0.65);
    final fontWeight = isSelected ? FontWeight.w600 : FontWeight.w500;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 65,
        height: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontWeight: fontWeight,
                fontSize: 10,
                color: color,
                letterSpacing: -0.15,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
