import * as admin from 'firebase-admin';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

if (admin.apps.length === 0) {
  admin.initializeApp();
}

type SetUserRoleData = {
  uid: string;
  role: 'owner' | 'receptionist' | 'staff';
};

export const setUserRole = onCall(async (request) => {
  if (request.auth?.token?.role !== 'owner') {
    throw new HttpsError('permission-denied', 'Chỉ chủ cơ sở được thực hiện');
  }

  const { uid, role } = request.data as SetUserRoleData;
  const tenantId = request.auth.token.tenantId;
  if (
    !uid ||
    typeof tenantId !== 'string' ||
    !['receptionist', 'staff'].includes(role)
  ) {
    throw new HttpsError('invalid-argument', 'Thông tin phân quyền không hợp lệ');
  }

  const userRef = admin.firestore().collection('users').doc(uid);
  const snapshot = await userRef.get();
  if (!snapshot.exists || snapshot.data()?.tenantId !== tenantId) {
    throw new HttpsError('not-found', 'Không tìm thấy người dùng trong cơ sở');
  }
  const permissions = role === 'receptionist'
    ? [
      'booking.manage',
      'customer.read',
      'customer.write',
      'campaign.send',
      'report.read',
    ]
    : ['booking.status.own', 'customer.read'];
  await admin.auth().setCustomUserClaims(uid, {
    role,
    tenantId,
    permissions,
  });
  const batch = admin.firestore().batch();
  batch.update(userRef, {
    role,
    permissions,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  batch.set(admin.firestore().collection('auditEvents').doc(), {
    tenantId,
    actorId: request.auth.uid,
    actorRole: 'owner',
    entityType: 'user',
    entityId: uid,
    action: 'permission.changed',
    before: { role: snapshot.data()?.role ?? null },
    after: { role, permissions },
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  await batch.commit();
  return { success: true };
});
