import { randomBytes } from 'node:crypto';

import * as admin from 'firebase-admin';
import { FieldValue } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

if (admin.apps.length === 0) {
  admin.initializeApp();
}

const db = admin.firestore();

type CreateStaffData = {
  name?: string;
  email?: string;
  phone?: string;
  roleTitle?: string;
  status?: string;
  color?: string;
  specialties?: string[];
  shift?: Record<string, string>;
};

export const createStaffAccount = onCall(
  { region: 'asia-southeast1' },
  async (request) => {
    const tenantId = ownerTenantId(request.auth?.token);
    const data = request.data as CreateStaffData;
    const name = data.name?.trim();
    const email = data.email?.trim().toLowerCase();

    if (!name || !email || !email.includes('@')) {
      throw new HttpsError('invalid-argument', 'Valid name and email required');
    }

    const temporaryPassword = `Sc!${randomBytes(9).toString('base64url')}`;
    let uid: string | undefined;

    try {
      const user = await admin.auth().createUser({
        email,
        password: temporaryPassword,
        displayName: name,
      });
      uid = user.uid;
      await admin.auth().setCustomUserClaims(uid, { role: 'staff', tenantId });
      await db.collection('users').doc(uid).set({
        tenantId,
        role: 'staff',
        role_title: data.roleTitle?.trim() ?? '',
        name,
        email,
        phone: data.phone?.trim() ?? '',
        status: data.status ?? 'available',
        color: data.color ?? '#148a9c',
        specialties: data.specialties ?? [],
        shift: data.shift ?? {},
        appointments: 0,
        rating: 5,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      return { uid, temporaryPassword };
    } catch (error) {
      if (uid) {
        await admin.auth().deleteUser(uid).catch(() => undefined);
      }
      if (errorCode(error) === 'auth/email-already-exists') {
        throw new HttpsError('already-exists', 'Email already exists');
      }
      throw error;
    }
  },
);

export const deleteStaffAccount = onCall(
  { region: 'asia-southeast1' },
  async (request) => {
    const tenantId = ownerTenantId(request.auth?.token);
    const uid = (request.data as { uid?: string }).uid;
    if (!uid) {
      throw new HttpsError('invalid-argument', 'Staff uid required');
    }

    const ref = db.collection('users').doc(uid);
    const snapshot = await ref.get();
    if (!snapshot.exists ||
        snapshot.data()?.tenantId !== tenantId ||
        snapshot.data()?.role !== 'staff') {
      throw new HttpsError('not-found', 'Staff account not found');
    }

    await admin.auth().deleteUser(uid);
    await ref.delete();
    return { success: true };
  },
);

function ownerTenantId(
  token: Record<string, unknown> | undefined,
): string {
  if (token?.role !== 'owner' || typeof token.tenantId !== 'string') {
    throw new HttpsError('permission-denied', 'Owners only');
  }
  return token.tenantId;
}

function errorCode(error: unknown): unknown {
  return typeof error === 'object' && error !== null && 'code' in error
    ? (error as { code?: unknown }).code
    : undefined;
}
