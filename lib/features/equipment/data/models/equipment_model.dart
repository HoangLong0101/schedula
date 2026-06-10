import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/equipment.dart';

class EquipmentModel extends Equipment {
  const EquipmentModel({
    required super.id,
    required super.name,
    required super.status,
    required super.location,
    required super.lastMaintenance,
    super.quantity,
  });

  factory EquipmentModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};

    // Chuyển đổi Timestamp sang String (yyyy-MM-dd)
    String lastMaintenanceStr = '';
    final ts = data['lastMaintenance'] as Timestamp?;
    if (ts != null) {
      lastMaintenanceStr = ts.toDate().toIso8601String().split('T')[0];
    }

    return EquipmentModel(
      id: doc.id,
      name: data['name'] as String? ?? '',
      status: _statusFromString(data['status'] as String?),
      location: data['location'] as String? ?? '',
      lastMaintenance: lastMaintenanceStr,
      quantity: data['quantity'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toFirestore() {
    DateTime? maintenanceDate;
    try {
      maintenanceDate = DateTime.parse(lastMaintenance);
    } catch (_) {
      maintenanceDate = DateTime.now();
    }

    return {
      'name': name,
      'status': _statusToString(status),
      'location': location,
      'lastMaintenance': Timestamp.fromDate(maintenanceDate),
      'quantity': quantity,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static EquipmentStatus _statusFromString(String? val) {
    switch (val) {
      case 'in_use': return EquipmentStatus.inUse;
      case 'maintenance': return EquipmentStatus.maintenance;
      case 'available':
      default: return EquipmentStatus.available;
    }
  }

  static String _statusToString(EquipmentStatus status) {
    switch (status) {
      case EquipmentStatus.inUse: return 'in_use';
      case EquipmentStatus.maintenance: return 'maintenance';
      case EquipmentStatus.available: return 'available';
    }
  }
}