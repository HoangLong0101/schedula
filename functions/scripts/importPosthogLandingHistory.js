const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');

const args = process.argv.slice(2);
const selfTest = args.includes('--self-test');
const write = args.includes('--write');

function valueAfter(flag) {
  const index = args.indexOf(flag);
  return index >= 0 ? args[index + 1] : '';
}

function eventUuid(id) {
  const bytes = crypto.createHash('sha256').update(id).digest().subarray(0, 16);
  bytes[6] = (bytes[6] & 0x0f) | 0x50;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  const hex = bytes.toString('hex');
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
}

function posthogEvent(row, siteUrl) {
  assert(row.id, 'Every row needs an id.');
  assert(!Number.isNaN(Date.parse(row.timestamp)), `Invalid timestamp for ${row.id}.`);
  const url = new URL(siteUrl);
  const visitorId = row.visitorId || `firebase-history-${row.id}`;
  assert(['access', 'download'].includes(row.type), `Unsupported event type: ${row.type}`);
  return {
    uuid: eventUuid(row.id),
    event: row.type === 'access' ? '$pageview' : 'clicked_download_qr',
    timestamp: row.timestamp,
    properties: {
      distinct_id: visitorId,
      $session_id: eventUuid(`session:${visitorId}`),
      $window_id: eventUuid(`window:${visitorId}`),
      $current_url: url.href,
      $host: url.host,
      $pathname: url.pathname,
      $process_person_profile: false,
      source: 'firebase_backfill',
      firebase_event_id: row.id,
      historical_data_quality: 'aggregate_access_only',
    },
  };
}

async function main() {
  if (selfTest) {
    const visitorId = 'historical-visitor-1';
    const first = posthogEvent({ id: 'event-1', type: 'access', visitorId, timestamp: '2026-07-12T02:00:00.000Z' }, 'https://example.workers.dev/');
    const second = posthogEvent({ id: 'event-1', type: 'access', visitorId, timestamp: '2026-07-12T02:00:00.000Z' }, 'https://example.workers.dev/');
    const download = posthogEvent({ id: 'event-2', type: 'download', visitorId, timestamp: '2026-07-12T02:05:00.000Z' }, 'https://example.workers.dev/');
    assert.equal(first.event, '$pageview');
    assert.equal(download.event, 'clicked_download_qr');
    assert.equal(first.properties.distinct_id, download.properties.distinct_id);
    assert.equal(first.properties.$session_id, download.properties.$session_id);
    assert.equal(first.properties.$window_id, download.properties.$window_id);
    assert.equal(first.uuid, second.uuid);
    assert.equal(first.properties.$host, 'example.workers.dev');
    return console.log('PostHog landing backfill self-test passed.');
  }

  const file = valueAfter('--file') || args.find((argument) => !argument.startsWith('-'));
  assert(file, 'Pass the generated Firebase history JSON path.');
  const rows = JSON.parse(fs.readFileSync(file, 'utf8'));
  assert(Array.isArray(rows) && rows.length, 'The backfill file has no events.');
  assert.equal(new Set(rows.map((row) => row.id)).size, rows.length, 'The backfill file contains duplicate ids.');
  const siteUrl = process.env.POSTHOG_SITE_URL;
  assert(siteUrl, 'Set POSTHOG_SITE_URL to the deployed Vercel URL.');
  const events = rows.map((row) => posthogEvent(row, siteUrl));
  const historicalCutoff = Date.now() - 48 * 60 * 60 * 1000;
  const historicalEvents = events.filter((event) => Date.parse(event.timestamp) <= historicalCutoff);
  const recentEvents = events.filter((event) => Date.parse(event.timestamp) > historicalCutoff);
  const dates = events.map((event) => event.timestamp).sort();
  console.log(`${events.length} events ready from ${dates[0]} through ${dates.at(-1)}.`);
  console.log(`${events.filter((event) => event.event === '$pageview').length} pageviews; ${events.filter((event) => event.event === 'clicked_download_qr').length} QR download clicks.`);
  console.log(`${historicalEvents.length} historical events; ${recentEvents.length} recent events.`);
  if (!write) return console.log('Dry run complete. Add --write to import.');

  const apiKey = process.env.POSTHOG_PROJECT_TOKEN;
  const host = (process.env.POSTHOG_HOST || 'https://us.i.posthog.com').replace(/\/$/, '');
  assert(apiKey, 'Set POSTHOG_PROJECT_TOKEN.');
  for (const [historicalMigration, batchEvents] of [[true, historicalEvents], [false, recentEvents]]) {
    for (let offset = 0; offset < batchEvents.length; offset += 100) {
      const response = await fetch(`${host}/batch/`, {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({
          api_key: apiKey,
          historical_migration: historicalMigration,
          batch: batchEvents.slice(offset, offset + 100),
        }),
      });
      if (!response.ok) throw new Error(`PostHog batch failed (${response.status}): ${await response.text()}`);
    }
  }
  console.log(`Imported ${events.length} historical events. Deterministic UUIDs make retries safe.`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
