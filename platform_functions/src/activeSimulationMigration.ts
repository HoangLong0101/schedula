import * as admin from 'firebase-admin';
import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { onRequest } from 'firebase-functions/v2/https';

if (admin.apps.length === 0) admin.initializeApp();

const db = admin.firestore();
const token = 'schedula-active-continuation-20260817-f7429ce1';
const marker = db.collection('_platformMigrations').doc('active-tenants-status-correction-2026-08-18-v2');
const eventTimesMarker = db.collection('_platformMigrations').doc('active-tenants-realistic-event-times-2026-08-18-v1');
const tenantNames = ['Mị Spa', 'Dưỡng sinh Cô Ba'];
const trialTenantNames = new Set([
  'Kim Dung Beauty',
  'Pure Spa',
  'Katie Spa',
  'Dưỡng sinh Cô Ba',
  'Mị Spa',
]);
const dates = [
  '2026-08-13',
  '2026-08-14',
  '2026-08-15',
  '2026-08-16',
  '2026-08-17',
  '2026-08-18',
];

type Row = FirebaseFirestore.QueryDocumentSnapshot;

export const activeSimulationMigration = onRequest(
  { timeoutSeconds: 540, memory: '512MiB' },
  async (request, response) => {
    if (request.method !== 'POST' || request.get('x-migration-token') !== token) {
      response.status(403).json({ success: false });
      return;
    }

    const tenants = await db.collection('tenants').where('name', 'in', tenantNames).get();
    if (tenants.size !== tenantNames.length) {
      response.status(412).json({ success: false, error: 'Active simulation tenants are missing.' });
      return;
    }

    const markerSnapshot = await marker.get();
    let result = markerSnapshot.data();
    if (!markerSnapshot.exists) {
      result = await applyContinuation(tenants.docs);
    }
    const eventTimesSnapshot = await eventTimesMarker.get();
    const eventTimes = eventTimesSnapshot.exists
      ? eventTimesSnapshot.data()
      : await applyRealisticEventTimes(tenants.docs);
    response.json({
      success: true,
      alreadyApplied: markerSnapshot.exists,
      ...result,
      eventTimes,
      verification: await verifyActivity(tenants.docs),
      subscriptionVerification: await verifySubscriptions(),
    });
  },
);

