const assert = require('node:assert/strict');
const fs = require('node:fs');
const admin = require('firebase-admin');

const selfTest = process.argv.includes('--self-test');
const projectId = process.env.FIREBASE_PROJECT_ID || 'schedula-543b1';
const outputFile = process.env.POSTHOG_HISTORY_FILE || 'scripts/landing-history.json';

function exportedRows(documents) {
  const rows = documents
    .map(({ id, data }) => ({
      id,
      type: data.type === 'access'
        ? 'access'
        : ['download', 'download_attempt'].includes(data.type) ? 'download' : '',
      timestamp: data.occurredAt.toDate().toISOString(),
    }))
    .filter((row) => row.type)
    .sort((a, b) => a.timestamp.localeCompare(b.timestamp));

  const availableVisits = [];
  for (const row of rows) {
    if (row.type === 'access') {
      row.visitorId = `firebase-history-${row.id}`;
      availableVisits.push(row);
      continue;
    }

    const visitIndex = availableVisits.findLastIndex((visit) => visit.timestamp <= row.timestamp);
    const visit = visitIndex >= 0 ? availableVisits.splice(visitIndex, 1)[0] : null;
    row.visitorId = visit?.visitorId || `firebase-history-${row.id}`;
  }
  return rows;
}

async function main() {
  if (selfTest) {
    const timestamp = (value) => ({ toDate: () => new Date(value) });
    const rows = exportedRows([
      { id: 'visit-1', data: { type: 'access', occurredAt: timestamp('2026-07-12T02:00:00Z') } },
      { id: 'download-1', data: { type: 'download', occurredAt: timestamp('2026-07-12T02:05:00Z') } },
    ]);
    assert.equal(rows.length, 2);
    assert.equal(rows[0].visitorId, rows[1].visitorId);
    return console.log('PostHog Firebase export self-test passed.');
  }

  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId,
  });
  const db = admin.firestore();
  const start = admin.firestore.Timestamp.fromDate(new Date('2026-06-28T17:00:00.000Z'));
  const cutoff = admin.firestore.Timestamp.now();
  const snapshot = await db.collection('landingPageEvents')
    .where('occurredAt', '>=', start)
    .where('occurredAt', '<=', cutoff)
    .orderBy('occurredAt')
    .get();
  const rows = exportedRows(snapshot.docs.map((document) => ({ id: document.id, data: document.data() })));
  assert(rows.length, 'No historical landing-page events were found.');
  fs.writeFileSync(outputFile, JSON.stringify(rows, null, 2));
  console.log(`Exported ${rows.length} events to ${outputFile}.`);
  console.log(`${rows.filter((row) => row.type === 'access').length} pageviews; ${rows.filter((row) => row.type === 'download').length} QR download clicks.`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
