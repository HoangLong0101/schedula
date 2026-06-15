import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../domain/entities/equipment.dart';
import '../cubit/equipment_management_cubit.dart';

class EquipmentPage extends StatelessWidget {
  const EquipmentPage({super.key});

  static const routePath = '/equipment';
  static const routeName = 'equipment';

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    final tenantId = authState is Authenticated ? authState.user.tenantId : '';

    if (tenantId.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('Lỗi: Không tìm thấy mã cơ sở')),
      );
    }

    return BlocProvider(
      create: (_) => getIt<EquipmentManagementCubit>()..init(tenantId),
      child: const _EquipmentView(),
    );
  }
}

class _EquipmentView extends StatefulWidget {
  const _EquipmentView();

  @override
  State<_EquipmentView> createState() => _EquipmentViewState();
}

class _EquipmentViewState extends State<_EquipmentView> {
  String _searchQuery = '';

  void _showForm(BuildContext context, {Equipment? equip}) {
    final cubit = context.read<EquipmentManagementCubit>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EquipmentFormSheet(
        initialEquipment: equip,
        onSave: (newEquip) {
          if (equip == null) {
            cubit.addEquipment(newEquip);
          } else {
            cubit.updateEquipment(newEquip);
          }
          Navigator.pop(ctx);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFf0f9fa),
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
                  _IconButton(icon: Icons.chevron_left, onTap: () => context.pop()),
                  const Text('Quản lý Thiết bị', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
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
              child: BlocBuilder<EquipmentManagementCubit, List<Equipment>>(
                builder: (context, equipmentList) {
                  // Lọc dữ liệu
                  final filtered = equipmentList.where((e) {
                    final query = _searchQuery.toLowerCase();
                    return e.name.toLowerCase().contains(query) || e.location.toLowerCase().contains(query);
                  }).toList();

                  // Thống kê
                  final countAvailable = equipmentList.where((e) => e.status == EquipmentStatus.available).length;
                  final countInUse = equipmentList.where((e) => e.status == EquipmentStatus.inUse).length;

                  return ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    children: [
                      // Thanh tìm kiếm
                      Container(
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4)]),
                        child: TextField(
                          onChanged: (val) => setState(() => _searchQuery = val),
                          decoration: InputDecoration(
                            hintText: 'Tìm theo tên hoặc vị trí...',
                            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                            prefixIcon: Icon(Icons.search, size: 20, color: Colors.grey.shade400),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Stats
                      Row(
                        children: [
                          _StatCard(label: 'Tổng', count: equipmentList.length, color: const Color(0xFF148a9c)),
                          const SizedBox(width: 8),
                          _StatCard(label: 'Sẵn sàng', count: countAvailable, color: const Color(0xFF22c55e)),
                          const SizedBox(width: 8),
                          _StatCard(label: 'Đang dùng', count: countInUse, color: const Color(0xFFf97316)),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Danh sách
                      if (filtered.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 40),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.inventory_2_outlined, size: 40, color: Colors.grey),
                                SizedBox(height: 8),
                                Text('Không tìm thấy thiết bị', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        )
                      else
                        ...filtered.map((e) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _EquipmentCard(
                            equip: e,
                            onEdit: () => _showForm(context, equip: e),
                            onDelete: () => context.read<EquipmentManagementCubit>().deleteEquipment(e.id),
                            onChangeStatus: (newStatus) => context.read<EquipmentManagementCubit>().updateStatus(e.id, newStatus),
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

// --- WIDGET THẺ THIẾT BỊ ---
class _EquipmentCard extends StatelessWidget {
  final Equipment equip;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Function(EquipmentStatus) onChangeStatus;

  const _EquipmentCard({required this.equip, required this.onEdit, required this.onDelete, required this.onChangeStatus});

  @override
  Widget build(BuildContext context) {
    final cfg = _getStatusConfig(equip.status);

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
                decoration: BoxDecoration(color: const Color(0xFF148a9c).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                alignment: Alignment.center,
                child: const Icon(Icons.inventory_2_outlined, color: Color(0xFF148a9c), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(equip.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(equip.location, style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                    if (equip.quantity > 1) ...[
                      const SizedBox(height: 4),
                      Text('Số lượng: ${equip.quantity}', style: const TextStyle(fontSize: 12, color: Color(0xFF148a9c), fontWeight: FontWeight.w700)),
                    ]
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: cfg.bgColor, borderRadius: BorderRadius.circular(99)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(cfg.icon, size: 12, color: cfg.color),
                    const SizedBox(width: 4),
                    Text(cfg.label, style: TextStyle(color: cfg.color, fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              )
            ],
          ),

          // Lịch bảo trì
          Container(
            margin: const EdgeInsets.only(top: 12), padding: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade100))),
            child: Row(
              children: [
                Text('Bảo trì lần cuối: ', style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
                Text(equip.lastMaintenance, style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w700)),
              ],
            ),
          ),

          // Nút hành động
          if (equip.status != EquipmentStatus.maintenance) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (equip.status == EquipmentStatus.available)
                  Expanded(
                    child: _ActionButton(
                      label: 'Đánh dấu đang dùng',
                      color: Colors.orange.shade600,
                      bgColor: Colors.orange.shade50,
                      onTap: () => onChangeStatus(EquipmentStatus.inUse),
                    ),
                  ),
                if (equip.status == EquipmentStatus.inUse)
                  Expanded(
                    child: _ActionButton(
                      label: 'Đánh dấu sẵn sàng',
                      color: Colors.green.shade600,
                      bgColor: Colors.green.shade50,
                      onTap: () => onChangeStatus(EquipmentStatus.available),
                    ),
                  ),
                const SizedBox(width: 8),
                _ActionBtn(icon: Icons.edit_outlined, color: Colors.grey.shade600, bgColor: Colors.grey.shade50, onTap: onEdit),
                const SizedBox(width: 8),
                _ActionBtn(icon: Icons.delete_outline, color: Colors.red.shade400, bgColor: Colors.red.shade50, onTap: onDelete),
              ],
            )
          ]
        ],
      ),
    );
  }
}

// --- BOTTOM SHEET FORM ---
class _EquipmentFormSheet extends StatefulWidget {
  final Equipment? initialEquipment;
  final Function(Equipment) onSave;

  const _EquipmentFormSheet({this.initialEquipment, required this.onSave});

  @override
  State<_EquipmentFormSheet> createState() => _EquipmentFormSheetState();
}

class _EquipmentFormSheetState extends State<_EquipmentFormSheet> {
  final _nameCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');

  @override
  void initState() {
    super.initState();
    if (widget.initialEquipment != null) {
      _nameCtrl.text = widget.initialEquipment!.name;
      _locationCtrl.text = widget.initialEquipment!.location;
      _qtyCtrl.text = widget.initialEquipment!.quantity.toString();
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
                Text(widget.initialEquipment == null ? 'Thêm thiết bị mới' : 'Chỉnh sửa thiết bị', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                _IconButton(icon: Icons.close, onTap: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 16),

            _buildField('Tên thiết bị', _nameCtrl, 'VD: Máy Laser CO2, Giường massage...'),
            _buildField('Vị trí / Phòng', _locationCtrl, 'VD: Phòng 1, Khu A...'),
            _buildField('Số lượng', _qtyCtrl, '1', TextInputType.number),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton(
                onPressed: () {
                  final quantity = int.tryParse(_qtyCtrl.text.trim()) ?? 0;
                  if (_nameCtrl.text.trim().isEmpty || quantity <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Vui lòng nhập tên thiết bị và số lượng hợp lệ.',
                        ),
                      ),
                    );
                    return;
                  }
                  widget.onSave(Equipment(
                    id: widget.initialEquipment?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                    name: _nameCtrl.text.trim(),
                    location: _locationCtrl.text.trim(),
                    quantity: quantity,
                    status: widget.initialEquipment?.status ?? EquipmentStatus.available,
                    lastMaintenance: widget.initialEquipment?.lastMaintenance ?? DateTime.now().toIso8601String().split('T')[0],
                  ));
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF22AFC2), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                child: Text(widget.initialEquipment == null ? 'Thêm thiết bị' : 'Lưu thay đổi', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, String hint, [TextInputType type = TextInputType.text]) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
          const SizedBox(height: 8),
          TextField(
            controller: ctrl, keyboardType: type,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(fontSize: 14, color: Colors.grey.shade400),
              filled: true, fillColor: Colors.grey.shade50,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF22AFC2))),
            ),
          ),
        ],
      ),
    );
  }
}

