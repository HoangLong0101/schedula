const admin = require('firebase-admin');
const { tenantAdminEmail } = require('./simulationTenantEmails');

const projectId = process.env.FIREBASE_PROJECT_ID || 'schedula-543b1';
const batchId = 'outreach-trials-2026-08';
const write = process.argv.includes('--write');
const appointmentFeature = 'Tối đa 100 lịch hẹn/tháng';

admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  projectId,
});
const db = admin.firestore();
const auth = admin.auth();
const { FieldValue } = admin.firestore;

function updatedFeatures(features) {
  const values = Array.isArray(features) ? features.map(String) : [];
  const index = values.findIndex((value) => /tối đa\s+\d+\s+lịch hẹn\/tháng/i.test(value));
  if (index === -1) return [appointmentFeature, ...values];
  values[index] = appointmentFeature;
  return values;
}

async function main() {
  const [tenants, basicPlan] = await Promise.all([
    db.collection('tenants').where('simulationBatchId', '==', batchId).get(),
    db.collection('subscriptionPlans').doc('basic').get(),
  ]);
  if (tenants.size !== 11) throw new Error(`Expected 11 simulation tenants, found ${tenants.size}`);
  if (!basicPlan.exists) throw new Error('Basic subscription plan not found');

  const changes = [];
  for (const tenant of tenants.docs) {
    const data = tenant.data();
    const ownerUid = String(data.ownerUid || '');
    const name = String(data.name || '');
    if (!ownerUid || !name) throw new Error(`Tenant ${tenant.id} has no owner or name`);
    const [profile, authUser] = await Promise.all([
      db.collection('users').doc(ownerUid).get(),
      auth.getUser(ownerUid),
    ]);
    if (profile.data()?.simulationBatchId !== batchId || authUser.customClaims?.simulationBatchId !== batchId) {
      throw new Error(`Tenant ${tenant.id} owner is not part of the simulation cohort`);
    }
    const email = tenantAdminEmail(name);
    try {
      const collision = await auth.getUserByEmail(email);
      if (collision.uid !== ownerUid) throw new Error(`Email collision for ${name}`);
    } catch (error) {
      if (error.code !== 'auth/user-not-found') throw error;
    }
    changes.push({
      tenant,
      ownerUid,
      name,
      beforeEmail: String(authUser.email || profile.data()?.email || ''),
      email,
    });
  }

  const beforeFeatures = basicPlan.data()?.features;
  const afterFeatures = updatedFeatures(beforeFeatures);
  console.table(changes.map(({ name, beforeEmail, email }) => ({
    tenant: name,
    account: beforeEmail === email ? 'unchanged' : 'email update',
    desiredEmail: email,
  })));
  console.log(`Basic plan feature: ${afterFeatures.find((value) => value === appointmentFeature)}`);
  if (!write) {
    console.log('Dry run complete. Re-run with --write to apply.');
    return;
  }

  for (const change of changes) {
    if (change.beforeEmail !== change.email) {
      await auth.updateUser(change.ownerUid, { email: change.email });
    }
  }

  const batch = db.batch();
  for (const change of changes) {
    batch.set(db.collection('users').doc(change.ownerUid), {
      email: change.email,
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
    batch.set(change.tenant.ref, {
      email: change.email,
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
    if (change.beforeEmail !== change.email) {
      batch.set(db.collection('auditEvents').doc(), {
        platform: true,
        actorId: 'system:tenant-email-migration',
        actorEmail: 'system@schedula.internal',
        actorRole: 'system',
        action: 'business.owner_email_updated',
        entityType: 'tenant',
        entityId: change.tenant.id,
        before: { ownerEmail: change.beforeEmail },
        after: { ownerEmail: change.email },
        status: 'succeeded',
        createdAt: FieldValue.serverTimestamp(),
      });
    }
  }
  batch.set(basicPlan.ref, {
    features: afterFeatures,
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });
  batch.set(db.collection('auditEvents').doc(), {
    platform: true,
    actorId: 'system:plan-limit-migration',
    actorEmail: 'system@schedula.internal',
    actorRole: 'system',
    action: 'plan.appointment_limit_updated',
    entityType: 'plan',
    entityId: basicPlan.id,
    before: { features: beforeFeatures || [] },
    after: { features: afterFeatures },
    status: 'succeeded',
    createdAt: FieldValue.serverTimestamp(),
  });
  await batch.commit();
  console.log(`Applied ${changes.length} tenant email records and the Basic plan limit.`);
}

main().then(() => process.exit(0)).catch((error) => {
  console.error(error);
  process.exit(1);
});
