import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../domain/entities/customer.dart';
import '../cubit/customer_management_cubit.dart';

class CustomerPage extends StatelessWidget {
  const CustomerPage({super.key});

  static const routePath = '/customers';
  static const routeName = 'customers';

  @override
  Widget build(BuildContext context) {
    // Trích xuất tenantId từ phiên đăng nhập hiện tại
    final authState = context.read<AuthBloc>().state;
    final tenantId = authState is Authenticated ? authState.user.tenantId : '';

    if (tenantId.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('Lỗi: Không tìm thấy mã cơ sở')),
      );
    }

    return BlocProvider(
      // Dùng GetIt để tự động tiêm các UseCase vào Cubit và gọi hàm init
      create: (_) => getIt<CustomerManagementCubit>()..init(tenantId),
      child: const _CustomerView(),
    );
  }
}

class _CustomerView extends StatefulWidget {
  const _CustomerView();

  @override
  State<_CustomerView> createState() => _CustomerViewState();
}

class _CustomerViewState extends State<_CustomerView> {
  String _searchQuery = '';
  CustomerStatus? _filter; // null = All

  void _goBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/dashboard');
    }
  }

  void _showForm(BuildContext context, {Customer? customer}) {
    final cubit = context.read<CustomerManagementCubit>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CustomerFormSheet(
        initialCustomer: customer,
        onSave: (newCustomer) {
          if (customer == null) {
            cubit.addCustomer(newCustomer);
          } else {
            cubit.updateCustomer(newCustomer);
          }
          Navigator.pop(ctx);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFf0f9fa), // Màu nền chuẩn từ React
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _IconButton(icon: Icons.chevron_left, onTap: () => _goBack(context)),
                  const Text('Quản lý Khách hàng', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                  _IconButton(
                    icon: Icons.add,
                    iconColor: Colors.white,
                    bgColor: const Color(0xFF22AFC2),
                    onTap: () => _showForm(context),
                  ),
                ],
              ),
            ),

            Expanded(
              child: BlocBuilder<CustomerManagementCubit, List<Customer>>(
                builder: (context, customers) {
                  // Lọc dữ liệu
                  final filtered = customers.where((c) {
                    final matchSearch = c.name.toLowerCase().contains(_searchQuery.toLowerCase()) || c.phone.contains(_searchQuery);
                    final matchFilter = _filter == null || c.derivedStatus == _filter;
                    return matchSearch && matchFilter;
                  }).toList();

                  // Thống kê
                  final countAll = customers.length;
                  final countNew = customers.where((c) => c.derivedStatus == CustomerStatus.newCustomer).length;
                  final countRecovery = customers.where((c) => c.derivedStatus == CustomerStatus.recovery).length;
                  final countFollowUp = customers.where((c) => c.derivedStatus == CustomerStatus.followUp).length;

                  return ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    children: [
                      // Thanh tìm kiếm
                      Container(
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4)]),
                        child: TextField(
                          onChanged: (val) => setState(() => _searchQuery = val),
                          decoration: InputDecoration(
                            hintText: 'Tìm theo tên hoặc SĐT...',
                            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                            prefixIcon: Icon(Icons.search, size: 20, color: Colors.grey.shade400),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Tabs lọc
                      Row(
                        children: [
                          _FilterTab(label: 'Tổng', count: countAll, color: const Color(0xFF148a9c), isSelected: _filter == null, onTap: () => setState(() => _filter = null)),
                          const SizedBox(width: 8),
                          _FilterTab(label: 'Mới', count: countNew, color: const Color(0xFF3b82f6), isSelected: _filter == CustomerStatus.newCustomer, onTap: () => setState(() => _filter = CustomerStatus.newCustomer)),
                          const SizedBox(width: 8),
                          _FilterTab(label: 'Liệu trình', count: countRecovery, color: const Color(0xFF22AFC2), isSelected: _filter == CustomerStatus.recovery, onTap: () => setState(() => _filter = CustomerStatus.recovery)),
                          const SizedBox(width: 8),
                          _FilterTab(label: 'Tái khám', count: countFollowUp, color: const Color(0xFFf97316), isSelected: _filter == CustomerStatus.followUp, onTap: () => setState(() => _filter = CustomerStatus.followUp)),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // AI Hint
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [const Color(0xFF22AFC2).withOpacity(0.1), const Color(0xFF58d8e3).withOpacity(0.1)]),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Icon(Icons.auto_awesome, size: 16, color: Color(0xFF148a9c)),
                            SizedBox(width: 8),
                            Expanded(child: Text('AI tự động phân loại trạng thái dựa trên lịch hẹn và liệu trình của khách.', style: TextStyle(fontSize: 12, color: Color(0xFF148a9c), fontWeight: FontWeight.w500, height: 1.4))),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Danh sách khách hàng
                      if (filtered.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 40),
                          child: Center(child: Text('Không tìm thấy khách hàng', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
                        )
                      else
                        ...filtered.map((c) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _CustomerCard(
                            customer: c,
                            onEdit: () => _showForm(context, customer: c),
                            onDelete: () => context.read<CustomerManagementCubit>().deleteCustomer(c.id),
                          ),
                        )),

                      const SizedBox(height: 40),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- WIDGET THẺ KHÁCH HÀNG ---
class _CustomerCard extends StatelessWidget {
  final Customer customer;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CustomerCard({required this.customer, required this.onEdit, required this.onDelete});

  Color _parseColor(String hex) => Color(int.parse(hex.replaceFirst('#', '0xFF')));

  @override
  Widget build(BuildContext context) {
    final color = _parseColor(customer.color);
    final statusCfg = _getStatusConfig(customer.derivedStatus);
    final isBirthdaySoon = customer.birthdayInDays != null && customer.birthdayInDays! <= 14;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                alignment: Alignment.center,
                child: Text(customer.avatar, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(customer.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: statusCfg.bgColor, borderRadius: BorderRadius.circular(99)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(width: 6, height: 6, decoration: BoxDecoration(color: statusCfg.dotColor, shape: BoxShape.circle)),
                              const SizedBox(width: 4),
                              Text(statusCfg.label, style: TextStyle(color: statusCfg.color, fontSize: 10, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.phone, size: 12, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(customer.phone, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                        if (customer.age != null) ...[
                          const SizedBox(width: 6),
                          Text('• ${customer.age} tuổi', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                        ]
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Cảnh báo sinh nhật
          if (isBirthdaySoon)
            Container(
              margin: const EdgeInsets.only(top: 12), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: Colors.pink.shade50, borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  Icon(Icons.cake, size: 14, color: Colors.pink.shade400),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Sinh nhật ${customer.birthdayInDays == 0 ? "hôm nay" : "trong ${customer.birthdayInDays} ngày"}', style: TextStyle(fontSize: 12, color: Colors.pink.shade600, fontWeight: FontWeight.w600))),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(99)), child: Text('Gửi ưu đãi', style: TextStyle(fontSize: 10, color: Colors.pink.shade500, fontWeight: FontWeight.bold))),
                ],
              ),
            ),

          // Cảnh báo liệu trình / Tái khám
          if (customer.derivedStatus == CustomerStatus.recovery)
            Container(
              margin: const EdgeInsets.only(top: 12), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: const Color(0xFFe0f8fc), borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  const Icon(Icons.show_chart, size: 14, color: Color(0xFF148a9c)),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Đang chạy liệu trình • ${customer.recent30Count} buổi gần đây', style: const TextStyle(fontSize: 12, color: Color(0xFF148a9c), fontWeight: FontWeight.w600))),
                ],
              ),
            ),

          if (customer.derivedStatus == CustomerStatus.followUp)
            Container(
              margin: const EdgeInsets.only(top: 12), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  Icon(Icons.notifications_active, size: 14, color: Colors.orange.shade500),
                  const SizedBox(width: 8),
                  Expanded(child: Text('${customer.daysSinceLast} ngày chưa quay lại • Cần nhắc tái khám', style: TextStyle(fontSize: 12, color: Colors.orange.shade600, fontWeight: FontWeight.w600))),
                ],
              ),
            ),

          // Stats Grid
          Container(
            margin: const EdgeInsets.only(top: 12), padding: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade100))),
            child: Row(
              children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Lượt thăm', style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
                  Text('${customer.totalVisits}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                ])),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Lần cuối', style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
                  Text(customer.lastVisit.substring(5), style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                ])),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Lịch tới', style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
                  Text('${customer.futureCount}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF22AFC2))),
                ])),
              ],
            ),
          ),

          // Dị ứng (Đỏ) & Ghi chú (Vàng)
          if (customer.allergies.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 12), padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.warning_amber_rounded, size: 14, color: Colors.red.shade500),
                const SizedBox(width: 8),
                Expanded(child: Text('Dị ứng: ${customer.allergies}', style: TextStyle(fontSize: 12, color: Colors.red.shade600, fontWeight: FontWeight.w600))),
              ]),
            ),

          if (customer.notes.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 8), padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.yellow.shade50, borderRadius: BorderRadius.circular(8)),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.info_outline, size: 14, color: Colors.yellow.shade700),
                const SizedBox(width: 8),
                Expanded(child: Text(customer.notes, style: TextStyle(fontSize: 12, color: Colors.yellow.shade800, fontWeight: FontWeight.w500))),
              ]),
            ),

          // Nút hành động
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: onEdit,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.edit, size: 14, color: Colors.grey.shade700), const SizedBox(width: 6), Text('Chỉnh sửa', style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.bold))]),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onDelete,
                child: Container(
                  padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                  child: Icon(Icons.delete_outline, size: 16, color: Colors.red.shade400),
                ),
              )
            ],
          )
        ],
      ),
    );
  }
}

