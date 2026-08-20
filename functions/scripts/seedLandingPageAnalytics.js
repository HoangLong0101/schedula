const assert = require('node:assert/strict');
const admin = require('firebase-admin');

const projectId = process.env.FIREBASE_PROJECT_ID || 'schedula-543b1';
const write = process.argv.includes('--write');
const selfTest = process.argv.includes('--self-test');
const batchId = 'landing-access-2026-08-v5';
const timezoneOffset = '+07:00';

let db;
const { Timestamp } = admin.firestore;

function dateKeys(start, end) {
  const result = [];
  for (let day = new Date(`${start}T00:00:00Z`); day <= new Date(`${end}T00:00:00Z`); day.setUTCDate(day.getUTCDate() + 1)) {
    result.push(day.toISOString().slice(0, 10));
  }
  return result;
}

function eventTimestamp(date, index) {
  const hour = date === '2026-08-18'
    ? 8 + index * 2
    : 8 + ((Number(date.slice(-2)) + index * 3) % 13);
  const minute = (index * 17 + Number(date.slice(-2)) * 7) % 60;
  return Timestamp.fromDate(new Date(
    `${date}T${String(hour).padStart(2, '0')}:${String(minute).padStart(2, '0')}:00${timezoneOffset}`,
  ));
}

async function commitInChunks(operations) {
  for (let offset = 0; offset < operations.length; offset += 400) {
    const batch = db.batch();
    for (const operation of operations.slice(offset, offset + 400)) operation(batch);
    await batch.commit();
  }
}

async function main() {
  const dates = dateKeys('2026-06-29', '2026-08-18');
  const dailyCounts = [
    5, 5, 5, 5, 6, 6, 6, 6, 7, 7, 8, 10, 13, 16, 17,
    16, 15, 14, 13, 12, 12, 11, 11, 10, 10, 9, 9, 8, 8, 7, 7, 7, 7,
    7, 7, 7, 7, 6, 6, 6, 6, 5, 5, 5, 5, 6, 7,
    8, 7, 5, 4,
  ];
  assert.equal(dates.length, dailyCounts.length);
  const counts = Object.fromEntries(dates.map((date, index) => [date, dailyCounts[index]]));
  const july = Object.fromEntries(Object.entries(counts).filter(([date]) => date <= '2026-07-31'));
  const desiredFirestoreTotal = 417;

  assert.equal(Object.values(july).reduce((sum, value) => sum + value, 0), 308);
  assert.equal(Object.values(counts).reduce((sum, value) => sum + value, 0), desiredFirestoreTotal);
  assert.equal(july['2026-07-12'], 16);
  assert.equal(july['2026-07-13'], Math.max(...Object.values(july)));
  assert.deepEqual(dailyCounts.slice(10, 15), [8, 10, 13, 16, 17]);
  assert(dailyCounts.slice(14, 33).every((value, index, values) => index === 0 || value <= values[index - 1]));

  if (selfTest) {
    console.log(`Self-test passed: ${desiredFirestoreTotal} pageviews through 18/08.`);
    return;
  }

  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId,
  });
  db = admin.firestore();

  const start = Timestamp.fromDate(new Date(`2026-06-29T00:00:00${timezoneOffset}`));
  const end = Timestamp.fromDate(new Date(`2026-08-19T00:00:00${timezoneOffset}`));
  const existing = await db.collection('landingPageEvents')
    .where('type', '==', 'access')
    .where('occurredAt', '>=', start)
    .where('occurredAt', '<', end)
    .orderBy('occurredAt')
    .get();

  console.log(`Existing access events in range: ${existing.size}`);
  console.log(`Desired 29/06-31/07: 308; desired history through 18/08: ${desiredFirestoreTotal}`);
  console.log(`Peak: 12/07=${july['2026-07-12']}, 13/07=${july['2026-07-13']}`);
  if (!write) {
    console.log('Dry run complete. Re-run with --write to apply.');
    return;
  }

  await commitInChunks(existing.docs.map((document) => (batch) => batch.delete(document.ref)));
  const creates = [];
  for (const [date, count] of Object.entries(counts)) {
    for (let index = 0; index < count; index += 1) {
      const id = `${batchId}-${date.replaceAll('-', '')}-${String(index + 1).padStart(3, '0')}`;
      const occurredAt = eventTimestamp(date, index);
      creates.push((batch) => batch.set(db.collection('landingPageEvents').doc(id), {
        type: 'access',
        source: 'simulation',
        simulationBatchId: batchId,
        occurredAt,
        createdAt: occurredAt,
      }));
    }
  }
  await commitInChunks(creates);

  const verified = await db.collection('landingPageEvents')
    .where('type', '==', 'access')
    .where('occurredAt', '>=', start)
    .where('occurredAt', '<', end)
    .orderBy('occurredAt')
    .get();
  assert.equal(verified.size, desiredFirestoreTotal);
  console.log(`Applied and verified ${verified.size} historical access events.`);
}

main().then(() => process.exit(0)).catch((error) => {
  console.error(error);
  process.exit(1);
});
