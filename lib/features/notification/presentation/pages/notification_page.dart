import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../booking/presentation/pages/booking_page.dart';
import '../../domain/entities/app_notification.dart';
import '../cubit/notification_cubit.dart';
import '../cubit/notification_state.dart';

class NotificationPage extends StatelessWidget {
  const NotificationPage({super.key});

  static const routePath = '/notifications';
  static const routeName = 'notifications';

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    if (authState is! Authenticated) {
      return const Scaffold(body: Center(child: Text('Chưa có thông báo')));
    }
    return BlocProvider(
      create: (_) => getIt<NotificationCubit>()
        ..init(
          tenantId: authState.user.tenantId,
          userId: authState.user.id,
          staffOnly: authState.user.isStaff,
        ),
      child: const _NotificationView(),
    );
  }
}

class _NotificationView extends StatelessWidget {
  const _NotificationView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFFBFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go(BookingPage.routePath),
        ),
        title: const Text(
          'Thông báo',
          style: TextStyle(fontWeight: FontWeight.w800, color: Colors.black87),
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Tùy chọn thông báo',
            onSelected: (_) => context.read<NotificationCubit>().markAllRead(),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'mark_all_read',
                child: Text('Đánh dấu tất cả đã đọc'),
              ),
            ],
          ),
        ],
      ),
      body: BlocBuilder<NotificationCubit, NotificationState>(
        builder: (context, state) {
          if (state.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.error != null && state.items.isEmpty) {
            return Center(child: Text(state.error!));
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            children: [
              _Filters(
                selected: state.filter,
                onSelected: context.read<NotificationCubit>().setFilter,
              ),
              const SizedBox(height: 14),
              if (state.visible.isEmpty)
                const _EmptyState()
              else
                for (final item in state.visible) _NotificationCard(item: item),
            ],
          );
        },
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        _chip('all', 'Tất cả'),
        _chip('staff_1h', 'Lịch hẹn'),
        _chip('customer_24h', 'Khách hàng'),
      ],
    );
  }

  Widget _chip(String value, String label) {
    return ChoiceChip(
      label: Text(label),
      selected: selected == value,
      onSelected: (_) => onSelected(value),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.item});

  final AppNotification item;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFFFF0DE),
          child: Icon(
            item.type == 'staff_1h'
                ? Icons.calendar_month_outlined
                : Icons.notifications_none,
            color: const Color(0xFFFF7622),
          ),
        ),
        title: Text(
          item.title,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text('${item.message}\n${_timeAgo(item.sentAt)}'),
        ),
        isThreeLine: true,
        trailing: item.read
            ? null
            : const Icon(Icons.circle, color: Color(0xFFFF4E57), size: 10),
        onTap: () {
          context.read<NotificationCubit>().markRead(item.id);
          final bookingId = item.bookingId;
          context.go(
            bookingId == null || bookingId.isEmpty
                ? BookingPage.routePath
                : '${BookingPage.routePath}?bookingId=$bookingId&action=view',
          );
        },
      ),
    );
  }

  String _timeAgo(DateTime? date) {
    if (date == null) return '';
    final difference = DateTime.now().difference(date);
    if (difference.inMinutes < 1) return 'Vừa xong';
    if (difference.inHours < 1) return '${difference.inMinutes} phút trước';
    if (difference.inDays < 1) return '${difference.inHours} giờ trước';
    return '${difference.inDays} ngày trước';
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 80),
      child: Column(
        children: [
          Icon(Icons.notifications_off_outlined, size: 42, color: Colors.grey),
          SizedBox(height: 10),
          Text('Chưa có thông báo'),
        ],
      ),
    );
  }
}
