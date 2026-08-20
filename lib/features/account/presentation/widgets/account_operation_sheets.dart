import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/di/injection.dart';
import '../../domain/entities/audit_event.dart';
import '../../domain/repositories/account_repository.dart';
import '../../domain/usecases/governance_usecase.dart';

GovernanceUseCase _governance() =>
    GovernanceUseCase(getIt<AccountRepository>());

class TenantActivityHistory extends StatelessWidget {
  const TenantActivityHistory({
    required this.tenantId,
    required this.rangeIndex,
    super.key,
  });

  final String tenantId;
  final int rangeIndex;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _governance().watchAudit(tenantId),
      builder: (context, snapshot) {
        final either = snapshot.data;
        if (either == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return either.fold((failure) => Text(failure.message), (allEvents) {
          final start = _activityStart(DateTime.now(), rangeIndex);
          final events = allEvents
              .where((event) => !event.createdAt.isBefore(start))
              .toList(growable: false);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Hoạt động với hệ thống',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  Text(
                    '${events.length} hoạt động',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (events.isEmpty)
                const _EmptyState(
                  icon: Icons.history_toggle_off_outlined,
                  title: 'Chưa có hoạt động trong kỳ',
                  message:
                      'Các thao tác thêm, chỉnh sửa và xóa sẽ xuất hiện tại đây.',
                )
              else
                ...events.map((event) => _AuditTile(event: event)),
            ],
          );
        });
      },
    );
  }
}

DateTime _activityStart(DateTime now, int rangeIndex) => switch (rangeIndex) {
  0 => DateTime(now.year, now.month, now.day),
  1 => DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6)),
  2 => DateTime(now.year, now.month),
  _ => DateTime(now.year),
};

void showAuditHistorySheet(BuildContext context, String tenantId) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _AuditSheet(tenantId: tenantId),
  );
}

void showCampaignSheet(BuildContext context, String tenantId) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _CampaignSheet(tenantId: tenantId),
  );
}

void showHelpSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _TextSheet(
      title: 'Trợ giúp',
      children: [
        ListTile(
          leading: Icon(Icons.event_available_outlined),
          title: Text('Quản lý lịch hẹn'),
          subtitle: Text(
            'Tạo, chỉnh sửa, hủy và ghi nhận thanh toán từ màn hình Lịch đặt.',
          ),
        ),
        ListTile(
          leading: Icon(Icons.people_outline),
          title: Text('Nhân viên và phân quyền'),
          subtitle: Text(
            'Quản lý ca làm, ngày nghỉ và quyền truy cập trong khu vực Tài khoản.',
          ),
        ),
        ListTile(
          leading: Icon(Icons.support_agent_outlined),
          title: Text('Liên hệ hỗ trợ'),
          subtitle: Text('support@schedula.app'),
          onTap: () => launchUrl(Uri.parse('mailto:support@schedula.app')),
        ),
        ListTile(
          leading: Icon(Icons.info_outline),
          title: Text('Phiên bản'),
          subtitle: Text('Schedula v1.0.0'),
        ),
      ],
    ),
  );
}

void showShortcutSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    builder: (_) => const _TextSheet(
      title: 'Phím tắt',
      children: [
        ListTile(title: Text('Alt + 1'), trailing: Text('Tổng quan')),
        ListTile(title: Text('Alt + 2'), trailing: Text('Lịch đặt')),
        ListTile(title: Text('Alt + 3'), trailing: Text('Thống kê')),
        ListTile(title: Text('Alt + 4'), trailing: Text('Tài khoản')),
        ListTile(title: Text('Esc'), trailing: Text('Đóng hộp thoại')),
      ],
    ),
  );
}

class _AuditSheet extends StatefulWidget {
  const _AuditSheet({required this.tenantId});

  final String tenantId;

  @override
  State<_AuditSheet> createState() => _AuditSheetState();
}

