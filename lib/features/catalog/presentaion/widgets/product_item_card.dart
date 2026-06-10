import 'package:flutter/material.dart';
import '../../domain/entities/product_item.dart';

class ProductItemCard extends StatelessWidget {
  final ProductItem product;
  final Color themeColor;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const ProductItemCard({super.key, required this.product, required this.themeColor, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade100)),
      child: Row(
        children: [
          Container(width: 40, height: 40, decoration: BoxDecoration(color: themeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.card_giftcard, color: themeColor, size: 16)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text('${product.category} / ${product.unit}', style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(product.price >= 1000 ? '${(product.price / 1000).toStringAsFixed(0)}K ₫' : '${product.price} ₫', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: themeColor)),
              const SizedBox(height: 8),
              Row(
                children: [
                  IconButton(onPressed: onEdit, icon: const Icon(Icons.edit, size: 12, color: Colors.grey), constraints: const BoxConstraints(minWidth: 26, minHeight: 26), padding: EdgeInsets.zero, style: IconButton.styleFrom(backgroundColor: Colors.grey.shade50, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)))),
                  const SizedBox(width: 4),
                  IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_outline, size: 12, color: Colors.redAccent), constraints: const BoxConstraints(minWidth: 26, minHeight: 26), padding: EdgeInsets.zero, style: IconButton.styleFrom(backgroundColor: Color(0xFFFFEFEF), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)))),
                ],
              )
            ],
          )
        ],
      ),
    );
  }
}