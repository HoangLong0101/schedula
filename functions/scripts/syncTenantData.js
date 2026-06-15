const admin = require('firebase-admin');

const projectId = process.env.FIREBASE_PROJECT_ID || 'schedula-543b1';
const tenantId = process.env.SEED_TENANT_ID || process.env.TENANT_ID || 'demo-tenant';
const dryRun = process.env.DRY_RUN === '1';

admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  projectId,
});

const db = admin.firestore();
const { FieldValue, Timestamp } = admin.firestore;

async function docs(collection) {
  const snapshot = await db.collection(collection).where('tenantId', '==', tenantId).get();
  return snapshot.docs.map((doc) => ({ id: doc.id, ref: doc.ref, data: doc.data() }));
}

function dateKey(timestamp) {
  const date = timestamp.toDate();
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

function phoneFromCustomerId(customerId) {
  const value = String(customerId || '').replace(/^customer-/, '');
  return /^\d{8,15}$/.test(value) ? value : '';
}

function latestTimestamp(a, b) {
  if (!a) return b || null;
  if (!b) return a;
  return a.toMillis() >= b.toMillis() ? a : b;
}

async function syncMissingCustomers(bookings, customersById) {
  const missing = new Map();
  for (const booking of bookings) {
    const data = booking.data;
    const customerId = data.customerId;
    if (!customerId || customersById.has(customerId)) {
      continue;
    }

    const current = missing.get(customerId);
    missing.set(customerId, {
      id: customerId,
      tenantId,
      name: data.customerName || customerId,
      phone: phoneFromCustomerId(customerId),
      email: '',
      notes: 'Created by data sync from existing bookings.',
      avatar: (data.customerName || customerId).trim().slice(0, 1).toUpperCase(),
      color: '#22AFC2',
      visitCount: (current?.visitCount || 0) + 1,
      lastVisit: latestTimestamp(current?.lastVisit, data.startTime),
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
  }

  for (const customer of missing.values()) {
    console.log(`${dryRun ? '[dry-run] would create' : 'creating'} customer ${customer.id}`);
    if (!dryRun) {
      await db.collection('customers').doc(customer.id).set(customer, { merge: true });
    }
  }

  return missing.size;
}

async function syncServices(services) {
  let updated = 0;
  for (const service of services) {
    const data = service.data;
    const patch = {};

    if (data.duration == null && data.durationMin != null) {
      patch.duration = data.durationMin;
    }
    if (data.durationMin == null && data.duration != null) {
      patch.durationMin = data.duration;
    }
    if (data.resources == null && Array.isArray(data.equipment)) {
      patch.resources = data.equipment;
    }

    if (Object.keys(patch).length === 0) {
      continue;
    }

    updated += 1;
    console.log(`${dryRun ? '[dry-run] would update' : 'updating'} service ${service.id}`, patch);
    if (!dryRun) {
      await service.ref.set({ ...patch, updatedAt: FieldValue.serverTimestamp() }, { merge: true });
    }
  }
  return updated;
}

async function rebuildSlots(bookings) {
  const slots = new Map();

  for (const booking of bookings) {
    const data = booking.data;
    if (!data.staffId || !data.startTime || !data.endTime) {
      continue;
    }
    if (data.status === 'cancelled' || data.status === 'no_show') {
      continue;
    }

    const key = `${dateKey(data.startTime)}_${data.staffId}`;
    const slot = slots.get(key) || {
      tenantId,
      staffId: data.staffId,
      date: Timestamp.fromDate(new Date(`${dateKey(data.startTime)}T00:00:00+07:00`)),
      intervals: [],
      updatedAt: FieldValue.serverTimestamp(),
    };

    slot.intervals.push({
      startTime: data.startTime,
      endTime: data.endTime,
      bookingId: booking.id,
    });
    slots.set(key, slot);
  }

  for (const [id, slot] of slots.entries()) {
    slot.intervals.sort((a, b) => a.startTime.toMillis() - b.startTime.toMillis());
    console.log(`${dryRun ? '[dry-run] would upsert' : 'upserting'} slot ${id} (${slot.intervals.length} intervals)`);
    if (!dryRun) {
      await db.collection('slots').doc(id).set(slot, { merge: true });
    }
  }

  return slots.size;
}

async function main() {
  console.log(`Project: ${projectId}`);
  console.log(`Tenant: ${tenantId}`);
  console.log(`Mode: ${dryRun ? 'dry-run' : 'write'}`);

  const [customers, services, bookings] = await Promise.all([
    docs('customers'),
    docs('services'),
    docs('bookings'),
  ]);

  const customersById = new Map(customers.map((customer) => [customer.id, customer]));

  const createdCustomers = await syncMissingCustomers(bookings, customersById);
  const updatedServices = await syncServices(services);
  const rebuiltSlots = await rebuildSlots(bookings);

  console.log('\nSync summary');
  console.table({
    createdCustomers,
    updatedServices,
    rebuiltSlots,
  });
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
