import * as admin from 'firebase-admin';
import { FieldValue } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

if (admin.apps.length === 0) admin.initializeApp();
const db = admin.firestore();

export const updateOwnProfile = onCall(
  { region: 'asia-southeast1' },
  async (request) => {
    const uid = request.auth?.uid;
    const tenantId = request.auth?.token?.tenantId;
    if (!uid || typeof tenantId !== 'string') {
      throw new HttpsError('unauthenticated', 'Vui lòng đăng nhập');
    }
    const data = request.data as {
      name?: string;
      phone?: string;
      avatarUrl?: string;
    };
    const before = await db.collection('users').doc(uid).get();
    if (!before.exists || before.data()?.tenantId !== tenantId) {
      throw new HttpsError('permission-denied', 'Không đúng cơ sở');
    }
    const update = {
      ...(typeof data.name === 'string' ? { name: data.name.trim() } : {}),
      ...(typeof data.phone === 'string' ? { phone: data.phone.trim() } : {}),
      ...(typeof data.avatarUrl === 'string'
        ? { avatarUrl: data.avatarUrl.trim() }
        : {}),
      updatedAt: FieldValue.serverTimestamp(),
    };
    const batch = db.batch();
    batch.update(before.ref, update);
    batch.set(db.collection('auditEvents').doc(), {
      tenantId,
      actorId: uid,
      actorRole: request.auth!.token.role ?? 'staff',
      entityType: 'user',
      entityId: uid,
      action: 'account.updated',
      before: before.data(),
      after: update,
      createdAt: FieldValue.serverTimestamp(),
    });
    await batch.commit();
    return { success: true };
  },
);

export const recordPasswordChange = onCall(
  { region: 'asia-southeast1' },
  async (request) => {
    const uid = request.auth?.uid;
    const tenantId = request.auth?.token?.tenantId;
    if (!uid || typeof tenantId !== 'string') {
      throw new HttpsError('unauthenticated', 'Vui lòng đăng nhập');
    }
    await db.collection('auditEvents').add({
      tenantId,
      actorId: uid,
      actorRole: request.auth!.token.role ?? 'staff',
      entityType: 'user',
      entityId: uid,
      action: 'account.password_changed',
      createdAt: FieldValue.serverTimestamp(),
    });
    return { success: true };
  },
);
