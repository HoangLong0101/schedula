import 'package:flutter/material.dart';
import '../cubit/catalog_state.dart';

class CatalogTabs extends StatelessWidget {
  final CatalogTab activeTab;
  final Function(CatalogTab) onTabChanged;

  const CatalogTabs({super.key, required this.activeTab, required this.onTabChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          _buildTabButton('Dịch vụ', Icons.content_cut, CatalogTab.service),
          _buildTabButton('Sản phẩm', Icons.card_giftcard, CatalogTab.product),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, IconData icon, CatalogTab tab) {
    final isSelected = activeTab == tab;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTabChanged(tab),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)] : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: isSelected ? const Color(0xFF8B5CF6) : Colors.grey),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal, color: isSelected ? const Color(0xFF8B5CF6) : Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}