// --- HELPER COMPONENTS ---

class _StatCard extends StatelessWidget {
  final String label; final int count; final Color color;
  const _StatCard({required this.label, required this.count, required this.color});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4)]),
        child: Column(
          children: [
            Text('$count', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color, height: 1)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color.withOpacity(0.8))),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label; final Color color; final Color bgColor; final VoidCallback onTap;
  const _ActionButton({required this.label, required this.color, required this.bgColor, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
        child: Center(child: Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold))),
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
        padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 16, color: color),
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
  final String label; final Color color; final Color bgColor; final IconData icon;
  _StatusConfig(this.label, this.color, this.bgColor, this.icon);
}

_StatusConfig _getStatusConfig(EquipmentStatus status) {
  switch (status) {
    case EquipmentStatus.available: return _StatusConfig('Sẵn sàng', const Color(0xFF16a34a), const Color(0xFFf0fdf4), Icons.check_circle_outline);
    case EquipmentStatus.inUse: return _StatusConfig('Đang dùng', const Color(0xFFea580c), const Color(0xFFfff7ed), Icons.schedule);
    case EquipmentStatus.maintenance: return _StatusConfig('Bảo trì', const Color(0xFFef4444), const Color(0xFFfef2f2), Icons.warning_amber_rounded);
  }
}
