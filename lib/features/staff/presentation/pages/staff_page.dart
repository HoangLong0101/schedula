import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';

import '../../domain/entities/staff_member.dart';
import '../cubit/staff_management_cubit.dart';

class StaffPage extends StatelessWidget {
  const StaffPage({super.key});

  static const routePath = '/staff';
  static const routeName = 'staff';

  @override
  Widget build(BuildContext context) {
    // 1. Trích xuất tenantId từ phiên đăng nhập hiện tại
    final authState = context.read<AuthBloc>().state;
    final tenantId = authState is Authenticated ? authState.user.tenantId : '';

    if (tenantId.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('Lỗi: Không tìm thấy mã cơ sở')),
      );
    }

    return BlocProvider(
      // 2. Dùng GetIt để tiêm UseCases và truyền tenantId vào
      create: (_) => getIt<StaffManagementCubit>()..init(tenantId),
      child: const _StaffView(),
    );
  }
}

class _StaffView extends StatelessWidget {
  const _StaffView();

  void _showStaffForm(BuildContext context, {StaffMember? staff}) {
    final cubit = context.read<StaffManagementCubit>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _StaffFormSheet(
        initialStaff: staff,
        onSave: (newStaff) {
          if (staff == null) {
            cubit.addStaff(newStaff);
          } else {
            cubit.updateStaff(newStaff);
          }
          Navigator.pop(context);
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, String id) {
    final cubit = context.read<StaffManagementCubit>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56, height: 56,
              decoration: const BoxDecoration(color: Color(0xFFFEF2F2), shape: BoxShape.circle),
              child: const Icon(Icons.delete_outline, color: Color(0xFFF87171), size: 28),
            ),
            const SizedBox(height: 16),
            const Text('Xóa nhân viên?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Hành động này không thể hoàn tác.', style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: TextButton.styleFrom(backgroundColor: Colors.grey.shade100, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: const Text('Hủy', style: TextStyle(color: Colors.black87)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      cubit.deleteStaff(id);
                      Navigator.pop(ctx);
                    },
                    style: TextButton.styleFrom(backgroundColor: const Color(0xFFEF4444), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: const Text('Xóa', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCFCFD),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _IconButton(icon: Icons.chevron_left, onTap: () => context.pop()),
                  const Text('Quản Lý Nhân Viên', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                  _IconButton(
                    icon: Icons.add,
                    iconColor: Colors.white,
                    bgColor: const Color(0xFF8B5CF6), // Giả lập gradient tím
                    onTap: () => _showStaffForm(context),
                  ),
                ],
              ),
            ),

            Expanded(
              child: BlocBuilder<StaffManagementCubit, List<StaffMember>>(
                builder: (context, staffList) {
                  final available = staffList.where((s) => s.status == StaffStatus.available).length;
                  final inSession = staffList.where((s) => s.status == StaffStatus.inSession).length;
                  final absent = staffList.where((s) => s.status == StaffStatus.absent).length;

                  return ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    children: [
                      // Stats Row
                      Row(
                        children: [
                          _StatCard(value: available, label: 'Sẵn sàng', color: const Color(0xFF16a34a), bgColor: const Color(0xFFf0fdf4)),
                          const SizedBox(width: 8),
                          _StatCard(value: inSession, label: 'Trong phiên', color: const Color(0xFFea580c), bgColor: const Color(0xFFfff7ed)),
                          const SizedBox(width: 8),
                          _StatCard(value: absent, label: 'Vắng mặt', color: const Color(0xFFca8a04), bgColor: const Color(0xFFfefce8)),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Staff List
                      ...staffList.map((staff) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _StaffCard(
                          staff: staff,
                          onEdit: () => _showStaffForm(context, staff: staff),
                          onDelete: () => _confirmDelete(context, staff.id),
                        ),
                      )),

                      // Add Button CTA
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () => _showStaffForm(context),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFa5f3fc), width: 2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.add, color: Color(0xFF22AFC2), size: 20),
                              SizedBox(width: 8),
                              Text('Thêm nhân viên mới', style: TextStyle(color: Color(0xFF22AFC2), fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
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

// --- WIDGETS PHỤ ---

class _StaffCard extends StatelessWidget {
  final StaffMember staff;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _StaffCard({required this.staff, required this.onEdit, required this.onDelete});

  Color _parseColor(String hex) => Color(int.parse(hex.replaceFirst('#', '0xFF')));

  @override
  Widget build(BuildContext context) {
    final color = _parseColor(staff.color);
    final statusCfg = _getStatusConfig(staff.status);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade100)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                    alignment: Alignment.center,
                    child: Text(staff.name.split(' ').last[0].toUpperCase(), style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  Positioned(bottom: -2, right: -2, child: Container(width: 14, height: 14, decoration: BoxDecoration(color: statusCfg.color, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)))),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(staff.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: statusCfg.bgColor, borderRadius: BorderRadius.circular(99)),
                          child: Text(statusCfg.label, style: TextStyle(color: statusCfg.color, fontSize: 10, fontWeight: FontWeight.bold)),
                        )
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(staff.role, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    if (staff.phone.isNotEmpty) Text(staff.phone, style: TextStyle(fontSize: 12, color: color)),
                  ],
                ),
              ),
            ],
          ),

          if (staff.specialties.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6, runSpacing: 6,
              children: staff.specialties.map((s) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(99)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome, size: 10, color: color),
                    const SizedBox(width: 4),
                    Text(s, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
                  ],
                ),
              )).toList(),
            ),
          ],

          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.calendar_month, size: 12, color: Colors.grey),
              const SizedBox(width: 6),
              Expanded(child: _ShiftBar(shift: staff.shift)),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(width: 6, height: 6, decoration: BoxDecoration(color: Colors.grey.shade400, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text('${staff.appointments} lịch hôm nay', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              const SizedBox(width: 16),
              Container(width: 6, height: 6, decoration: BoxDecoration(color: Colors.yellow.shade500, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text('${staff.rating} ⭐', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              const Spacer(),
              _ActionBtn(icon: Icons.edit_outlined, color: const Color(0xFF148a9c), bgColor: const Color(0xFFe0f8fc), onTap: onEdit),
              const SizedBox(width: 8),
              _ActionBtn(icon: Icons.delete_outline, color: Colors.red.shade400, bgColor: Colors.red.shade50, onTap: onDelete),
            ],
          )
        ],
      ),
    );
  }
}