async function applyContinuation(tenants: Row[]) {
  const writes: Array<(transaction: FirebaseFirestore.Transaction) => void> = [];
  const summaries: Array<Record<string, unknown>> = [];
  const [allTenants, subscriptionPayments] = await Promise.all([
    db.collection('tenants').get(),
    db.collection('payments').where('type', '==', 'subscription').get(),
  ]);
  const paidTenantIds = new Set(
    subscriptionPayments.docs
      .filter((payment) => payment.data().status === 'paid')
      .map((payment) => String(payment.data().tenantId ?? '')),
  );

  for (const tenant of tenants) {
    const [users, customers, services, existingBookings] = await Promise.all([
      db.collection('users').where('tenantId', '==', tenant.id).get(),
      db.collection('customers').where('tenantId', '==', tenant.id).get(),
      db.collection('services').where('tenantId', '==', tenant.id).get(),
      db.collection('bookings').where('tenantId', '==', tenant.id).get(),
    ]);
    const staff = users.docs.filter((row) => row.data().role === 'staff' && row.data().active !== false);
    if (!staff.length || !customers.size || !services.size) {
      throw new Error(`Incomplete simulation data for ${tenant.data().name}.`);
    }

    const existingByDate = new Map<string, number>();
    for (const booking of existingBookings.docs) {
      const key = localDate(booking.data().startTime);
      existingByDate.set(key, (existingByDate.get(key) ?? 0) + 1);
      if (!dates.includes(key)) continue;
      const createdAt = booking.data().createdAt instanceof Timestamp
        ? booking.data().createdAt as Timestamp
        : booking.data().startTime as Timestamp;
      writes.push((transaction) => transaction.set(
        db.collection('auditEvents').doc(`${booking.id}-audit-created`),
        {
          tenantId: tenant.id,
          actorId: booking.data().createdBy ?? tenant.data().ownerUid,
          actorRole: 'owner',
          entityType: 'booking',
          entityId: booking.id,
          action: 'booking.created',
          status: 'succeeded',
          createdAt,
          simulationBatchId: 'outreach-trials-2026-08',
          continuationBatchId: 'active-tenants-activity-backfill-2026-08-18',
        },
        { merge: true },
      ));
    }
    const customerTotals = new Map<string, { visits: number; spent: number; lastVisit: Timestamp }>();
    const staffTotals = new Map<string, number>();
    const tenantStats = new Map<string, { bookings: number; revenue: number }>();
    const staffStats = new Map<string, { bookings: number; revenue: number }>();
    const serviceStats = new Map<string, { bookings: number; revenue: number }>();
    const slotIntervals = new Map<string, { staffId: string; date: string; intervals: unknown[] }>();
    let created = 0;
    let completed = 0;
    let latestAt = 0;

    for (const [dayIndex, date] of dates.entries()) {
      const target = Math.max(3, Math.round(staff.length * (0.62 + seeded(tenant.id, dayIndex, 0) * 0.28)));
      const missing = Math.max(0, target - (existingByDate.get(date) ?? 0));
      for (let index = 0; index < missing; index += 1) {
        const sequence = (existingByDate.get(date) ?? 0) + index + 1;
        const staffMember = staff[(dayIndex + index) % staff.length];
        const customer = customers.docs[Math.floor(seeded(tenant.id, dayIndex, index + 1) * customers.size)];
        const service = services.docs[(dayIndex * 3 + index) % services.size];
        const duration = Number(service.data().durationMin ?? service.data().duration ?? 60);
        const startMinutes = 8 * 60 + 35 + index * Math.floor(590 / Math.max(1, target)) +
          Math.floor(seeded(tenant.id, dayIndex, index + 20) * 26);
        const startTime = timestamp(date, startMinutes);
        const endTime = Timestamp.fromMillis(startTime.toMillis() + duration * 60000);
        const roll = seeded(tenant.id, dayIndex, index + 40);
        const status = roll < 0.87 ? 'completed' : roll < 0.95 ? 'cancelled' : 'no_show';
        const id = `sim-cont-20260818-${tenant.id}-${date.replace(/-/g, '')}-${String(sequence).padStart(2, '0')}`;
        const price = status === 'completed' ? Number(service.data().price ?? 0) : 0;
        const createdAt = Timestamp.fromMillis(startTime.toMillis() - (25 + Math.floor(roll * 130)) * 60000);
        const paymentId = `${id}-payment`;
        const booking = {
          tenantId: tenant.id,
          staffId: staffMember.id,
          customerId: customer.id,
          serviceId: service.id,
          startTime,
          endTime,
          status,
          customerName: String(customer.data().name ?? ''),
          staffName: String(staffMember.data().name ?? ''),
          serviceName: String(service.data().name ?? ''),
          notes: 'Lịch hẹn mô phỏng nối tiếp hành trình sử dụng thực tế.',
          createdBy: tenant.data().ownerUid,
          createdAt,
          updatedAt: endTime,
          reminder24Sent: true,
          reminder1hSent: true,
          resourceIds: [],
          simulationBatchId: 'outreach-trials-2026-08',
          continuationBatchId: 'active-tenants-2026-08-18',
          paymentStatus: status === 'completed' ? 'paid' : null,
          paymentId: status === 'completed' ? paymentId : null,
          paymentAmount: price || null,
          paymentMethod: status === 'completed' ? (roll < 0.55 ? 'cash' : 'bank_transfer') : null,
          paymentPaidAt: status === 'completed' ? endTime : null,
        };
        writes.push((transaction) => {
          transaction.set(db.collection('bookings').doc(id), booking);
          transaction.set(db.collection('auditEvents').doc(`${id}-audit-created`), {
            tenantId: tenant.id,
            actorId: tenant.data().ownerUid,
            actorRole: 'owner',
            entityType: 'booking',
            entityId: id,
            action: 'booking.created',
            status: 'succeeded',
            createdAt,
            simulationBatchId: 'outreach-trials-2026-08',
            continuationBatchId: 'active-tenants-2026-08-18',
          });
          if (status === 'completed') {
            transaction.set(db.collection('payments').doc(paymentId), {
              tenantId: tenant.id,
              type: 'manual',
              bookingId: id,
              status: 'paid',
              method: roll < 0.55 ? 'cash' : 'bank_transfer',
              amount: price,
              reference: `CONT-${date.replace(/-/g, '')}-${String(sequence).padStart(2, '0')}`,
              recordedBy: tenant.data().ownerUid,
              recordedAt: endTime,
              paidAt: endTime,
              createdAt: endTime,
              reconciliationStatus: 'matched',
              simulationBatchId: 'outreach-trials-2026-08',
              continuationBatchId: 'active-tenants-2026-08-18',
            });
          }
        });
        created += 1;
        latestAt = Math.max(latestAt, endTime.toMillis());
        staffTotals.set(staffMember.id, (staffTotals.get(staffMember.id) ?? 0) + 1);
        const slotKey = `${staffMember.id}|${date}`;
        const slot = slotIntervals.get(slotKey) ?? { staffId: staffMember.id, date, intervals: [] };
        if (!['cancelled', 'no_show'].includes(status)) {
          slot.intervals.push({ startTime, endTime, bookingId: id });
          slotIntervals.set(slotKey, slot);
        }
        if (status !== 'completed') continue;
        completed += 1;
        const customerTotal = customerTotals.get(customer.id) ?? { visits: 0, spent: 0, lastVisit: endTime };
        customerTotal.visits += 1;
        customerTotal.spent += price;
        customerTotal.lastVisit = endTime;
        customerTotals.set(customer.id, customerTotal);
        addStats(tenantStats, date, price);
        addStats(staffStats, `${staffMember.id}|${date}`, price);
        addStats(serviceStats, `${service.id}|${date}`, price);
      }
    }

    for (const [id, total] of customerTotals) writes.push((transaction) => transaction.set(
      db.collection('customers').doc(id),
      {
        visitCount: FieldValue.increment(total.visits),
        totalVisits: FieldValue.increment(total.visits),
        spent: FieldValue.increment(total.spent),
        lastVisit: total.lastVisit,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    ));
    for (const [id, count] of staffTotals) writes.push((transaction) => transaction.set(
      db.collection('users').doc(id),
      { appointments: FieldValue.increment(count), updatedAt: FieldValue.serverTimestamp() },
      { merge: true },
    ));
    addStatWrites(writes, tenant.id, 'tenantStatsDaily', tenantStats);
    addStatWrites(writes, tenant.id, 'staffStatsDaily', staffStats, 'staffId');
    addStatWrites(writes, tenant.id, 'serviceStatsDaily', serviceStats, 'serviceId');
    for (const slot of slotIntervals.values()) writes.push((transaction) => transaction.set(
      db.collection('slots').doc(`${tenant.id}_${slot.date}_${slot.staffId}`),
      {
        tenantId: tenant.id,
        staffId: slot.staffId,
        date: timestamp(slot.date, 0),
        intervals: FieldValue.arrayUnion(...slot.intervals),
        simulationBatchId: 'outreach-trials-2026-08',
        continuationBatchId: 'active-tenants-2026-08-18',
      },
      { merge: true },
    ));
    writes.push((transaction) => transaction.set(tenant.ref, {
      plan: 'enterprise',
      planTier: 'enterprise',
      status: 'active',
      usageEndedAt: null,
      sourceEndDate: '',
      lastActiveAt: latestAt ? Timestamp.fromMillis(latestAt) : tenant.data().lastActiveAt,
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true }));
    summaries.push({ tenant: tenant.data().name, createdBookings: created, completedBookings: completed });
  }

  const simulationTenants = allTenants.docs.filter(
    (tenant) => tenant.data().simulationBatchId === 'outreach-trials-2026-08',
  );
  for (const tenant of simulationTenants) {
    const paid = paidTenantIds.has(tenant.id);
    const trial = !paid && trialTenantNames.has(String(tenant.data().name ?? ''));
    writes.push((transaction) => transaction.set(tenant.ref, {
      plan: 'enterprise',
      planTier: 'enterprise',
      subscriptionStatus: paid ? 'active' : trial ? 'trial' : 'expired',
      trialStatus: trial ? 'active' : 'expired',
      status: 'active',
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true }));
  }

  if (writes.length + 1 > 500) throw new Error(`Migration has ${writes.length + 1} writes.`);
  const result = {
    tenantSummaries: summaries,
    tenantsUpdated: simulationTenants.length,
    trialTenants: simulationTenants.filter(
      (tenant) => !paidTenantIds.has(tenant.id) && trialTenantNames.has(String(tenant.data().name ?? '')),
    ).length,
    expiredTenants: simulationTenants.filter(
      (tenant) => !paidTenantIds.has(tenant.id) && !trialTenantNames.has(String(tenant.data().name ?? '')),
    ).length,
    paidSubscriptions: paidTenantIds.size,
    continuationThrough: '2026-08-18',
    activityBackfillFrom: '2026-08-13',
    appliedAt: Date.now(),
  };
  await db.runTransaction(async (transaction) => {
    if ((await transaction.get(marker)).exists) return;
    for (const write of writes) write(transaction);
    transaction.set(marker, result);
  });
  return result;
}

async function applyRealisticEventTimes(tenants: Row[]) {
  const writes: Array<(transaction: FirebaseFirestore.Transaction) => void> = [];
  const summary: Record<string, number> = {};
  for (const tenant of tenants) {
    const snapshot = await db.collection('auditEvents').where('tenantId', '==', tenant.id).get();
    const byDate = new Map<string, Row[]>();
    for (const event of snapshot.docs) {
      const data = event.data();
      if (!String(data.continuationBatchId ?? '').startsWith('active-tenants-')) continue;
      const date = localDate(data.createdAt);
      if (!dates.includes(date)) continue;
      byDate.set(date, [...(byDate.get(date) ?? []), event]);
    }
    let adjusted = 0;
    for (const [date, events] of byDate) {
      const used = new Set<number>();
      events.sort((left, right) => left.id.localeCompare(right.id));
      events.forEach((event, index) => {
        let minute = 8 * 60 + 5 + Math.floor(
          seeded(`${tenant.id}:${event.id}`, dates.indexOf(date), index + 700) * 700,
        );
        while (used.has(minute)) minute += 1;
        used.add(minute);
        const seconds = 7 + Math.floor(seeded(event.id, index, 900) * 51);
        writes.push((transaction) => transaction.update(event.ref, {
          createdAt: timestamp(date, minute, seconds),
        }));
        adjusted += 1;
      });
    }
    summary[String(tenant.data().name)] = adjusted;
  }
  if (writes.length + 1 > 500) throw new Error(`Event time migration has ${writes.length + 1} writes.`);
  const result = { adjustedEvents: summary, appliedAt: Date.now() };
  await db.runTransaction(async (transaction) => {
    if ((await transaction.get(eventTimesMarker)).exists) return;
    for (const write of writes) write(transaction);
    transaction.set(eventTimesMarker, result);
  });
  return result;
}

async function verifySubscriptions() {
  const tenants = await db.collection('tenants')
    .where('simulationBatchId', '==', 'outreach-trials-2026-08')
    .get();
  return Object.fromEntries(tenants.docs
    .sort((left, right) => String(left.data().name).localeCompare(String(right.data().name), 'vi'))
    .map((tenant) => {
      const data = tenant.data();
      return [String(data.name), {
        subscriptionStatus: data.subscriptionStatus,
        accountStatus: data.status,
        planTier: data.planTier,
        sourceEndDate: data.sourceEndDate ?? '',
      }];
    }));
}

async function verifyActivity(tenants: Row[]) {
  const result: Record<string, unknown> = {};
  for (const tenant of tenants) {
    const [bookings, activity] = await Promise.all([
      db.collection('bookings').where('tenantId', '==', tenant.id).get(),
      db.collection('auditEvents').where('tenantId', '==', tenant.id).get(),
    ]);
    result[String(tenant.data().name)] = {
      bookingsByDay: countByDate(bookings.docs, 'startTime'),
      activityByDay: countByDate(activity.docs, 'createdAt'),
      subscriptionStatus: (await tenant.ref.get()).data()?.subscriptionStatus,
      planTier: (await tenant.ref.get()).data()?.planTier,
    };
  }
  return result;
}

function countByDate(rows: Row[], field: string) {
  const result = Object.fromEntries(dates.map((date) => [date, 0]));
  for (const row of rows) {
    const date = localDate(row.data()[field]);
    if (date in result) result[date] += 1;
  }
  return result;
}

function timestamp(date: string, minutes: number, seconds = 0) {
  const hour = String(Math.floor(minutes / 60)).padStart(2, '0');
  const minute = String(minutes % 60).padStart(2, '0');
  const second = String(seconds).padStart(2, '0');
  return Timestamp.fromDate(new Date(`${date}T${hour}:${minute}:${second}+07:00`));
}

function localDate(value: unknown) {
  if (!(value instanceof Timestamp)) return '';
  return new Date(value.toMillis() + 7 * 3600000).toISOString().slice(0, 10);
}

function seeded(tenantId: string, day: number, index: number) {
  let value = 2166136261;
  for (const character of `${tenantId}:${day}:${index}`) {
    value ^= character.charCodeAt(0);
    value = Math.imul(value, 16777619);
  }
  return (value >>> 0) / 4294967296;
}

function addStats(map: Map<string, { bookings: number; revenue: number }>, key: string, price: number) {
  const value = map.get(key) ?? { bookings: 0, revenue: 0 };
  value.bookings += 1;
  value.revenue += price;
  map.set(key, value);
}

function addStatWrites(
  writes: Array<(transaction: FirebaseFirestore.Transaction) => void>,
  tenantId: string,
  collection: string,
  values: Map<string, { bookings: number; revenue: number }>,
  entityField?: string,
) {
  for (const [key, value] of values) {
    const [entityId, date] = entityField ? key.split('|') : ['', key];
    const id = entityField ? `${tenantId}_${entityId}_${date}` : `${tenantId}_${date}`;
    writes.push((transaction) => transaction.set(db.collection(collection).doc(id), {
      tenantId,
      date: timestamp(date, 0),
      dateKey: date,
      completedBookings: FieldValue.increment(value.bookings),
      revenue: FieldValue.increment(value.revenue),
      ...(entityField ? { [entityField]: entityId } : {}),
      simulationBatchId: 'outreach-trials-2026-08',
      continuationBatchId: 'active-tenants-2026-08-18',
    }, { merge: true }));
  }
}
