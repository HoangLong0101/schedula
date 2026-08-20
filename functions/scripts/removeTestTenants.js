const fs = require('node:fs');
const path = require('node:path');
const admin = require('firebase-admin');

const projectId = process.env.FIREBASE_PROJECT_ID || 'schedula-543b1';
const apply = process.argv.includes('--apply');
const targets = new Map([
  ['wV1dCKBYE9A1kcflDnWi', 'Spa của Minh'],
  ['49T78xceyH20e4zggB9g', 'vindy'],
]);
const tenantCollections = [
  'bookings',
  'customers',
  'users',
  'services',
  'products',
  'equipment',
  'slots',
  'notifications',
  'payments',
  'tenantStatsDaily',
  'staffStatsDaily',
  'serviceStatsDaily',
  'staffLeaves',
  'auditEvents',
  'campaigns',
  'campaignDeliveries',
];

admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  projectId,
});

const db = admin.firestore();

async function main() {
  const tenants = await Promise.all(
    [...targets].map(async ([preferredId, expectedName]) => {
      let snapshot = await db.collection('tenants').doc(preferredId).get();
      if (!snapshot.exists) {
        const matches = await db.collection('tenants')
          .where('name', '==', expectedName)
          .limit(2)
          .get();
        if (matches.size !== 1) {
          throw new Error(`Expected one tenant named ${expectedName}, found ${matches.size}. Aborting.`);
        }
        [snapshot] = matches.docs;
      }
      const data = snapshot.data();
      if (String(data.name).trim().toLocaleLowerCase('vi') !== expectedName.toLocaleLowerCase('vi')) {
        throw new Error(`Tenant ${snapshot.id} is ${data.name}, expected ${expectedName}. Aborting.`);
      }
      return { id: snapshot.id, ref: snapshot.ref, data };
    }),
  );

  const records = [];
  for (const tenant of tenants) {
    records.push({ collection: 'tenants', id: tenant.id, data: tenant.data });
    for (const collection of tenantCollections) {
      const snapshot = await db.collection(collection)
        .where('tenantId', '==', tenant.id)
        .get();
      records.push(...snapshot.docs.map((doc) => ({
        collection,
        id: doc.id,
        data: doc.data(),
      })));
    }
  }

  const counts = records.reduce((result, record) => {
    result[record.collection] = (result[record.collection] || 0) + 1;
    return result;
  }, {});
  console.table(counts);
  console.log(`${records.length} Firestore records matched in ${projectId}.`);
  if (!apply) {
    console.log('Dry run only. Re-run with --apply to create a backup and delete them.');
    return;
  }

  const output = path.resolve(__dirname, '..', '..', 'outputs', 'removed-test-tenants-2026-08-18.json');
  fs.mkdirSync(path.dirname(output), { recursive: true });
  fs.writeFileSync(output, JSON.stringify({ projectId, exportedAt: new Date().toISOString(), records }, null, 2));

  const authUserIds = records
    .filter((record) => record.collection === 'users')
    .map((record) => record.id);
  const writer = db.bulkWriter();
  for (const record of records) {
    writer.delete(db.collection(record.collection).doc(record.id));
  }
  await writer.close();
  await Promise.all(authUserIds.map((uid) => admin.auth().deleteUser(uid).catch((error) => {
    if (error.code !== 'auth/user-not-found') throw error;
  })));

  console.log(`Deleted ${records.length} Firestore records and ${authUserIds.length} Auth users.`);
  console.log(`Backup: ${output}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
