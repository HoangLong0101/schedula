const fs = require('node:fs');
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');
const {
  doc,
  getDoc,
  setDoc,
  updateDoc,
} = require('firebase/firestore');

async function main() {
  const environment = await initializeTestEnvironment({
    projectId: 'schedula-rules-test',
    firestore: {
      rules: fs.readFileSync('../firestore.rules', 'utf8'),
    },
  });
  await environment.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'users/staff-1'), {
      tenantId: 'tenant-1',
      role: 'staff',
      permissions: ['booking.status.own', 'customer.read'],
    });
    await setDoc(doc(db, 'bookings/own-booking'), {
      tenantId: 'tenant-1',
      staffId: 'staff-1',
    });
    await setDoc(doc(db, 'bookings/other-booking'), {
      tenantId: 'tenant-1',
      staffId: 'staff-2',
    });
    await setDoc(doc(db, 'auditEvents/audit-1'), {
      tenantId: 'tenant-1',
      actorId: 'owner-1',
    });
    await setDoc(doc(db, 'notifications/notification-1'), {
      tenantId: 'tenant-1',
      recipientUserId: 'staff-1',
      read: false,
    });
  });

  const owner = environment
    .authenticatedContext('owner-1', {
      tenantId: 'tenant-1',
      role: 'owner',
      permissions: [],
    })
    .firestore();
  const staff = environment
    .authenticatedContext('staff-1', {
      tenantId: 'tenant-1',
      role: 'staff',
      permissions: ['booking.status.own', 'customer.read'],
    })
    .firestore();

  await assertSucceeds(getDoc(doc(staff, 'bookings/own-booking')));
  await assertFails(getDoc(doc(staff, 'bookings/other-booking')));
  await assertFails(
    updateDoc(doc(owner, 'bookings/own-booking'), { status: 'cancelled' }),
  );
  await assertSucceeds(getDoc(doc(owner, 'auditEvents/audit-1')));
  await assertFails(
    setDoc(doc(owner, 'auditEvents/forged'), {
      tenantId: 'tenant-1',
    }),
  );
  await assertSucceeds(
    updateDoc(doc(staff, 'notifications/notification-1'), { read: true }),
  );
  await assertFails(
    updateDoc(doc(staff, 'notifications/notification-1'), {
      recipientUserId: 'staff-2',
    }),
  );
  await environment.cleanup();
  console.log('Firestore authorization rules passed');
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
