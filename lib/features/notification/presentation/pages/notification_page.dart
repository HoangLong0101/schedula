import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/domain/entities/user.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../booking/presentation/pages/booking_page.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  static const routePath = '/notifications';
  static const routeName = 'notifications';

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    if (authState is! Authenticated) {
      return const Scaffold(body: Center(child: Text('No notifications')));
    }

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
          'Notifications',
          style: TextStyle(fontWeight: FontWeight.w800, color: Colors.black87),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _query(authState.user).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Could not load notifications'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final items = snapshot.requireData.docs
              .map((doc) => _NotificationItem.from(doc.data()))
              .where((item) => _filter == 'all' || item.type == _filter)
              .toList(growable: false);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            children: [
              _Filters(
                selected: _filter,
                onSelected: (value) => setState(() => _filter = value),
              ),
              const SizedBox(height: 14),
              if (items.isEmpty)
                const _EmptyState()
              else
                for (final item in items) _NotificationCard(item: item),
            ],
          );
        },
      ),
    );
  }

  Query<Map<String, dynamic>> _query(AppUser user) {
    var query = FirebaseFirestore.instance
        .collection('notifications')
        .where('tenantId', isEqualTo: user.tenantId);
    if (user.isStaff) {
      query = query.where('recipientUserId', isEqualTo: user.id);
    }
    return query.orderBy('sentAt', descending: true).limit(50);
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
        _chip('all', 'All'),
        _chip('staff_1h', 'Appointments'),
        _chip('customer_24h', 'Customers'),
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

  final _NotificationItem item;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFFFF0DE),
          child: Icon(item.icon, color: const Color(0xFFFF7622)),
        ),
        title: Text(
          item.title,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text('${item.message}\n${item.timeAgo}'),
        ),
        isThreeLine: true,
        trailing: item.read
            ? null
            : const Icon(Icons.circle, color: Color(0xFFFF4E57), size: 10),
        onTap: () => context.go(BookingPage.routePath),
      ),
    );
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
          Text('No notifications yet'),
        ],
      ),
    );
  }
}

class _NotificationItem {
  const _NotificationItem({
    required this.type,
    required this.title,
    required this.message,
    required this.sentAt,
    required this.read,
  });

  factory _NotificationItem.from(Map<String, dynamic> data) {
    return _NotificationItem(
      type: data['type'] as String? ?? '',
      title: data['title'] as String? ?? 'Notification',
      message: data['message'] as String? ?? '',
      sentAt: (data['sentAt'] as Timestamp?)?.toDate(),
      read: data['read'] == true,
    );
  }

  final String type;
  final String title;
  final String message;
  final DateTime? sentAt;
  final bool read;

  IconData get icon => type == 'staff_1h'
      ? Icons.calendar_month_outlined
      : Icons.notifications_none;

  String get timeAgo {
    final date = sentAt;
    if (date == null) return '';
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes} minutes ago';
    if (diff.inDays < 1) return '${diff.inHours} hours ago';
    return '${diff.inDays} days ago';
  }
}