class _ShiftBar extends StatelessWidget {
  final Map<String, ShiftValue> shift;
  const _ShiftBar({required this.shift});

  @override
  Widget build(BuildContext context) {
    final days = [
      {'k': 'mon', 'l': 'T2'}, {'k': 'tue', 'l': 'T3'}, {'k': 'wed', 'l': 'T4'},
      {'k': 'thu', 'l': 'T5'}, {'k': 'fri', 'l': 'T6'}, {'k': 'sat', 'l': 'T7'}, {'k': 'sun', 'l': 'CN'}
    ];
    return Row(
      children: days.map((d) {
        final v = shift[d['k']] ?? ShiftValue.full;
        final cfg = _getShiftConfig(v);
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 1),
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(color: cfg.bgColor, borderRadius: BorderRadius.circular(4)),
            alignment: Alignment.center,
            child: Text(d['l']!, style: TextStyle(color: cfg.color, fontSize: 9, fontWeight: FontWeight.bold)),
          ),
        );
      }).toList(),
    );
  }
}

// --- FORM BOTTOM SHEET ---

class _StaffFormSheet extends StatefulWidget {
  final StaffMember? initialStaff;
  final Function(StaffMember) onSave;

  const _StaffFormSheet({this.initialStaff, required this.onSave});

  @override
  State<_StaffFormSheet> createState() => _StaffFormSheetState();
}

