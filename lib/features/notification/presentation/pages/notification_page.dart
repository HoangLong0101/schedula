import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../booking/presentation/pages/booking_page.dart';
import '../../../staff/presentation/pages/staff_page.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  static const routePath = '/notifications';
  static const routeName = 'notifications';

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  int _selectedFilter = 0;

  static const _filters = [
    _NotificationFilter('Tất cả', 5),
    _NotificationFilter('Lịch hẹn', 2),
    _NotificationFilter('Nhân sự', 1),
    _NotificationFilter('Hệ thống', 2),
  ];

  static const _items = [
    _NotificationItem(
      category: 'Lịch hẹn',
      timeAgo: '5 phút trước',
      title: 'Cảnh báo khách không đến',
      message:
          'Quá 15 phút từ giờ hẹn nhưng khách Trần Bình Minh chưa Check-in. Hệ thống tự động chuyển sang trạng thái chờ.',
      icon: Icons.warning_amber_rounded,
      accent: _NotifyColors.orange,
      soft: _NotifyColors.orangeSoft,
      border: Color(0xFFFFDEBC),
      actionLabel: 'Xem lịch hẹn',
      routePath: BookingPage.routePath,
    ),
    _NotificationItem(
      category: 'Nhân sự',
      timeAgo: '32 phút trước',
      title: 'Nhân viên báo vắng đột xuất',
      message:
          'Dr. Bảo Trâm báo vắng mặt đột xuất ngày hôm nay. Vui lòng kiểm tra lại 3 lịch hẹn liên quan để sắp xếp lại.',
      icon: Icons.person_off_outlined,
      accent: _NotifyColors.red,
      soft: _NotifyColors.redSoft,
      border: Color(0xFFFFD6D6),
      actionLabel: 'Xem nhân viên',
      routePath: StaffPage.routePath,
    ),
    _NotificationItem(
      category: 'Hệ thống',
      timeAgo: '1 giờ trước',
      title: 'Đã gửi nhắc lịch tự động',
      message:
          'Hệ thống đã tự động gửi tin nhắn nhắc lịch trước 2 tiếng đến 5 khách hàng trong cùng giờ 14:00.',
      icon: Icons.chat_bubble_outline,
      accent: _NotifyColors.teal,
      soft: _NotifyColors.tealSoft,
      border: Color(0xFFC9F3EE),
      actionLabel: 'Xem chi tiết',
      routePath: BookingPage.routePath,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final visibleItems = _selectedFilter == 0
        ? _items
        : _items
              .where((item) => item.category == _filters[_selectedFilter].label)
              .toList(growable: false);

    return Scaffold(
      backgroundColor: _NotifyColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _NotificationHeader(unreadCount: 3),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 34),
                children: [
                  _FilterRail(
                    filters: _filters,
                    selectedIndex: _selectedFilter,
                    onChanged: (index) {
                      setState(() => _selectedFilter = index);
                    },
                  ),
                  const SizedBox(height: 24),
                  const _InfoCard(),
                  const SizedBox(height: 22),
                  for (final item in visibleItems) ...[
                    _NotificationCard(item: item),
                    const SizedBox(height: 20),
                  ],
                  if (visibleItems.isEmpty) const _EmptyNotifications(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationHeader extends StatelessWidget {
  const _NotificationHeader({required this.unreadCount});

  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 86,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      color: Colors.white,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: _HeaderIconButton(
              icon: Icons.chevron_left,
              onTap: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go(BookingPage.routePath);
                }
              },
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Thông báo',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: _NotifyColors.ink,
                  fontWeight: FontWeight.w900,
                  fontSize: 23,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: _NotifyColors.red,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$unreadCount',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Đọc hết',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: _NotifyColors.tealDark,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _NotifyColors.softButton,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Icon(icon, color: _NotifyColors.grayBlue, size: 25),
      ),
    );
  }
}

class _FilterRail extends StatelessWidget {
  const _FilterRail({
    required this.filters,
    required this.selectedIndex,
    required this.onChanged,
  });

