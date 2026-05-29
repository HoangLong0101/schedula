import * as admin from 'firebase-admin';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

if (admin.apps.length === 0) {
  admin.initializeApp();
}

type SetUserRoleData = {
  uid: string;
  role: 'owner' | 'receptionist' | 'staff';
  tenantId: string;
};

export const setUserRole = onCall(async (request) => {
  if (request.auth?.token?.role !== 'owner') {
    throw new HttpsError('permission-denied', 'Owners only');
  }

  const { uid, role, tenantId } = request.data as SetUserRoleData;
  if (!uid || !tenantId || !['owner', 'receptionist', 'staff'].includes(role)) {
    throw new HttpsError('invalid-argument', 'Bad role payload');
  }

  await admin.auth().setCustomUserClaims(uid, { role, tenantId });
  return { success: true };
});