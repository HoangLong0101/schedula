const admin = require('firebase-admin');

const projectId = process.env.FIREBASE_PROJECT_ID || 'schedula-543b1';
const tenantId = process.env.SEED_TENANT_ID || process.env.TENANT_ID || 'demo-tenant';

admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  projectId,
});

const db = admin.firestore();

async function docs(collection) {
  const snapshot = await db.collection(collection).where('tenantId', '==', tenantId).get();
  return snapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
}

function byId(items) {
  return new Map(items.map((item) => [item.id, item]));
}

function countBy(items, key) {
  const counts = new Map();
  for (const item of items) {
    const value = item[key] || '(missing)';
    counts.set(value, (counts.get(value) || 0) + 1);
  }
  return [...counts.entries()].sort((a, b) => String(a[0]).localeCompare(String(b[0])));
}

function hasSeedMarker(item) {
  return typeof item.id === 'string' && (
    item.id.startsWith('staff-') ||
    item.id.startsWith('customer-') ||
    item.id.startsWith('service-') ||
    item.id.startsWith('booking-') ||
    item.id.startsWith('equipment-')
  );
}

async function countCollection(collection) {
  const snapshot = await db.collection(collection).where('tenantId', '==', tenantId).count().get();
  return snapshot.data().count;
}

async function main() {
  console.log(`Project: ${projectId}`);
  console.log(`Tenant: ${tenantId}`);

  const [users, customers, services, bookings, equipment] = await Promise.all([
    docs('users'),
    docs('customers'),
    docs('services'),
    docs('bookings'),
    docs('equipment'),
  ]);

  const staff = users.filter((user) => user.role === 'staff');
  const customersById = byId(customers);
  const staffById = byId(staff);
  const servicesById = byId(services);

  console.log('\nCore collection counts');
  console.table({
    users: users.length,
    staff: staff.length,
    customers: customers.length,
    services: services.length,
    bookings: bookings.length,
    equipment: equipment.length,
  });

  console.log('\nBooking status counts');
  console.table(Object.fromEntries(countBy(bookings, 'status')));

  const orphanBookings = bookings.filter((booking) =>
    !customersById.has(booking.customerId) ||
    !staffById.has(booking.staffId) ||
    !servicesById.has(booking.serviceId)
  );

  console.log('\nBooking relation audit');
  console.table({
    totalBookings: bookings.length,
    orphanBookings: orphanBookings.length,
    missingCustomer: orphanBookings.filter((booking) => !customersById.has(booking.customerId)).length,
    missingStaff: orphanBookings.filter((booking) => !staffById.has(booking.staffId)).length,
    missingService: orphanBookings.filter((booking) => !servicesById.has(booking.serviceId)).length,
  });

  if (orphanBookings.length > 0) {
    console.log('\nFirst orphan bookings');
    console.table(orphanBookings.slice(0, 10).map((booking) => ({
      id: booking.id,
      customerId: booking.customerId,
      customerOk: customersById.has(booking.customerId),
      staffId: booking.staffId,
      staffOk: staffById.has(booking.staffId),
      serviceId: booking.serviceId,
      serviceOk: servicesById.has(booking.serviceId),
      status: booking.status,
    })));
  }

  console.log('\nSeed/mock id audit');
  console.table({
    seededStaffIds: staff.filter(hasSeedMarker).length,
    seededCustomerIds: customers.filter(hasSeedMarker).length,
    seededServiceIds: services.filter(hasSeedMarker).length,
    seededBookingIds: bookings.filter(hasSeedMarker).length,
    seededEquipmentIds: equipment.filter(hasSeedMarker).length,
  });

  console.log('\nAnalytics collections');
  for (const collection of [
    'dashboardChartData',
    'weeklyRevenue',
    'aiInsights',
    'tenantStatsDaily',
    'staffStatsDaily',
    'serviceStatsDaily',
    'subscriptionPlans',
  ]) {
    try {
      console.log(`${collection}: ${await countCollection(collection)}`);
    } catch (error) {
      console.log(`${collection}: unavailable (${error.message})`);
    }
  }

  console.log('\nSchema compatibility');
  console.table({
    servicesUsingDurationMinOnly: services.filter((service) =>
      service.duration == null && service.durationMin != null
    ).length,
    bookingsMissingDenormalizedNames: bookings.filter((booking) =>
      !booking.customerName || !booking.staffName || !booking.serviceName
    ).length,
  });
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
