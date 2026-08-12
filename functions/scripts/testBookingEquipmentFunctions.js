const assert = require('node:assert/strict');
const admin = require('firebase-admin');

const projectId = 'demo-schedula-booking-equipment-test';
const callableBase = `http://127.0.0.1:5001/${projectId}/asia-southeast1`;
const authBase = 'http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1';

admin.initializeApp({ projectId });

async function signIn(email, password) {
  const response = await fetch(
    `${authBase}/accounts:signInWithPassword?key=fake-api-key`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password, returnSecureToken: true }),
    },
  );
  if (!response.ok) throw new Error(await response.text());
  return (await response.json()).idToken;
}

async function call(token, data, shouldSucceed = true) {
  const response = await fetch(`${callableBase}/mutateBooking`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ data }),
  });
  const body = await response.json();
  assert.equal(response.ok, shouldSucceed, JSON.stringify(body));
  return shouldSucceed ? body.result : body.error;
}

async function equipmentStatus(id) {
  const snapshot = await admin.firestore().collection('equipment').doc(id).get();
  return snapshot.data().status;
}

async function main() {
  const db = admin.firestore();
  await admin.auth().createUser({
    uid: 'owner-1',
    email: 'owner@example.com',
    password: 'OwnerPass123!',
  });
  await admin.auth().setCustomUserClaims('owner-1', {
    role: 'owner',
    tenantId: 'tenant-1',
  });
  const token = await signIn('owner@example.com', 'OwnerPass123!');

  await Promise.all([
    db.collection('tenants').doc('tenant-1').set({ name: 'Tenant 1' }),
    db.collection('users').doc('staff-1').set({
      tenantId: 'tenant-1',
      role: 'staff',
      name: 'Staff 1',
      status: 'available',
    }),
    db.collection('customers').doc('customer-1').set({
      tenantId: 'tenant-1',
      name: 'Customer 1',
    }),
    db.collection('services').doc('service-1').set({
      tenantId: 'tenant-1',
      name: 'Service 1',
      resourceIds: [],
    }),
    db.collection('equipment').doc('equipment-1').set({
      tenantId: 'tenant-1',
      name: 'Equipment 1',
      status: 'available',
      quantity: 1,
    }),
    db.collection('equipment').doc('equipment-2').set({
      tenantId: 'tenant-1',
      name: 'Equipment 2',
      status: 'available',
      quantity: 1,
    }),
    db.collection('equipment').doc('other-equipment').set({
      tenantId: 'tenant-2',
      name: 'Other equipment',
      status: 'available',
      quantity: 1,
    }),
  ]);

  const booking = await call(token, {
    action: 'create',
    staffId: 'staff-1',
    customerId: 'customer-1',
    serviceId: 'service-1',
    startTime: '2026-08-13T02:00:00.000Z',
    endTime: '2026-08-13T03:00:00.000Z',
    status: 'confirmed',
    resourceIds: ['equipment-1'],
  });
  assert.equal(await equipmentStatus('equipment-1'), 'in_use');

  await call(token, {
    action: 'update',
    bookingId: booking.bookingId,
    resourceIds: ['equipment-2'],
  });
  assert.equal(await equipmentStatus('equipment-1'), 'available');
  assert.equal(await equipmentStatus('equipment-2'), 'in_use');

  const rejected = await call(token, {
    action: 'create',
    staffId: 'staff-1',
    customerId: 'customer-1',
    serviceId: 'service-1',
    startTime: '2026-08-13T04:00:00.000Z',
    endTime: '2026-08-13T05:00:00.000Z',
    status: 'confirmed',
    resourceIds: ['other-equipment'],
  }, false);
  assert.equal(rejected.status, 'FAILED_PRECONDITION');

  const secondBooking = await call(token, {
    action: 'create',
    staffId: 'staff-1',
    customerId: 'customer-1',
    serviceId: 'service-1',
    startTime: '2026-08-13T04:00:00.000Z',
    endTime: '2026-08-13T05:00:00.000Z',
    status: 'confirmed',
    resourceIds: ['equipment-2'],
  });

  await call(token, { action: 'cancel', bookingId: booking.bookingId });
  assert.equal(await equipmentStatus('equipment-2'), 'in_use');
  await call(token, {
    action: 'cancel',
    bookingId: secondBooking.bookingId,
  });
  assert.equal(await equipmentStatus('equipment-2'), 'available');

  console.log('Booking equipment lifecycle validation passed');
}

main().then(() => process.exit(0)).catch((error) => {
  console.error(error);
  process.exit(1);
});
