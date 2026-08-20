const admin = require('firebase-admin');

admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  projectId: process.env.GCLOUD_PROJECT || 'schedula-543b1',
});

const db = admin.firestore();

async function main() {
  const cutoff = admin.firestore.Timestamp.fromMillis(Date.now() - 30 * 86400000);
  const [tenants, bookings, pureSpaActivity] = await Promise.all([
    db.collection('tenants').get(),
    db.collection('bookings').where('startTime', '>=', cutoff).select('tenantId').get(),
    db.collection('auditEvents')
      .where('tenantId', '==', 'sim-2026-49-pure-spa')
      .where('createdAt', '>=', cutoff)
      .orderBy('createdAt', 'desc')
      .get(),
  ]);
  const tenantIds = new Set(tenants.docs.map((document) => document.id));
  const active = new Set(
    bookings.docs
      .map((document) => String(document.data().tenantId ?? ''))
      .filter((tenantId) => tenantIds.has(tenantId)),
  );
  console.log(JSON.stringify({
    tenants: tenants.size,
    activeTenants30d: active.size,
    usageRate30d: tenants.size ? Math.round(active.size / tenants.size * 1000) / 10 : 0,
    pureSpaActivity30d: pureSpaActivity.size,
  }));
}

main().then(() => process.exit(0)).catch((error) => {
  console.error(error.message || error);
  process.exit(1);
});
