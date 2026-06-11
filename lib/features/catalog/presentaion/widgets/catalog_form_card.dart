import 'package:flutter/material.dart';
import '../../domain/entities/product_item.dart';
import '../../domain/entities/service_item.dart';
import '../cubit/catalog_state.dart';

class CatalogFormCard extends StatefulWidget {
  final CatalogTab tab;
  final dynamic editingItem;
  final Function() onCancel;
  final Function(Map<String, dynamic>) onSave;

  const CatalogFormCard({super.key, required this.tab, this.editingItem, required this.onCancel, required this.onSave});

  @override
  State<CatalogFormCard> createState() => _CatalogFormCardState();
}

class _CatalogFormCardState extends State<CatalogFormCard> {
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _extraCtrl = TextEditingController(); // Thời gian hoặc Đơn vị
  final _catCtrl = TextEditingController();
  List<String> selectedResources = [];

  final resourceOptions = ["Giường", "Máy xông tinh dầu", "Máy hấp tóc", "Máy massage", "Máy phun sương", "Bàn nail", "Phòng riêng"];

  @override
  void initState() {
    super.initState();
    if (widget.editingItem != null) {
      if (widget.tab == CatalogTab.service) {
        final s = widget.editingItem as ServiceItem;
        _nameCtrl.text = s.name; _priceCtrl.text = s.price.toString();
        _extraCtrl.text = s.duration.toString(); _catCtrl.text = s.category;
        selectedResources = List.from(s.resources);
      } else {
        final p = widget.editingItem as ProductItem;
        _nameCtrl.text = p.name; _priceCtrl.text = p.price.toString();
        _extraCtrl.text = p.unit; _catCtrl.text = p.category;
      }
    } else {
      if (widget.tab == CatalogTab.product) _extraCtrl.text = 'Lọ';
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = const Color(0xFF8B5CF6);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFFF5F3FF), borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFDDD6FE))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.editingItem == null ? 'Thêm mới' : 'Chỉnh sửa', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF6D28D9))),
          const SizedBox(height: 10),
          _buildField('Tên *', _nameCtrl),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildField('Giá (VNĐ)', _priceCtrl, TextInputType.number)),
              const SizedBox(width: 8),
              Expanded(child: _buildField(widget.tab == CatalogTab.service ? 'Thời gian (phút)' : 'Đơn vị', _extraCtrl, widget.tab == CatalogTab.service ? TextInputType.number : TextInputType.text)),
            ],
          ),
          const SizedBox(height: 8),
          _buildField('Danh mục', _catCtrl),
          if (widget.tab == CatalogTab.service) ...[
            const SizedBox(height: 12),
            const Text('Tài nguyên yêu cầu', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF6D28D9))),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6, runSpacing: 6,
              children: resourceOptions.map((r) {
                final active = selectedResources.contains(r);
                return InkWell(
                  onTap: () => setState(() => active ? selectedResources.remove(r) : selectedResources.add(r)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: active ? const Color(0xFFEDE9FE) : Colors.white, borderRadius: BorderRadius.circular(99), border: Border.all(color: active ? themeColor : Colors.grey.shade300)),
                    child: Text(r, style: TextStyle(fontSize: 10, color: active ? const Color(0xFF7C3AED) : Colors.grey.shade600, fontWeight: active ? FontWeight.bold : FontWeight.normal)),
                  ),
                );
              }).toList(),
            )
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: TextButton(onPressed: widget.onCancel, style: TextButton.styleFrom(backgroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Hủy', style: TextStyle(color: Colors.grey, fontSize: 12)))),
              const SizedBox(width: 8),
              Expanded(child: ElevatedButton(
                onPressed: () {
                  if (_nameCtrl.text.isEmpty) return;
                  widget.onSave({
                    'id': widget.editingItem?.id, 'name': _nameCtrl.text,
                    'price': int.tryParse(_priceCtrl.text) ?? 0, 'extra': _extraCtrl.text,
                    'category': _catCtrl.text, 'resources': selectedResources
                  });
                },
                style: ElevatedButton.styleFrom(backgroundColor: themeColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                child: const Text('Lưu', style: TextStyle(color: Colors.white, fontSize: 12)),
              )),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildField(String hint, TextEditingController ctrl, [TextInputType type = TextInputType.text]) {
    return TextField(
      controller: ctrl, keyboardType: type,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        hintText: hint, hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
        filled: true, fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFDDD6FE))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF8B5CF6))),
      ),
    );
  }
}