import 'package:flutter/material.dart';
import '../../domain/entities/service_item.dart';

class ServiceItemCard extends StatelessWidget {
  final ServiceItem service;
  final Color themeColor;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const ServiceItemCard({super.key, required this.service, required this.themeColor, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade100)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 40, height: 40, decoration: BoxDecoration(color: themeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.content_cut, color: themeColor, size: 16)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(service.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.local_offer_outlined, size: 10, color: Colors.grey.shade400),
                    const SizedBox(width: 4),
                    Text(service.category, style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
                    const SizedBox(width: 12),
                    Icon(Icons.access_time, size: 10, color: Colors.grey.shade400),
                    const SizedBox(width: 4),
                    Text('${service.duration} phút', style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
                  ],
                ),
                if (service.resources.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(spacing: 4, children: service.resources.map((r) => Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: const Color(0xFFEDE9FE), borderRadius: BorderRadius.circular(6)), child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.bed, size: 8, color: Color(0xFF7C3AED)), const SizedBox(width: 2), Text(r, style: const TextStyle(fontSize: 9, color: Color(0xFF7C3AED), fontWeight: FontWeight.bold))]))).toList()),
                ]
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(service.price >= 1000 ? '${(service.price / 1000).toStringAsFixed(0)}K ₫' : '${service.price} ₫', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: themeColor)),
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