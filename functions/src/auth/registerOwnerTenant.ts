import * as admin from 'firebase-admin';
import { FieldValue } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

if (admin.apps.length === 0) {
  admin.initializeApp();
}

type RegisterOwnerTenantData = {
  email: string;
  password: string;
  ownerName: string;
  business: {
    name: string;
    type: string;
    address: string;
    phone: string;
    website?: string;
    hoursWeekday: string;
    hoursWeekend: string;
    description?: string;
  };
};

const db = admin.firestore();

export const registerOwnerTenant = onCall(
  { region: 'asia-southeast1' },
  async (request) => {
    const data = request.data as Partial<RegisterOwnerTenantData>;
    const email = data.email?.trim().toLowerCase();
    const password = data.password;
    const ownerName = data.ownerName?.trim();
    const business = data.business;

    if (!email || !password || !ownerName || !business) {
      throw new HttpsError('invalid-argument', 'Missing registration fields');
    }

    if (password.length < 8) {
      throw new HttpsError(
        'invalid-argument',
        'Password must be at least 8 characters',
      );
    }

    const requiredBusinessFields = [
      business.name,
      business.type,
      business.address,
      business.phone,
      business.hoursWeekday,
      business.hoursWeekend,
    ];

    if (requiredBusinessFields.some((value) => !value?.trim())) {
      throw new HttpsError('invalid-argument', 'Missing tenant fields');
    }

    const tenantRef = db.collection('tenants').doc();
    const tenantId = tenantRef.id;
    let uid: string | undefined;

    try {
      const userRecord = await admin.auth().createUser({
        email,
        password,
        displayName: ownerName,
      });
      uid = userRecord.uid;
      const createdUid = userRecord.uid;

      await admin.auth().setCustomUserClaims(createdUid, {
        role: 'owner',
        tenantId,
      });

      const now = FieldValue.serverTimestamp();
      await db.runTransaction(async (transaction) => {
        transaction.set(tenantRef, {
          tenantId,
          name: business.name.trim(),
          type: business.type.trim(),
          address: business.address.trim(),
          phone: business.phone.trim(),
          website: business.website?.trim() ?? '',
          hoursWeekday: business.hoursWeekday.trim(),
          hoursWeekend: business.hoursWeekend.trim(),
          description: business.description?.trim() ?? '',
          ownerUid: createdUid,
          createdAt: now,
          updatedAt: now,
        });

        transaction.set(db.collection('users').doc(createdUid), {
          tenantId,
          role: 'owner',
          name: ownerName,
          email,
          createdAt: now,
          updatedAt: now,
        });
      });

      return { success: true, uid, tenantId };
    } catch (error) {
      if (uid) {
        await admin.auth().deleteUser(uid).catch(() => undefined);
      }

      const errorCode =
        typeof error === 'object' && error !== null && 'code' in error
          ? (error as { code?: unknown }).code
          : undefined;

      if (errorCode === 'auth/email-already-exists') {
        throw new HttpsError('already-exists', 'Email already exists');
      }

      throw error;
    }
  },
);
