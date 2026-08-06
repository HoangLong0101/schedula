const admin = require('firebase-admin');

admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  projectId: process.env.FIREBASE_PROJECT_ID || 'schedula-543b1',
});

const db = admin.firestore();
const dryRun = process.env.DRY_RUN === '1';
const onlyTenant = process.env.TENANT_ID;

async function migrateTenant(tenant) {
  const tenantId = tenant.id;
  const equipment = await db
    .collection('equipment')
    .where('tenantId', '==', tenantId)
    .get();
  const byName = new Map(
    equipment.docs.map((document) => [
      String(document.data().name || '').trim().toLowerCase(),
      document,
    ]),
  );
  const services = await db
    .collection('services')
    .where('tenantId', '==', tenantId)
    .get();
  let mapped = 0;
  let unmapped = 0;

  for (const service of services.docs) {
    const names = Array.isArray(service.data().resources)
      ? service.data().resources
      : [];
    const matches = names
      .map((name) => byName.get(String(name).trim().toLowerCase()))
      .filter(Boolean);
    const missing = names.filter(
      (name) => !byName.has(String(name).trim().toLowerCase()),
    );
    const update = {
      resourceIds: [...new Set(matches.map((document) => document.id))],
      unmappedResources: missing,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    if (!dryRun) await service.ref.update(update);
    mapped += update.resourceIds.length;
    unmapped += missing.length;
  }

  const data = tenant.data();
  if (!dryRun) {
    await tenant.ref.set(
      {
        bookingPolicy: {
          timezone: data.timezone || 'Asia/Ho_Chi_Minh',
          weekdayHours: data.hoursWeekday || '',
          weekendHours: data.hoursWeekend || '',
        },
      },
      { merge: true },
    );
  }
  return { tenantId, services: services.size, mapped, unmapped };
}

async function main() {
  const tenants = onlyTenant
    ? [await db.collection('tenants').doc(onlyTenant).get()]
    : (await db.collection('tenants').get()).docs;
  const results = [];
  for (const tenant of tenants) {
    if (tenant.exists) results.push(await migrateTenant(tenant));
  }
  console.table(results);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