class _AuditSheetState extends State<_AuditSheet> {
  String actor = '';
  String action = '';

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .85,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const _SheetHeader(title: 'Lịch sử hoạt động'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        labelText: 'Người thực hiện',
                      ),
                      onChanged: (value) =>
                          setState(() => actor = value.toLowerCase()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(labelText: 'Hành động'),
                      onChanged: (value) =>
                          setState(() => action = value.toLowerCase()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: StreamBuilder(
                  stream: _governance().watchAudit(widget.tenantId),
                  builder: (context, snapshot) {
                    final either = snapshot.data;
                    if (either == null) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return either.fold(
                      (failure) => Center(child: Text(failure.message)),
                      (events) {
                        final filtered = events
                            .where(
                              (event) =>
                                  event.actorId.toLowerCase().contains(actor) &&
                                  event.action.toLowerCase().contains(action),
                            )
                            .toList(growable: false);
                        if (filtered.isEmpty) {
                          return const _EmptyState(
                            icon: Icons.history_toggle_off_outlined,
                            title: 'Chưa có lịch sử hoạt động',
                            message:
                                'Các thay đổi mới về lịch hẹn, thanh toán, '
                                'nhân viên và phân quyền sẽ xuất hiện tại đây.',
                          );
                        }
                        return ListView(
                          children: filtered
                              .map((event) => _AuditTile(event: event))
                              .toList(growable: false),
                        );
                      },
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
}

class _AuditTile extends StatelessWidget {
  const _AuditTile({required this.event});

  final AuditEvent event;

  @override
  Widget build(BuildContext context) {
    final date = event.createdAt;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(_auditIcon(event.action), color: const Color(0xFF148A9C)),
      title: Text(
        '${_auditAction(event.action)} · ${_entityName(event.entityType)}',
      ),
      subtitle: Text(
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')} '
        '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}',
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: event.status == 'failed'
              ? const Color(0xFFFFE4E6)
              : const Color(0xFFE7F6F0),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          event.status == 'failed' ? 'Thất bại' : 'Thành công',
          style: TextStyle(
            color: event.status == 'failed'
                ? const Color(0xFFE11D48)
                : const Color(0xFF07885E),
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  String _auditAction(String action) {
    final value = action.toLowerCase();
    if (value.contains('delete') || value.contains('archive')) return 'Xóa';
    if (value.contains('create') || value.contains('add')) return 'Thêm';
    return 'Chỉnh sửa';
  }

  IconData _auditIcon(String action) => switch (_auditAction(action)) {
    'Thêm' => Icons.add_circle_outline,
    'Xóa' => Icons.delete_outline,
    _ => Icons.edit_outlined,
  };

  String _entityName(String entity) => switch (entity) {
    'booking' => 'Lịch hẹn',
    'payment' => 'Thanh toán',
    'staff' => 'Nhân viên',
    'user' => 'Người dùng',
    'customer' => 'Khách hàng',
    'service' => 'Dịch vụ',
    'product' => 'Sản phẩm',
    'equipment' => 'Thiết bị',
    'tenant' => 'Doanh nghiệp',
    _ => 'Hệ thống',
  };
}

class _CampaignSheet extends StatefulWidget {
  const _CampaignSheet({required this.tenantId});

  final String tenantId;

  @override
  State<_CampaignSheet> createState() => _CampaignSheetState();
}

class _CampaignSheetState extends State<_CampaignSheet> {
  late final future = _governance().eligibleRecipients(widget.tenantId);
  late final TextEditingController subjectController;
  late final TextEditingController bodyController;
  final selected = <String>{};
  String template = 'follow_up';
  bool sending = false;

  @override
  void initState() {
    super.initState();
    subjectController = TextEditingController();
    bodyController = TextEditingController();
    _applyTemplate(template);
  }

  @override
  void dispose() {
    subjectController.dispose();
    bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .85,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const _SheetHeader(title: 'Chăm sóc khách hàng qua email'),
              DropdownButtonFormField<String>(
                initialValue: template,
                decoration: const InputDecoration(labelText: 'Mẫu đã duyệt'),
                items: const [
                  DropdownMenuItem(
                    value: 'birthday',
                    child: Text('Chúc mừng sinh nhật'),
                  ),
                  DropdownMenuItem(
                    value: 'follow_up',
                    child: Text('Mời đặt lịch tiếp theo'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    template = value;
                    _applyTemplate(value);
                  });
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: subjectController,
                maxLength: 150,
                decoration: const InputDecoration(
                  labelText: 'Tiêu đề email',
                  helperText: 'Có thể dùng {{name}} để chèn tên khách hàng.',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: bodyController,
                minLines: 3,
                maxLines: 5,
                maxLength: 5000,
                decoration: const InputDecoration(
                  labelText: 'Nội dung email',
                  alignLabelWithHint: true,
                  helperText: 'Nội dung sẽ được xem lại trước khi gửi.',
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: FutureBuilder(
                  future: future,
                  builder: (context, snapshot) {
                    final either = snapshot.data;
                    if (either == null) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return either.fold(
                      (failure) => Center(child: Text(failure.message)),
                      (recipients) {
                        if (recipients.isEmpty) {
                          return const _EmptyState(
                            icon: Icons.mark_email_unread_outlined,
                            title: 'Chưa có khách hàng đủ điều kiện',
                            message:
                                'Cần có email hợp lệ và đồng ý nhận email '
                                'tiếp thị trước khi gửi.',
                          );
                        }
                        return ListView(
                          children: recipients
                              .map(
                                (recipient) => CheckboxListTile(
                                  value: selected.contains(recipient.id),
                                  title: Text(recipient.name),
                                  subtitle: Text(
                                    '${recipient.email}\n${recipient.reason}',
                                  ),
                                  onChanged: (checked) => setState(() {
                                    checked == true
                                        ? selected.add(recipient.id)
                                        : selected.remove(recipient.id);
                                  }),
                                ),
                              )
                              .toList(growable: false),
                        );
                      },
                    );
                  },
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: Row(
                  children: [
                    TextButton(
                      onPressed: _showDeliveryHistory,
                      child: const Text('Lịch sử gửi'),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        onPressed: sending || selected.isEmpty
                            ? null
                            : _reviewAndSend,
                        child: Text(
                          sending
                              ? 'Đang gửi...'
                              : 'Xem lại và gửi (${selected.length})',
                        ),
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

  Future<void> _reviewAndSend() async {
    final subject = subjectController.text.trim();
    final body = bodyController.text.trim();
    if (subject.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập tiêu đề và nội dung email.'),
        ),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xác nhận gửi email'),
        content: SingleChildScrollView(
          child: Text(
            'Người nhận: ${selected.length}\n\n'
            'Tiêu đề:\n$subject\n\n'
            'Nội dung:\n$body',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Gửi'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => sending = true);
    final result = await _governance().sendCampaign(
      templateId: template,
      subject: subject,
      body: body,
      recipientIds: selected.toList(growable: false),
    );
    if (!mounted) return;
    setState(() => sending = false);
    result.fold(
      (failure) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message))),
      (counts) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã gửi ${counts['sent']}, lỗi ${counts['failed']}.'),
          ),
        );
        Navigator.pop(context);
      },
    );
  }

  void _showDeliveryHistory() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CampaignHistorySheet(tenantId: widget.tenantId),
    );
  }

  void _applyTemplate(String value) {
    if (value == 'birthday') {
      subjectController.text = 'Chúc mừng sinh nhật {{name}}';
      bodyController.text =
          'Chúc mừng sinh nhật {{name}}. Cảm ơn bạn đã luôn đồng hành '
          'cùng chúng tôi.';
      return;
    }
    subjectController.text = 'Đã đến lúc đặt lịch chăm sóc tiếp theo';
    bodyController.text =
        'Xin chào {{name}}, đã đến lúc đặt lịch chăm sóc tiếp theo của bạn.';
  }
}

class _CampaignHistorySheet extends StatelessWidget {
  const _CampaignHistorySheet({required this.tenantId});

  final String tenantId;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .85,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const _SheetHeader(title: 'Lịch sử gửi email'),
              Expanded(
                child: StreamBuilder(
                  stream: _governance().watchCampaigns(tenantId),
                  builder: (context, campaignSnapshot) {
                    final campaignsEither = campaignSnapshot.data;
                    if (campaignsEither == null) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return campaignsEither.fold(
                      (failure) => Center(child: Text(failure.message)),
                      (campaigns) {
                        if (campaigns.isEmpty) {
                          return const _EmptyState(
                            icon: Icons.history_toggle_off_outlined,
                            title: 'Chưa có lịch sử gửi email',
                            message:
                                'Chiến dịch đã gửi hoặc gửi lỗi sẽ xuất hiện '
                                'tại đây.',
                          );
                        }
                        return StreamBuilder(
                          stream: _governance().watchDeliveries(tenantId),
                          builder: (context, deliverySnapshot) {
                            final deliveriesEither = deliverySnapshot.data;
                            if (deliveriesEither == null) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }
                            return deliveriesEither.fold(
                              (failure) => Center(child: Text(failure.message)),
                              (deliveries) => ListView(
                                children: campaigns
                                    .map(
                                      (campaign) => _CampaignHistoryTile(
                                        campaign: campaign,
                                        deliveries: deliveries
                                            .where(
                                              (delivery) =>
                                                  delivery.campaignId ==
                                                  campaign.id,
                                            )
                                            .toList(growable: false),
                                      ),
                                    )
                                    .toList(growable: false),
                              ),
                            );
                          },
                        );
                      },
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
}

class _CampaignHistoryTile extends StatelessWidget {
  const _CampaignHistoryTile({
    required this.campaign,
    required this.deliveries,
  });

  final CampaignRecord campaign;
  final List<CampaignDelivery> deliveries;

  @override
  Widget build(BuildContext context) {
    final date = campaign.createdAt;
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(
        campaign.subject.isEmpty ? 'Chiến dịch email' : campaign.subject,
      ),
      subtitle: Text(
        '${_campaignStatus(campaign.status)}\n'
        'Đã gửi ${campaign.sent}, lỗi ${campaign.failed}, '
        'tổng ${campaign.recipientCount}\n'
        '${date.day}/${date.month}/${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}',
      ),
      children: deliveries.isEmpty
          ? const [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Chưa có chi tiết gửi.'),
              ),
            ]
          : deliveries
                .map(
                  (delivery) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      delivery.email.isEmpty
                          ? 'Không có địa chỉ email'
                          : delivery.email,
                    ),
                    subtitle: delivery.reason.isEmpty
                        ? null
                        : Text(_deliveryReason(delivery.reason)),
                    trailing: Text(_deliveryStatus(delivery.status)),
                  ),
                )
                .toList(growable: false),
    );
  }

  String _campaignStatus(String status) => switch (status) {
    'sending' => 'Đang gửi',
    'sent' => 'Đã gửi',
    'partial' => 'Gửi một phần',
    'failed' => 'Gửi thất bại',
    _ => 'Không xác định',
  };

  String _deliveryStatus(String status) => switch (status) {
    'sent' => 'Đã gửi',
    'failed' => 'Thất bại',
    'skipped' => 'Đã bỏ qua',
    _ => 'Không xác định',
  };

  String _deliveryReason(String reason) => switch (reason) {
    'not_eligible' => 'Khách hàng không còn đủ điều kiện nhận email.',
    'unknown_error' => 'Lỗi không xác định từ dịch vụ email.',
    _ => reason,
  };
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _TextSheet extends StatelessWidget {
  const _TextSheet({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SheetHeader(title: title),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        IconButton(
          tooltip: 'Đóng',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close),
        ),
      ],
    );
  }
}
