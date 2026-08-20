const fs = require('node:fs');
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');
const {
  doc,
  deleteDoc,
  getDoc,
  getDocs,
  collection,
  query,
  setDoc,
  updateDoc,
  where,
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
    await setDoc(doc(db, 'users/staff-2'), {
      tenantId: 'tenant-1',
      role: 'staff',
      name: 'Staff Two',
      active: true,
    });
    await setDoc(doc(db, 'users/other-owner'), {
      tenantId: 'tenant-2',
      role: 'owner',
    });
    await setDoc(doc(db, 'customers/existing-customer'), {
      tenantId: 'tenant-1',
      name: 'Existing Customer',
      phone: '0900000000',
    });
    await setDoc(doc(db, 'customers/other-customer'), {
      tenantId: 'tenant-2',
      name: 'Other Customer',
      phone: '0911111111',
    });
    await setDoc(doc(db, 'equipment/existing-equipment'), {
      tenantId: 'tenant-1',
      name: 'Laser',
      status: 'available',
    });
    await setDoc(doc(db, 'equipment/other-equipment'), {
      tenantId: 'tenant-2',
      name: 'Other Laser',
      status: 'available',
    });
    await setDoc(doc(db, 'payments/payment-1'), {
      tenantId: 'tenant-1',
      amount: 100,
    });
    await setDoc(doc(db, 'campaigns/campaign-1'), {
      tenantId: 'tenant-1',
      status: 'sent',
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
  const receptionist = environment
    .authenticatedContext('receptionist-1', {
      tenantId: 'tenant-1',
      role: 'receptionist',
      permissions: ['customer.read', 'customer.write', 'report.read'],
    })
    .firestore();

  await assertSucceeds(getDoc(doc(staff, 'bookings/own-booking')));
  await assertFails(getDoc(doc(staff, 'bookings/other-booking')));
  await assertFails(
    updateDoc(doc(owner, 'bookings/own-booking'), { status: 'cancelled' }),
  );

  await assertSucceeds(
    setDoc(doc(owner, 'customers/new-customer'), {
      tenantId: 'tenant-1',
      name: 'New Customer',
      phone: '0922222222',
    }),
  );
  await assertSucceeds(
    updateDoc(doc(owner, 'customers/new-customer'), { name: 'Updated' }),
  );
  await assertSucceeds(deleteDoc(doc(owner, 'customers/new-customer')));
  await assertSucceeds(
    setDoc(doc(receptionist, 'customers/reception-customer'), {
      tenantId: 'tenant-1',
      name: 'Reception Customer',
      phone: '0933333333',
    }),
  );
  await assertSucceeds(
    getDocs(
      query(
        collection(owner, 'customers'),
        where('tenantId', '==', 'tenant-1'),
      ),
    ),
  );
  await assertFails(getDoc(doc(owner, 'customers/other-customer')));
  await assertSucceeds(getDoc(doc(staff, 'customers/existing-customer')));
  await assertFails(
    updateDoc(doc(staff, 'customers/existing-customer'), { name: 'Denied' }),
  );

  await assertSucceeds(
    setDoc(doc(owner, 'equipment/new-equipment'), {
      tenantId: 'tenant-1',
      name: 'Bed',
      status: 'available',
    }),
  );
  await assertSucceeds(
    updateDoc(doc(owner, 'equipment/new-equipment'), { status: 'in_use' }),
  );
  await assertSucceeds(deleteDoc(doc(owner, 'equipment/new-equipment')));
  await assertFails(getDoc(doc(owner, 'equipment/other-equipment')));
  await assertFails(
    setDoc(doc(receptionist, 'equipment/denied-equipment'), {
      tenantId: 'tenant-1',
      name: 'Denied',
    }),
  );

  await assertSucceeds(
    updateDoc(doc(owner, 'users/staff-2'), { name: 'Renamed Staff' }),
  );
  await assertFails(
    updateDoc(doc(owner, 'users/staff-2'), { role: 'receptionist' }),
  );
  await assertSucceeds(getDoc(doc(owner, 'payments/payment-1')));
  await assertSucceeds(getDoc(doc(owner, 'campaigns/campaign-1')));
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
