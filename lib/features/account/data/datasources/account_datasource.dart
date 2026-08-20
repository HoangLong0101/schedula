import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:injectable/injectable.dart';

import '../../domain/entities/business_info.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/entities/audit_event.dart';
import '../model/business_info_model.dart';

@lazySingleton
class AccountDataSource {
  AccountDataSource(this._firestore, this._auth, this._storage);

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseStorage _storage;
  FirebaseFunctions get _functions =>
      FirebaseFunctions.instanceFor(region: 'asia-southeast1');

  DocumentReference<Map<String, dynamic>> _tenantDoc(String tenantId) =>
      _firestore.collection('tenants').doc(tenantId);

  Stream<BusinessInfoModel> watchBusinessInfo(String tenantId) {
    return _tenantDoc(tenantId).snapshots().map((snapshot) {
      if (!snapshot.exists) {
        return const BusinessInfoModel(
          name: 'Chưa cập nhật tên',
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
    final data = model.toFirestore();
    data['bookingPolicy'] = {
      'timezone': 'Asia/Ho_Chi_Minh',
      'weekdayHours': info.hoursWeekday,
      'weekendHours': info.hoursWeekend,
    };
    await _tenantDoc(tenantId).set(data, SetOptions(merge: true));
  }

  Stream<UserProfile> watchUserProfile(String userId, String defaultEmail) {
    return _firestore.collection('users').doc(userId).snapshots().map((
      snapshot,
    ) {
      final data = snapshot.data() ?? const <String, dynamic>{};
      final user = _auth.currentUser;
      final passwordEnabled =
          user?.providerData.any(
            (provider) => provider.providerId == 'password',
          ) ??
          false;
      return UserProfile(
        name: data['name'] as String? ?? user?.displayName ?? '',
        phone: data['phone'] as String? ?? '',
        email: user?.email ?? data['email'] as String? ?? defaultEmail,
        avatarUrl: data['avatarUrl'] as String? ?? user?.photoURL,
        passwordEnabled: passwordEnabled,
      );
    });
  }

  Future<void> updateUserProfile(String userId, UserProfile profile) async {
    await _functions.httpsCallable('updateOwnProfile').call({
      'name': profile.name.trim(),
      'phone': profile.phone.trim(),
    });
    await _auth.currentUser?.updateDisplayName(profile.name.trim());
  }

  Future<String> uploadAvatar(
    String userId,
    Uint8List bytes,
    String contentType,
  ) async {
    final reference = _storage.ref('users/$userId/avatar/profile');
    await reference.putData(bytes, SettableMetadata(contentType: contentType));
    final url = await reference.getDownloadURL();
    await _functions.httpsCallable('updateOwnProfile').call({'avatarUrl': url});
    await _auth.currentUser?.updatePhotoURL(url);
    return url;
  }

  Future<void> changePassword(
    String email,
    String currentPassword,
    String newPassword,
  ) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw FirebaseAuthException(code: 'user-not-found');
    }
    final credential = EmailAuthProvider.credential(
      email: email,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(newPassword);
    await _functions.httpsCallable('recordPasswordChange').call();
    await user.getIdTokenResult(true);
  }

  Stream<List<AuditEvent>> watchAuditEvents(String tenantId) {
    return _firestore
        .collection('auditEvents')
        .where('tenantId', isEqualTo: tenantId)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((document) {
                final data = document.data();
                return AuditEvent(
                  id: document.id,
                  actorId: data['actorId'] as String? ?? '',
                  entityType: data['entityType'] as String? ?? '',
                  entityId: data['entityId'] as String? ?? '',
                  action: data['action'] as String? ?? '',
                  createdAt:
                      (data['createdAt'] as Timestamp?)?.toDate() ??
                      DateTime.fromMillisecondsSinceEpoch(0),
                  status: data['status'] as String? ?? 'succeeded',
                  before: (data['before'] as Map?)?.cast<String, dynamic>(),
                  after: (data['after'] as Map?)?.cast<String, dynamic>(),
                );
              })
              .toList(growable: false),
        );
  }

  Future<List<CampaignRecipient>> getEligibleCampaignRecipients(
    String tenantId,
  ) async {
    final snapshot = await _firestore
        .collection('customers')
        .where('tenantId', isEqualTo: tenantId)
        .get();
    final now = DateTime.now();
    return snapshot.docs
        .where((document) {
          final data = document.data();
          return data['emailMarketingConsent'] == true &&
              data['emailOptedOut'] != true &&
              (data['email'] as String? ?? '').contains('@');
        })
        .map((document) {
          final data = document.data();
          final birthday = DateTime.tryParse(data['birthday'] as String? ?? '');
          final lastVisit = (data['lastVisit'] as Timestamp?)?.toDate();
          var reason = 'Chăm sóc lại';
          if (birthday != null) {
            var next = DateTime(now.year, birthday.month, birthday.day);
            if (next.isBefore(DateTime(now.year, now.month, now.day))) {
              next = DateTime(now.year + 1, birthday.month, birthday.day);
            }
            if (next.difference(now).inDays <= 14) reason = 'Sinh nhật';
          }
          if (reason != 'Sinh nhật' &&
              lastVisit != null &&
              now.difference(lastVisit).inDays < 30) {
            reason = '';
          }
          return CampaignRecipient(
            id: document.id,
            name: data['name'] as String? ?? '',
            email: data['email'] as String? ?? '',
            reason: reason,
          );
        })
        .where((recipient) => recipient.reason.isNotEmpty)
        .toList(growable: false);
  }

  Future<Map<String, int>> sendCampaign(
    String templateId,
    String subject,
    String body,
    List<String> recipientIds,
  ) async {
    final result = await _functions.httpsCallable('sendCampaign').call({
      'templateId': templateId,
      'subject': subject,
      'body': body,
      'recipientIds': recipientIds,
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    return {
      'sent': data['sent'] as int? ?? 0,
      'failed': data['failed'] as int? ?? 0,
    };
  }

  Stream<List<CampaignRecord>> watchCampaigns(String tenantId) {
    return _firestore
        .collection('campaigns')
        .where('tenantId', isEqualTo: tenantId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((document) {
                final data = document.data();
                return CampaignRecord(
                  id: document.id,
                  templateId: data['templateId'] as String? ?? '',
                  subject: data['subject'] as String? ?? '',
                  body: data['body'] as String? ?? '',
                  status: data['status'] as String? ?? '',
                  recipientCount: data['recipientCount'] as int? ?? 0,
                  sent: data['sent'] as int? ?? 0,
                  failed: data['failed'] as int? ?? 0,
                  createdAt:
                      (data['createdAt'] as Timestamp?)?.toDate() ??
                      DateTime.fromMillisecondsSinceEpoch(0),
                );
              })
              .toList(growable: false),
        );
  }

  Stream<List<CampaignDelivery>> watchCampaignDeliveries(String tenantId) {
    return _firestore
        .collection('campaignDeliveries')
        .where('tenantId', isEqualTo: tenantId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((document) {
                final data = document.data();
                return CampaignDelivery(
                  id: document.id,
                  campaignId: data['campaignId'] as String? ?? '',
                  customerId: data['customerId'] as String? ?? '',
                  email: data['email'] as String? ?? '',
                  status: data['status'] as String? ?? '',
                  reason: data['reason'] as String? ?? '',
                  createdAt:
                      (data['createdAt'] as Timestamp?)?.toDate() ??
                      DateTime.fromMillisecondsSinceEpoch(0),
                );
              })
              .toList(growable: false),
        );
  }
}
