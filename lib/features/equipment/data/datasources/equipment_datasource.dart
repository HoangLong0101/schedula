import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';
import '../../domain/entities/equipment.dart';
import '../models/equipment_model.dart';

@lazySingleton
class EquipmentDataSource {
  EquipmentDataSource(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _equipment =>
      _firestore.collection('equipment');

  Stream<List<EquipmentModel>> watchEquipment(String tenantId) {
    return _equipment
        .where('tenantId', isEqualTo: tenantId)
        .snapshots()
        .map((snapshot) =>
        snapshot.docs.map(EquipmentModel.fromFirestore).toList());
  }

  Future<EquipmentModel> createEquipment(String tenantId, Equipment equip) async {
    final docRef = _equipment.doc();

    final model = EquipmentModel(
      id: docRef.id, name: equip.name, status: equip.status,
      location: equip.location, lastMaintenance: equip.lastMaintenance,
      quantity: equip.quantity,
    );

    final data = model.toFirestore();
    data['tenantId'] = tenantId;
    data['createdAt'] = FieldValue.serverTimestamp();

    await docRef.set(data);
    return model;
  }

  Future<void> updateEquipment(Equipment equip) async {
    final model = EquipmentModel(
      id: equip.id, name: equip.name, status: equip.status,
      location: equip.location, lastMaintenance: equip.lastMaintenance,
      quantity: equip.quantity,
    );
    await _equipment.doc(equip.id).update(model.toFirestore());
  }

  Future<void> deleteEquipment(String id) async {
    await _equipment.doc(id).delete();
  }
}