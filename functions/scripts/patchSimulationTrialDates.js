const assert = require('node:assert/strict');
const admin = require('firebase-admin');
const { tenantIdFor } = require('./simulationTenantEmails');

const projectId = process.env.FIREBASE_PROJECT_ID || 'schedula-543b1';
const batchId = 'outreach-trials-2026-08';
const write = process.argv.includes('--write');
const lifecycles = [
  ['An Nhiên Spa & Wellness', '2026-07-02', '2026-07-31'],
  ['Cát Tường Spa', '2026-07-02', '2026-07-25'],
  ['Lotus Beauty Spa', '2026-07-04', '2026-07-19'],
  ['Oasis Spa', '2026-07-03', '2026-07-14'],
  ['Xinh Xinh Nail & Eyelash', '2026-07-05', '2026-07-22'],
  ['Ngọc Anh Beauty Spa', '2026-07-01', '2026-07-30'],
  ['Dưỡng sinh Cô Ba', '2026-07-18', null],
  ['Katie Spa', '2026-07-19', '2026-07-24'],
  ['Kim Dung Beauty', '2026-07-25', '2026-07-27'],
  ['Mị Spa', '2026-07-15', null],
  ['Pure Spa', '2026-07-22', '2026-08-03'],
];
const activityCollections = [
  ['bookings', ['startTime', 'createdAt']],
  ['payments', ['createdAt', 'recordedAt', 'paidAt']],
  ['auditEvents', ['createdAt']],
  ['slots', ['date']],
  ['tenantStatsDaily', ['date']],
  ['staffStatsDaily', ['date']],
  ['serviceStatsDaily', ['date']],
];

admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  projectId,
});
const db = admin.firestore();
const { FieldValue, Timestamp } = admin.firestore;

function addDays(value, days) {
  const date = new Date(`${value}T00:00:00.000Z`);
  date.setUTCDate(date.getUTCDate() + days);
  return date.toISOString().slice(0, 10);
}

function localTimestamp(date, endOfDay = false) {
  return Timestamp.fromDate(new Date(`${date}T${endOfDay ? '23:59:59.999' : '00:00:00.000'}+07:00`));
}

function millis(value) {
  return value instanceof Timestamp ? value.toMillis() : null;
}

function activityTime(data, fields) {
  for (const field of fields) {
    const value = millis(data[field]);
    if (value != null) return value;
  }
  return null;
}

function localToday() {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Ho_Chi_Minh',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(new Date());
}

async function inspectLifecycle([name, startDate, usageEndDate]) {
  const ref = db.collection('tenants').doc(tenantIdFor(name));
  const tenant = await ref.get();
  if (!tenant.exists || tenant.data().name !== name || tenant.data().simulationBatchId !== batchId) {
    throw new Error(`Simulation tenant not found: ${name}`);
  }
  const cutoff = usageEndDate ? localTimestamp(usageEndDate, true).toMillis() : null;
  const snapshots = await Promise.all(activityCollections.map(([collection]) =>
    db.collection(collection).where('tenantId', '==', ref.id).get()));
  const late = [];
  let latestBookingAt = null;
  snapshots.forEach((snapshot, index) => {
    const [collection, fields] = activityCollections[index];
    for (const document of snapshot.docs) {
      const at = activityTime(document.data(), fields);
      if (collection === 'bookings' && at != null && (cutoff == null || at <= cutoff)) {
        latestBookingAt = Math.max(latestBookingAt || 0, at);
      }
      if (cutoff != null && at != null && at > cutoff) {
        late.push({ collection, ref: document.ref, at });
      }
    }
  });
  const trialEndDate = addDays(startDate, 30);
  const trialActive = localToday() <= trialEndDate;
  return {
    name,
    ref,
    tenant,
    startDate,
    trialEndDate,
    usageEndDate,
    subscriptionStatus: trialActive ? 'trial' : usageEndDate ? 'cancelled' : 'expired',
    latestBookingAt,
    late,
  };
}

async function verifyLifecycle(change) {
  const data = (await change.ref.get()).data();
  assert.equal(data.status, 'active');
  assert.equal(data.planExpiresAt.toMillis(), localTimestamp(change.trialEndDate).toMillis());
  assert.equal(data.subscriptionStatus, change.subscriptionStatus);
  assert.equal(data.sourceEndDate, change.usageEndDate || '');
  assert.equal(
    data.usageEndedAt ? data.usageEndedAt.toMillis() : null,
    change.usageEndDate ? localTimestamp(change.usageEndDate, true).toMillis() : null,
  );
  if (change.usageEndDate) {
    for (const [collection, fields] of activityCollections) {
      const snapshot = await db.collection(collection).where('tenantId', '==', change.ref.id).get();
      const cutoff = localTimestamp(change.usageEndDate, true).toMillis();
      assert(snapshot.docs.every((document) => {
        const at = activityTime(document.data(), fields);
        return at == null || at <= cutoff;
      }), `${change.name} still has ${collection} activity after ${change.usageEndDate}`);
    }
  }
}

async function main() {
  assert.equal(addDays('2026-07-18', 30), '2026-08-17');
  assert.equal(addDays('2026-07-15', 30), '2026-08-14');
  const changes = [];
  for (const lifecycle of lifecycles) changes.push(await inspectLifecycle(lifecycle));
  for (const name of ['Katie Spa', 'Kim Dung Beauty', 'Pure Spa']) {
    assert.equal(changes.find((change) => change.name === name)?.subscriptionStatus, 'trial');
  }

  console.table(changes.map((change) => ({
    tenant: change.name,
    start: change.startDate,
    trialEnd: change.trialEndDate,
    usageEnd: change.usageEndDate || 'still using',
    status: change.subscriptionStatus,
    lateActivity: change.late.length,
  })));
  if (!write) return console.log('Dry run complete. Re-run with --write to apply.');

  const writer = db.bulkWriter();
  writer.onWriteError((error) => error.failedAttempts < 3);
  for (const change of changes) {
    writer.update(change.ref, {
      status: 'active',
      subscriptionStatus: change.subscriptionStatus,
      trialStatus: change.subscriptionStatus === 'trial' ? 'active' : 'expired',
      planStartedAt: localTimestamp(change.startDate),
      planExpiresAt: localTimestamp(change.trialEndDate),
      usageEndedAt: change.usageEndDate ? localTimestamp(change.usageEndDate, true) : null,
      sourceEndDate: change.usageEndDate || '',
      lastActiveAt: change.latestBookingAt ? Timestamp.fromMillis(change.latestBookingAt) : null,
      updatedAt: FieldValue.serverTimestamp(),
    });
    change.late.forEach((activity) => writer.delete(activity.ref));
  }
  await writer.close();
  for (const change of changes) await verifyLifecycle(change);
  console.log(`Corrected ${changes.length} tenant lifecycles and removed ${changes.reduce((sum, change) => sum + change.late.length, 0)} out-of-range activity records.`);
}

main().then(() => process.exit(0)).catch((error) => {
  console.error(error);
  process.exit(1);
});