// --- BOTTOM SHEET FORM THÊM/SỬA KHÁCH HÀNG ---
class _CustomerFormSheet extends StatefulWidget {
  final Customer? initialCustomer;
  final Function(Customer) onSave;

  const _CustomerFormSheet({this.initialCustomer, required this.onSave});

  @override
  State<_CustomerFormSheet> createState() => _CustomerFormSheetState();
}

class _CustomerFormSheetState extends State<_CustomerFormSheet> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _bdCtrl = TextEditingController();
  final _allergiesCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialCustomer != null) {
      final c = widget.initialCustomer!;
      _nameCtrl.text = c.name;
      _phoneCtrl.text = c.phone;
      _emailCtrl.text = c.email;
      _bdCtrl.text = c.birthday;
      _allergiesCtrl.text = c.allergies;
      _notesCtrl.text = c.notes;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 24, top: 24, left: 24, right: 24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(widget.initialCustomer == null ? 'Thêm khách hàng mới' : 'Chỉnh sửa khách hàng', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                _IconButton(icon: Icons.close, onTap: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 16),

            _buildTextField(_nameCtrl, Icons.person_outline, 'Họ và tên', 'Nhập họ tên đầy đủ'),
            _buildTextField(_phoneCtrl, Icons.phone_outlined, 'Số điện thoại (khóa chính)', '0901234567', type: TextInputType.phone),
            _buildTextField(_emailCtrl, Icons.mail_outline, 'Email', 'email@example.com', type: TextInputType.emailAddress),
            _buildTextField(_bdCtrl, Icons.cake_outlined, 'Ngày sinh', 'YYYY-MM-DD', type: TextInputType.datetime, hintText: 'để AI gợi ý ưu đãi sinh nhật'),
            _buildTextField(_allergiesCtrl, Icons.warning_amber_rounded, 'Dị ứng / Cảnh báo', 'VD: Dị ứng cồn...', type: TextInputType.text, isAlert: true, hintText: 'hiển thị nổi bật'),
            _buildTextField(_notesCtrl, Icons.info_outline, 'Ghi chú da liễu / Sức khỏe', 'VD: Da nhạy cảm...', type: TextInputType.multiline, maxLines: 3),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton(
                onPressed: () {
                  if (_nameCtrl.text.trim().isEmpty ||
                      _phoneCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Vui lòng nhập tên và số điện thoại.'),
                      ),
                    );
                    return;
                  }
                  widget.onSave(Customer(
                    id: widget.initialCustomer?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                    name: _nameCtrl.text.trim(), phone: _phoneCtrl.text.trim(), email: _emailCtrl.text.trim(),
                    birthday: _bdCtrl.text, allergies: _allergiesCtrl.text, notes: _notesCtrl.text,
                    lastVisit: DateTime.now().toIso8601String().split('T')[0], avatar: _nameCtrl.text.isNotEmpty ? _nameCtrl.text[0].toUpperCase() : 'U', color: '#22AFC2',
                  ));
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF22AFC2), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                child: Text(widget.initialCustomer == null ? 'Thêm khách hàng' : 'Lưu thay đổi', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            )
          ],
        ),
      ),
    );
  }

  // Đổi ngoặc vuông [] thành ngoặc nhọn {} để dùng named parameters
  Widget _buildTextField(
      TextEditingController ctrl,
      IconData icon,
      String label,
      String placeholder, {
        TextInputType type = TextInputType.text,
        bool isAlert = false,
        String? hintText,
        int maxLines = 1,
      }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: Colors.grey.shade500),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
              if (hintText != null) Text(' ($hintText)', style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: ctrl, keyboardType: type, maxLines: maxLines,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: placeholder,
              hintStyle: TextStyle(fontSize: 14, color: Colors.grey.shade400),
              filled: true, fillColor: isAlert ? Colors.red.shade50.withOpacity(0.5) : Colors.grey.shade50,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isAlert ? Colors.red.shade300 : const Color(0xFF22AFC2))),
            ),
          ),
        ],
      ),
    );
  }
}