class _StaffFormSheetState extends State<_StaffFormSheet> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  String _role = '';
  StaffStatus _status = StaffStatus.available;
  String _color = '#148a9c';
  List<String> _specialties = [];
  Map<String, ShiftValue> _shift = {
    'mon': ShiftValue.full, 'tue': ShiftValue.full, 'wed': ShiftValue.full,
    'thu': ShiftValue.full, 'fri': ShiftValue.full, 'sat': ShiftValue.morning, 'sun': ShiftValue.off,
  };

  final _colors = ['#148a9c', '#14b8a6', '#f97316', '#3b82f6', '#ec4899', '#22c55e', '#eab308'];
  final _roles = ["Chuyên gia da mặt", "Chuyên gia da liễu", "Massage", "Chăm sóc tóc", "Nail & Móng tay", "Trang điểm", "Lễ tân", "Quản lý", "Khác"];
  final _allSpecialties = ["Chuyên gia da liễu", "Kỹ thuật viên", "Massage trị liệu", "Tẩy trắng", "Trị mụn chuyên sâu", "Phun xăm", "Nail Art", "Chăm sóc tóc", "Trang điểm cô dâu"];

  @override
  void initState() {
    super.initState();
    if (widget.initialStaff != null) {
      final s = widget.initialStaff!;
      _nameCtrl.text = s.name;
      _phoneCtrl.text = s.phone;
      _emailCtrl.text = s.email;
      _role = s.role;
      _status = s.status;
      _color = s.color;
      _specialties = List.from(s.specialties);
      _shift = Map.from(s.shift);
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
                Text(widget.initialStaff == null ? 'Thêm nhân viên mới' : 'Chỉnh sửa nhân viên', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                _IconButton(icon: Icons.close, onTap: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 16),

            _buildLabel('Họ và tên *'),
            _buildTextField(_nameCtrl, Icons.person_outline, 'Nhập họ và tên'),

            _buildLabel('Vai trò / Chuyên môn *'),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  hint: const Text('Chọn vai trò', style: TextStyle(fontSize: 14)),
                  value: _role.isEmpty ? null : _role,
                  items: _roles.map((r) => DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: 14)))).toList(),
                  onChanged: (v) => setState(() => _role = v ?? ''),
                ),
              ),
            ),

            Row(
              children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_buildLabel('Số điện thoại'), _buildTextField(_phoneCtrl, Icons.phone_outlined, '09xxxx')])),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_buildLabel('Email'), _buildTextField(_emailCtrl, Icons.mail_outline, 'email@...')])),
              ],
            ),

            _buildLabel('Trạng thái'),
            Row(
              children: StaffStatus.values.map((s) {
                final cfg = _getStatusConfig(s);
                final isActive = _status == s;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _status = s),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isActive ? cfg.bgColor : Colors.grey.shade50,
                        border: Border.all(color: isActive ? cfg.color : Colors.transparent),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(cfg.label, style: TextStyle(fontSize: 12, color: isActive ? cfg.color : Colors.grey, fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
                    ),
                  ),
                );
              }).toList(),
            ),

            _buildLabel('Tay nghề / Chuyên môn'),
            Wrap(
              spacing: 6, runSpacing: 6,
              children: _allSpecialties.map((s) {
                final isActive = _specialties.contains(s);
                return GestureDetector(
                  onTap: () {
                    setState(() { isActive ? _specialties.remove(s) : _specialties.add(s); });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isActive ? const Color(0xFFe0f8fc) : Colors.white,
                      border: Border.all(color: isActive ? const Color(0xFF148a9c) : Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(s, style: TextStyle(fontSize: 11, color: isActive ? const Color(0xFF148a9c) : Colors.grey.shade600, fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
                  ),
                );
              }).toList(),
            ),

            _buildLabel('Lịch trực trong tuần'),
            ...['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'].map((day) {
              final labels = {'mon': 'T2', 'tue': 'T3', 'wed': 'T4', 'thu': 'T5', 'fri': 'T6', 'sat': 'T7', 'sun': 'CN'};
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    SizedBox(width: 32, child: Text(labels[day]!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                    Expanded(
                      child: Row(
                        children: ShiftValue.values.map((v) {
                          final cfg = _getShiftConfig(v);
                          final isActive = _shift[day] == v;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _shift[day] = v),
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 2),
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                decoration: BoxDecoration(
                                  color: isActive ? cfg.bgColor : Colors.grey.shade50,
                                  border: Border.all(color: isActive ? cfg.color.withOpacity(0.5) : Colors.transparent),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                alignment: Alignment.center,
                                child: Text(cfg.label, style: TextStyle(fontSize: 10, color: isActive ? cfg.color : Colors.grey, fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    )
                  ],
                ),
              );
            }).toList(),

            _buildLabel('Màu hiển thị'),
            Row(
              children: _colors.map((c) => GestureDetector(
                onTap: () => setState(() => _color = c),
                child: Container(
                  margin: const EdgeInsets.only(right: 10),
                  width: 32, height: 32,
                  decoration: BoxDecoration(color: Color(int.parse(c.replaceFirst('#', '0xFF'))), shape: BoxShape.circle),
                  child: _color == c ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
                ),
              )).toList(),
            ),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton(
                onPressed: () {
                  if (_nameCtrl.text.trim().isEmpty || _role.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Vui lòng nhập tên và vai trò nhân viên.'),
                      ),
                    );
                    return;
                  }
                  widget.onSave(StaffMember(
                    id: widget.initialStaff?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                    name: _nameCtrl.text.trim(),
                    role: _role,
                    phone: _phoneCtrl.text.trim(),
                    email: _emailCtrl.text.trim(),
                    status: _status,
                    color: _color,
                    specialties: _specialties,
                    shift: _shift,
                  ));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF22AFC2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: Text(widget.initialStaff == null ? 'Thêm nhân viên' : 'Lưu thay đổi', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) => Padding(padding: const EdgeInsets.only(top: 16, bottom: 6), child: Text(text, style: const TextStyle(fontSize: 12, color: Colors.grey)));

  Widget _buildTextField(TextEditingController ctrl, IconData icon, String hint) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontSize: 14, color: Colors.grey.shade400),
        prefixIcon: Icon(icon, size: 18, color: Colors.grey.shade400),
        filled: true, fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF22AFC2))),
      ),
    );
  }
}