  final List<_NotificationFilter> filters;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          for (var i = 0; i < filters.length; i++) ...[
            _FilterChipButton(
              filter: filters[i],
              selected: selectedIndex == i,
              onTap: () => onChanged(i),
            ),
            if (i != filters.length - 1) const SizedBox(width: 10),
          ],
        ],
      ),
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  const _FilterChipButton({
    required this.filter,
    required this.selected,
    required this.onTap,
  });

  final _NotificationFilter filter;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
        decoration: BoxDecoration(
          color: selected ? _NotifyColors.darkChip : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: _NotifyShadow.card,
        ),
        child: Row(
          children: [
            Text(
              filter.label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: selected ? Colors.white : _NotifyColors.muted,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white.withValues(alpha: 0.18)
                    : _NotifyColors.badgeSoft,
                shape: BoxShape.circle,
              ),
              child: Text(
                '${filter.count}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: selected ? Colors.white : _NotifyColors.muted,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _NotifyColors.border),
        boxShadow: _NotifyShadow.card,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_outline,
            color: _NotifyColors.tealDark,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: _NotifyColors.muted,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
                children: const [
                  TextSpan(
                    text:
                        'Chỉ hiển thị thông báo nghiệp vụ quan trọng. Cấu hình loại popup tại ',
                  ),
                  TextSpan(
                    text: 'Cài đặt thông báo.',
                    style: TextStyle(
                      color: _NotifyColors.tealDark,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.item});

  final _NotificationItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: item.border),
        boxShadow: _NotifyShadow.card,
      ),
      child: Stack(
        children: [
          Positioned(
            top: -2,
            right: 0,
            child: Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: _NotifyColors.redDot,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 50,
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: item.soft,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(item.icon, color: item.accent, size: 25),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _CategoryBadge(item: item),
                        const SizedBox(width: 10),
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: _NotifyColors.muted.withValues(alpha: 0.8),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            item.timeAgo,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(color: _NotifyColors.muted),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      item.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: _NotifyColors.ink,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.message,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: _NotifyColors.body,
                        height: 1.55,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _PrimaryActionButton(item: item),
                        const _SecondaryActionButton(),
                        const _DismissButton(),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.item});

  final _NotificationItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: item.soft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_categoryIcon(item.category), color: item.accent, size: 12),
          const SizedBox(width: 4),
          Text(
            item.category,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: item.accent,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  IconData _categoryIcon(String category) {
    if (category == 'Lịch hẹn') return Icons.calendar_month_outlined;
    if (category == 'Nhân sự') return Icons.person_off_outlined;
    return Icons.settings_outlined;
  }
}

class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({required this.item});

  final _NotificationItem item;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go(item.routePath),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: item.accent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          item.actionLabel,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _SecondaryActionButton extends StatelessWidget {
  const _SecondaryActionButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
      decoration: BoxDecoration(
        color: _NotifyColors.softButton,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'Đánh dấu đã đọc',
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: _NotifyColors.darkChip,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _DismissButton extends StatelessWidget {
  const _DismissButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _NotifyColors.softButton,
        borderRadius: BorderRadius.circular(13),
      ),
      child: const Icon(Icons.close, color: _NotifyColors.grayBlue, size: 18),
    );
  }
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _NotifyColors.border),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.notifications_off_outlined,
            color: _NotifyColors.grayBlue,
            size: 36,
          ),
          const SizedBox(height: 10),
          Text(
            'Không có thông báo trong mục này',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: _NotifyColors.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationFilter {
  const _NotificationFilter(this.label, this.count);

  final String label;
  final int count;
}

class _NotificationItem {
  const _NotificationItem({
    required this.category,
    required this.timeAgo,
    required this.title,
    required this.message,
    required this.icon,
    required this.accent,
    required this.soft,
    required this.border,
    required this.actionLabel,
    required this.routePath,
  });

  final String category;
  final String timeAgo;
  final String title;
  final String message;
  final IconData icon;
  final Color accent;
  final Color soft;
  final Color border;
  final String actionLabel;
  final String routePath;
}

class _NotifyColors {
  static const background = Color(0xFFEFFBFC);
  static const ink = Color(0xFF111827);
  static const body = Color(0xFF596579);
  static const muted = Color(0xFF7A8393);
  static const grayBlue = Color(0xFF738196);
  static const darkChip = Color(0xFF334155);
  static const softButton = Color(0xFFF3F6F8);
  static const badgeSoft = Color(0xFFE9EEF3);
  static const border = Color(0x12000000);
  static const teal = Color(0xFF22AFC2);
  static const tealDark = Color(0xFF148A9C);
  static const tealSoft = Color(0xFFE3FAF8);
  static const orange = Color(0xFFFF7622);
  static const orangeSoft = Color(0xFFFFF0DE);
  static const red = Color(0xFFFF4E57);
  static const redSoft = Color(0xFFFFE9EC);
  static const redDot = Color(0xFFFF2E45);
}

class _NotifyShadow {
  static final card = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];
}
