import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';

import '../../domain/entities/business_info.dart';
import '../model/business_info_model.dart';

@lazySingleton
class AccountDataSource {
  AccountDataSource(this._firestore);

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _tenantDoc(String tenantId) =>
      _firestore.collection('tenants').doc(tenantId);

  Stream<BusinessInfoModel> watchBusinessInfo(String tenantId) {
    return _tenantDoc(tenantId).snapshots().map((snapshot) {
      if (!snapshot.exists) {
        return const BusinessInfoModel(
          name: 'Chua cap nhat ten',
          type: 'Spa',
          address: '',
          phone: '',
          website: '',
          hoursWeekday: '',
          hoursWeekend: '',
          description: '',
          staffReminderLeadMinutes: 60,
        );
      }
      return BusinessInfoModel.fromFirestore(snapshot);
    });
  }

  Future<void> updateBusinessInfo(String tenantId, BusinessInfo info) async {
    final model = BusinessInfoModel(
      name: info.name,
      type: info.type,
      address: info.address,
      phone: info.phone,
      website: info.website,
      hoursWeekday: info.hoursWeekday,
      hoursWeekend: info.hoursWeekend,
      description: info.description,
      planTier: info.planTier,
      planStartedAt: info.planStartedAt,
      planExpiresAt: info.planExpiresAt,
      staffReminderLeadMinutes: info.staffReminderLeadMinutes,
    );
    await _tenantDoc(tenantId).set(model.toFirestore(), SetOptions(merge: true));
  }
}
