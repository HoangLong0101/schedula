import * as admin from 'firebase-admin';
import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { onDocumentWritten } from 'firebase-functions/v2/firestore';

if (admin.apps.length === 0) admin.initializeApp();
const db = admin.firestore();

function auditCrud(collection: string, entityType: string) {
  return onDocumentWritten(
    { document: `${collection}/{documentId}`, region: 'asia-southeast1' },
    async (event) => {
      const before = event.data?.before.data();
      const after = event.data?.after.data();
      const tenantId = String(after?.tenantId ?? before?.tenantId ?? '');
      if (!tenantId) return;
      const tenantRef = db.collection('tenants').doc(tenantId);
      const tenant = await tenantRef.get();
      const usageEndedAt = tenant.data()?.usageEndedAt;
      const eventTime = new Date(event.time).getTime();
      if (usageEndedAt instanceof Timestamp && usageEndedAt.toMillis() < eventTime) return;
      const batch = db.batch();
      batch.set(db.collection('auditEvents').doc(), {
        tenantId,
        actorId: String(after?.updatedBy ?? after?.createdBy ?? 'system'),
        actorRole: 'system',
        entityType,
        entityId: event.params.documentId,
        action: `${entityType}.${crudAction(before, after)}`,
        status: 'succeeded',
        createdAt: FieldValue.serverTimestamp(),
      });
      batch.set(tenantRef, {
        lastActiveAt: FieldValue.serverTimestamp(),
      }, { merge: true });
      await batch.commit();
    },
  );
}

export function crudAction(
  before: FirebaseFirestore.DocumentData | undefined,
  after: FirebaseFirestore.DocumentData | undefined,
): 'created' | 'updated' | 'deleted' {
  if (!before) return 'created';
  if (!after) return 'deleted';
  return 'updated';
}

export const auditCustomerCrud = auditCrud('customers', 'customer');
export const auditServiceCrud = auditCrud('services', 'service');
export const auditProductCrud = auditCrud('products', 'product');
export const auditEquipmentCrud = auditCrud('equipment', 'equipment');