// --- HELPER COMPONENTS ---
class _FilterTab extends StatelessWidget {
  final String label; final int count; final Color color; final bool isSelected; final VoidCallback onTap;
  const _FilterTab({required this.label, required this.count, required this.color, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.1) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? color : Colors.transparent, width: 2),
            boxShadow: isSelected ? [] : [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4)],
          ),
          child: Column(
            children: [
              Text('$count', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color, height: 1)),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color.withOpacity(0.8))),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  final IconData icon; final VoidCallback onTap; final Color? bgColor; final Color? iconColor;
  const _IconButton({required this.icon, required this.onTap, this.bgColor, this.iconColor});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(color: bgColor ?? Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: bgColor == null ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)] : null),
        child: Icon(icon, size: 20, color: iconColor ?? Colors.grey.shade700),
      ),
    );
  }
}

class _StatusConfig {
  final String label; final Color color; final Color bgColor; final Color dotColor;
  _StatusConfig(this.label, this.color, this.bgColor, this.dotColor);
}
_StatusConfig _getStatusConfig(CustomerStatus status) {
  switch (status) {
    case CustomerStatus.active: return _StatusConfig('Tích cực', const Color(0xFF16a34a), const Color(0xFFf0fdf4), const Color(0xFF22c55e));
    case CustomerStatus.followUp: return _StatusConfig('Cần tái khám', const Color(0xFFea580c), const Color(0xFFfff7ed), const Color(0xFFf97316));
    case CustomerStatus.newCustomer: return _StatusConfig('Mới', const Color(0xFF2563eb), const Color(0xFFeff6ff), const Color(0xFF3b82f6));
    case CustomerStatus.recovery: return _StatusConfig('Đang liệu trình', const Color(0xFF148a9c), const Color(0xFFe0f8fc), const Color(0xFF22AFC2));
  }
}
