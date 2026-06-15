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

async function tenantDocs(collection) {
  const snapshot = await db.collection(collection).where('tenantId', '==', tenantId).get();
  return snapshot.docs.map((doc) => ({ id: doc.id, ref: doc.ref, data: doc.data() }));
}

function localDateKey(timestamp) {
  const date = timestamp.toDate();
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

function dateFromKey(key) {
  return new Date(`${key}T00:00:00+07:00`);
}

function addDays(date, days) {
  return new Date(date.getTime() + days * 24 * 60 * 60 * 1000);
}

function startOfWeek(date) {
  const copy = new Date(date);
  const day = copy.getDay() || 7;
  copy.setDate(copy.getDate() - day + 1);
  copy.setHours(0, 0, 0, 0);
  return copy;
}

function ymd(date) {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

function emptyDaily(key) {
  return {
    tenantId,
    date: Timestamp.fromDate(dateFromKey(key)),
    dateKey: key,
    label: key.slice(5),
    totalBookings: 0,
    completedBookings: 0,
    cancelledBookings: 0,
    noShowBookings: 0,
    confirmedBookings: 0,
    inProgressBookings: 0,
    uniqueCustomers: 0,
    revenue: 0,
    serviceRevenue: {},
    staffBookings: {},
    updatedAt: FieldValue.serverTimestamp(),
  };
}

function bookingRevenue(booking, servicesById) {
  if (typeof booking.paymentAmount === 'number' && booking.paymentStatus === 'paid') {
    return booking.paymentAmount;
  }
  const service = servicesById.get(booking.serviceId);
  if (typeof service?.price === 'number') {
    return service.price;
  }
  return 0;
}

function incrementStatus(target, status) {
  if (status === 'completed') target.completedBookings += 1;
  else if (status === 'cancelled') target.cancelledBookings += 1;
  else if (status === 'no_show') target.noShowBookings += 1;
  else if (status === 'confirmed') target.confirmedBookings += 1;
  else if (status === 'in_progress') target.inProgressBookings += 1;
}

async function replaceCollection(collection, docsById) {
  const current = await tenantDocs(collection);
  const nextIds = new Set(Object.keys(docsById));
  const batch = db.batch();
  let writes = 0;

  for (const currentDoc of current) {
    if (!nextIds.has(currentDoc.id)) {
      console.log(`${dryRun ? '[dry-run] would delete' : 'deleting'} ${collection}/${currentDoc.id}`);
      if (!dryRun) batch.delete(currentDoc.ref);
      writes += 1;
    }
  }

  for (const [id, data] of Object.entries(docsById)) {
    console.log(`${dryRun ? '[dry-run] would upsert' : 'upserting'} ${collection}/${id}`);
    if (!dryRun) batch.set(db.collection(collection).doc(id), data, { merge: false });
    writes += 1;
  }

  if (!dryRun && writes > 0) {
    await batch.commit();
  }
  return writes;
}

function buildDailyStats(bookings, servicesById) {
  const daily = new Map();
  const customerSets = new Map();

  for (const booking of bookings) {
    const data = booking.data;
    if (!data.startTime) continue;

    const key = localDateKey(data.startTime);
    const item = daily.get(key) || emptyDaily(key);
    const customers = customerSets.get(key) || new Set();

    item.totalBookings += 1;
    incrementStatus(item, data.status);

    if (data.customerId) customers.add(data.customerId);
    if (data.status === 'completed') {
      item.revenue += bookingRevenue(data, servicesById);
    }
    if (data.serviceId) {
      item.serviceRevenue[data.serviceId] = (item.serviceRevenue[data.serviceId] || 0) +
        (data.status === 'completed' ? bookingRevenue(data, servicesById) : 0);
    }
    if (data.staffId) {
      item.staffBookings[data.staffId] = (item.staffBookings[data.staffId] || 0) + 1;
    }

    daily.set(key, item);
    customerSets.set(key, customers);
  }

  for (const [key, item] of daily.entries()) {
    item.uniqueCustomers = customerSets.get(key)?.size || 0;
  }

  return daily;
}

function buildDashboardChartData(daily) {
  const keys = [...daily.keys()].sort();
  const lastKeys = keys.slice(-7);
  return Object.fromEntries(lastKeys.map((key) => {
    const item = daily.get(key);
    return [key, {
      tenantId,
      date: item.date,
      dateKey: key,
      day: item.label,
      appointments: item.totalBookings,
      completedBookings: item.completedBookings,
      cancelledBookings: item.cancelledBookings,
      revenue: item.revenue,
      uniqueCustomers: item.uniqueCustomers,
      updatedAt: FieldValue.serverTimestamp(),
    }];
  }));
}

function buildWeeklyRevenue(daily) {
  const weeks = new Map();
  for (const item of daily.values()) {
    const start = startOfWeek(item.date.toDate());
    const key = ymd(start);
    const week = weeks.get(key) || {
      tenantId,
      weekStart: Timestamp.fromDate(start),
      weekEnd: Timestamp.fromDate(addDays(start, 6)),
      week: key,
      revenue: 0,
      bookingCount: 0,
      completedBookings: 0,
      cancelledBookings: 0,
      updatedAt: FieldValue.serverTimestamp(),
    };
    week.revenue += item.revenue;
    week.bookingCount += item.totalBookings;
    week.completedBookings += item.completedBookings;
    week.cancelledBookings += item.cancelledBookings;
    weeks.set(key, week);
  }
  return Object.fromEntries([...weeks.entries()].sort().slice(-8));
}

function buildTenantStatsDaily(daily) {
  return Object.fromEntries([...daily.entries()].sort().map(([key, item]) => [
    `${tenantId}_${key}`,
    item,
  ]));
}

function buildStaffStatsDaily(bookings, servicesById, staffById) {
  const stats = new Map();
  for (const booking of bookings) {
    const data = booking.data;
    if (!data.startTime || !data.staffId) continue;
    const key = `${tenantId}_${data.staffId}_${localDateKey(data.startTime)}`;
    const item = stats.get(key) || {
      tenantId,
      staffId: data.staffId,
      staffName: data.staffName || staffById.get(data.staffId)?.name || '',
      date: Timestamp.fromDate(dateFromKey(localDateKey(data.startTime))),
      dateKey: localDateKey(data.startTime),
      totalBookings: 0,
      completedBookings: 0,
      cancelledBookings: 0,
      revenue: 0,
      updatedAt: FieldValue.serverTimestamp(),
    };
    item.totalBookings += 1;
    incrementStatus(item, data.status);
    if (data.status === 'completed') {
      item.revenue += bookingRevenue(data, servicesById);
    }
    stats.set(key, item);
  }
  return Object.fromEntries(stats);
}

function buildServiceStatsDaily(bookings, servicesById) {
  const stats = new Map();
  for (const booking of bookings) {
    const data = booking.data;
    if (!data.startTime || !data.serviceId) continue;
    const key = `${tenantId}_${data.serviceId}_${localDateKey(data.startTime)}`;
    const service = servicesById.get(data.serviceId);
    const item = stats.get(key) || {
      tenantId,
      serviceId: data.serviceId,
      serviceName: data.serviceName || service?.name || '',
      date: Timestamp.fromDate(dateFromKey(localDateKey(data.startTime))),
      dateKey: localDateKey(data.startTime),
      totalBookings: 0,
      completedBookings: 0,
      revenue: 0,
      updatedAt: FieldValue.serverTimestamp(),
    };
    item.totalBookings += 1;
    incrementStatus(item, data.status);
    if (data.status === 'completed') {
      item.revenue += bookingRevenue(data, servicesById);
    }
    stats.set(key, item);
  }
  return Object.fromEntries(stats);
}

function buildAiInsights(bookings, daily, servicesById) {
  const total = bookings.length;
  const cancelled = bookings.filter((booking) => booking.data.status === 'cancelled').length;
  const cancellationRate = total === 0 ? 0 : cancelled / total;
  const sortedDays = [...daily.values()].sort((a, b) => b.totalBookings - a.totalBookings);
  const bestDay = sortedDays[0];

  const serviceRevenue = new Map();
  for (const item of daily.values()) {
    for (const [serviceId, revenue] of Object.entries(item.serviceRevenue)) {
      serviceRevenue.set(serviceId, (serviceRevenue.get(serviceId) || 0) + revenue);
    }
  }
  const topServiceEntry = [...serviceRevenue.entries()].sort((a, b) => b[1] - a[1])[0];
  const topService = topServiceEntry ? servicesById.get(topServiceEntry[0]) : null;

  return {
    'real-volume': {
      tenantId,
      type: 'volume',
      title: bestDay
        ? `Ngày bận nhất: ${bestDay.dateKey}`
        : 'Chưa có dữ liệu lịch hẹn',
      description: bestDay
        ? `${bestDay.totalBookings} lịch hẹn, ${bestDay.completedBookings} hoàn thành, doanh thu ${bestDay.revenue.toLocaleString('vi-VN')} VND.`
        : 'Khi có lịch hẹn, hệ thống sẽ tự tính ngày bận nhất.',
      severity: 'info',
      generatedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    },
    'real-cancellation': {
      tenantId,
      type: 'cancellation',
      title: `Tỷ lệ hủy ${(cancellationRate * 100).toFixed(1)}%`,
      description: cancellationRate > 0.15
        ? 'Tỷ lệ hủy đang cao, nên tăng nhắc lịch 24h và xác nhận trước giờ hẹn.'
        : 'Tỷ lệ hủy đang ổn định so với tổng lịch hẹn hiện có.',
      severity: cancellationRate > 0.15 ? 'warning' : 'success',
      generatedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    },
    'real-top-service': {
      tenantId,
      type: 'service',
      title: topService ? `Dịch vụ doanh thu cao: ${topService.name}` : 'Chưa có doanh thu dịch vụ',
      description: topServiceEntry
        ? `Doanh thu ghi nhận ${topServiceEntry[1].toLocaleString('vi-VN')} VND từ lịch hoàn thành.`
        : 'Doanh thu sẽ được tính từ lịch hoàn thành và giá dịch vụ.',
      severity: 'info',
      generatedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    },
  };
}

async function main() {
  console.log(`Project: ${projectId}`);
  console.log(`Tenant: ${tenantId}`);
  console.log(`Mode: ${dryRun ? 'dry-run' : 'write'}`);

  const [bookings, services, users] = await Promise.all([
    tenantDocs('bookings'),
    tenantDocs('services'),
    tenantDocs('users'),
  ]);

  const servicesById = new Map(services.map((doc) => [doc.id, doc.data]));
  const staffById = new Map(users.filter((doc) => doc.data.role === 'staff').map((doc) => [doc.id, doc.data]));
  const daily = buildDailyStats(bookings, servicesById);

  const writeCounts = {};
  writeCounts.dashboardChartData = await replaceCollection('dashboardChartData', buildDashboardChartData(daily));
  writeCounts.weeklyRevenue = await replaceCollection('weeklyRevenue', buildWeeklyRevenue(daily));
  writeCounts.aiInsights = await replaceCollection('aiInsights', buildAiInsights(bookings, daily, servicesById));
  writeCounts.tenantStatsDaily = await replaceCollection('tenantStatsDaily', buildTenantStatsDaily(daily));
  writeCounts.staffStatsDaily = await replaceCollection('staffStatsDaily', buildStaffStatsDaily(bookings, servicesById, staffById));
  writeCounts.serviceStatsDaily = await replaceCollection('serviceStatsDaily', buildServiceStatsDaily(bookings, servicesById));

  console.log('\nAggregate summary');
  console.table({
    bookings: bookings.length,
    dailyDocs: daily.size,
    ...writeCounts,
  });
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