// --- HELPER CLASSES & CONFIGS ---

class _StatCard extends StatelessWidget {
  final int value; final String label; final Color color; final Color bgColor;
  const _StatCard({required this.value, required this.label, required this.color, required this.bgColor});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(16)),
        child: Column(
          children: [
            Text('$value', style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold)),
            Text(label, style: TextStyle(color: color.withOpacity(0.8), fontSize: 11)),
          ],
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

class _ActionBtn extends StatelessWidget {
  final IconData icon; final Color color; final Color bgColor; final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.color, required this.bgColor, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28, height: 28,
        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 14, color: color),
      ),
    );
  }
}

class _StatusConfig {
  final String label; final Color color; final Color bgColor;
  _StatusConfig(this.label, this.color, this.bgColor);
}
_StatusConfig _getStatusConfig(StaffStatus status) {
  switch (status) {
    case StaffStatus.available: return _StatusConfig('Sẵn sàng', const Color(0xFF63cd5b), const Color(0xFFe1ffde));
    case StaffStatus.inSession: return _StatusConfig('Trong phiên', const Color(0xFFd29430), const Color(0xFFffe9ad));
    case StaffStatus.absent: return _StatusConfig('Vắng mặt', const Color(0xFFd29430), const Color(0xFFffe9ad));
  }
}

class _ShiftConfig {
  final String label; final Color color; final Color bgColor;
  _ShiftConfig(this.label, this.color, this.bgColor);
}
_ShiftConfig _getShiftConfig(ShiftValue val) {
  switch (val) {
    case ShiftValue.morning: return _ShiftConfig('Sáng', const Color(0xFFd97706), const Color(0xFFfef3c7));
    case ShiftValue.afternoon: return _ShiftConfig('Chiều', const Color(0xFF2563eb), const Color(0xFFdbeafe));
    case ShiftValue.full: return _ShiftConfig('Cả ngày', const Color(0xFF148a9c), const Color(0xFFe0f8fc));
    case ShiftValue.off: return _ShiftConfig('Nghỉ', const Color(0xFF9ca3af), const Color(0xFFf3f4f6));
  }
}
