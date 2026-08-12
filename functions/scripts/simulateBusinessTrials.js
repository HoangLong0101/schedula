const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const admin = require('firebase-admin');

const projectId = process.env.FIREBASE_PROJECT_ID || 'schedula-543b1';
const batchId = 'outreach-trials-2026-08';
const asOf = process.env.SIMULATION_AS_OF || '2026-08-12';
const args = process.argv.slice(2);
const mode = args.includes('--write') ? 'write' : args.includes('--verify') ? 'verify' : 'dry-run';
const workbookPath = valueAfter('--workbook');
const credentialsPath = valueAfter('--credentials');

if (!workbookPath) throw new Error('Pass --workbook PATH');
if (mode === 'write' && !credentialsPath) {
  throw new Error('Pass --credentials PATH when using --write');
}

admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  projectId,
});
const db = admin.firestore();
const auth = admin.auth();
const { FieldValue, Timestamp } = admin.firestore;

const services = [
  ['Massage toàn thân thư giãn', 550000, 90, 'Massage'],
  ['Massage đá nóng', 650000, 90, 'Massage'],
  ['Massage tinh dầu', 450000, 75, 'Massage'],
  ['Chăm sóc da mặt cơ bản', 400000, 60, 'Da mặt'],
  ['Làm sạch sâu và cấp ẩm', 500000, 60, 'Da mặt'],
  ['Điều trị mụn chuyên sâu', 750000, 75, 'Da liễu'],
  ['Điều trị nám và sắc tố', 900000, 90, 'Da liễu'],
  ['Soi da và tư vấn liệu trình', 300000, 45, 'Da liễu'],
];
const familyNames = ['Nguyễn', 'Trần', 'Lê', 'Phạm', 'Hoàng', 'Huỳnh', 'Phan', 'Vũ', 'Võ', 'Đặng', 'Bùi', 'Đỗ', 'Hồ', 'Ngô', 'Dương'];
const femaleNames = ['Mai Anh', 'Bảo Châu', 'Ngọc Diệp', 'Thu Hà', 'Khánh Linh', 'Hương Giang', 'Minh Ngọc', 'Thanh Tâm', 'Thảo Vy', 'Quỳnh Anh', 'Bích Trâm', 'Kim Oanh'];
const maleNames = ['Minh Anh', 'Quốc Bảo', 'Đức Huy', 'Hoàng Long', 'Tuấn Kiệt', 'Gia Minh', 'Thanh Phong', 'Hữu Phước'];
const colors = ['#148A9C', '#22AFC2', '#16A34A', '#7C3AED', '#EA580C', '#DB2777'];
const roleTitles = [
  ['Chuyên viên massage trị liệu', ['Massage trị liệu', 'Massage đá nóng']],
  ['Kỹ thuật viên massage thư giãn', ['Massage thư giãn', 'Massage tinh dầu']],
  ['Chuyên viên chăm sóc da', ['Chăm sóc da mặt', 'Làm sạch sâu']],
  ['Kỹ thuật viên da liễu', ['Điều trị mụn', 'Điều trị sắc tố']],
  ['Chuyên viên facial', ['Soi da', 'Chăm sóc da chuyên sâu']],
];

function valueAfter(flag) {
  const index = args.indexOf(flag);
  return index >= 0 ? args[index + 1] : null;
}

function extractWorkbook() {
  const script = path.join(__dirname, 'simulationWorkbook.py');
  const result = spawnSync('python', ['-X', 'utf8', script, 'extract', workbookPath], {
    encoding: 'utf8',
    maxBuffer: 4 * 1024 * 1024,
  });
  if (result.status !== 0) throw new Error(result.stderr || 'Workbook extraction failed');
  return JSON.parse(result.stdout).businesses;
}

function writeCredentials(records) {
  const script = path.join(__dirname, 'simulationWorkbook.py');
  const result = spawnSync('python', ['-X', 'utf8', script, 'credentials', credentialsPath], {
    encoding: 'utf8',
    input: JSON.stringify(records),
  });
  if (result.status !== 0) throw new Error(result.stderr || 'Credential workbook failed');
}

function asciiText(value) {
  return value.normalize('NFD').replace(/[\u0300-\u036f]/g, '')
    .replace(/đ/g, 'd').replace(/Đ/g, 'D').toLowerCase()
    .replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
}

function asciiSlug(value) {
  return asciiText(value).slice(0, 34);
}

function hash32(value) {
  const hash = crypto.createHash('sha256').update(value).digest();
  return hash.readUInt32LE(0);
}

function rngFor(value) {
  let state = hash32(value);
  return () => {
    state += 0x6D2B79F5;
    let result = state;
    result = Math.imul(result ^ (result >>> 15), result | 1);
    result ^= result + Math.imul(result ^ (result >>> 7), result | 61);
    return ((result ^ (result >>> 14)) >>> 0) / 4294967296;
  };
}

function parseSourceDate(value) {
  const match = /^(\d{1,2})\/(\d{1,2})$/.exec(value);
  if (!match) throw new Error(`Invalid source date: ${value}`);
  return `2026-${match[2].padStart(2, '0')}-${match[1].padStart(2, '0')}`;
}

function dateFromYmd(value) {
  return new Date(`${value}T00:00:00.000Z`);
}

function ymd(date) {
  return date.toISOString().slice(0, 10);
}

function addDays(value, days) {
  const date = dateFromYmd(value);
  date.setUTCDate(date.getUTCDate() + days);
  return ymd(date);
}

function daysInclusive(start, end) {
  const values = [];
  for (let value = start; value <= end; value = addDays(value, 1)) values.push(value);
  return values;
}

function localTimestamp(date, time = '00:00') {
  return Timestamp.fromDate(new Date(`${date}T${time}:00+07:00`));
}

function staffCount(band, sourceId) {
  const normalized = band.toLowerCase();
  if (normalized.includes('dưới 5')) return 4;
  if (normalized.includes('5') && normalized.includes('10')) return 5 + (hash32(`${sourceId}:staff`) % 6);
  if (normalized.includes('11') && normalized.includes('20')) return 11 + (hash32(`${sourceId}:staff`) % 10);
  if (normalized.includes('trên 20')) return 22 + (hash32(`${sourceId}:staff`) % 7);
  throw new Error(`Unsupported staff band: ${band}`);
}

function taperAfterDays(note) {
  const normalized = asciiText(note);
  const days = /sau-(\d+)-ngay/.exec(normalized);
  if (days) return Number(days[1]);
  if (normalized.includes('sau-1-tuan')) return 7;
  return null;
}

function authUid(email) {
  return `sim-${crypto.createHash('sha256').update(email).digest('hex').slice(0, 28)}`;
}

function temporaryPassword() {
  return `Sc!${crypto.randomBytes(12).toString('base64url')}`;
}

function normalizedPhone(value) {
  const digits = value.replace(/\D/g, '');
  return digits.length >= 9 ? digits : '';
}

function buildPlan(businesses) {
  assert.equal(businesses.length, 11, 'Expected 11 visible tenant rows');
  const seenContacts = new Set();
  const tenants = businesses.map((business) => {
    if (!business.startDate) throw new Error(`Missing start date for ${business.name}`);
    const tenantId = `sim-2026-${String(business.sourceId).padStart(2, '0')}-${asciiSlug(business.name)}`;
    const startDate = parseSourceDate(business.startDate);
    const endDate = business.endDate ? parseSourceDate(business.endDate) : null;
    const journeyEnd = endDate || asOf;
    const count = staffCount(business.staffBand, business.sourceId);
    const sourceContact = business.contact.trim();
    const ownerEmail = sourceContact.includes('@')
      ? sourceContact.toLowerCase()
      : `owner.${String(business.sourceId).padStart(2, '0')}@schedula.demo`;
    if (seenContacts.has(ownerEmail)) throw new Error(`Duplicate owner email: ${ownerEmail}`);
    seenContacts.add(ownerEmail);
    return {
      ...business,
      tenantId,
      startDate,
      endDate,
      journeyEnd,
      staffCount: count,
      ownerEmail,
      ownerPhone: sourceContact.includes('@') ? '' : normalizedPhone(sourceContact),
      taperDay: taperAfterDays(business.note),
    };
  });
  return tenants.map(buildTenantData);
}

function buildTenantData(tenant) {
  const random = rngFor(tenant.tenantId);
  const owner = {
    uid: authUid(tenant.ownerEmail),
    tenantId: tenant.tenantId,
    tenantName: tenant.name,
    role: 'owner',
    name: tenant.contactName,
    email: tenant.ownerEmail,
    phone: tenant.ownerPhone,
    sourceContact: tenant.contact,
  };
  const staff = [];
  for (let index = 0; index < tenant.staffCount; index += 1) {
    const female = index % 4 !== 3;
    const given = female
      ? femaleNames[(index + tenant.sourceId) % femaleNames.length]
      : maleNames[(index + tenant.sourceId) % maleNames.length];
    const name = `${familyNames[(index * 3 + tenant.sourceId) % familyNames.length]} ${given}`;
    const role = roleTitles[(index + tenant.sourceId) % roleTitles.length];
    const email = `staff.${String(tenant.sourceId).padStart(2, '0')}.${String(index + 1).padStart(2, '0')}@schedula.demo`;
    const age = 20 + (hash32(`${tenant.tenantId}:${index}:age`) % 16);
    staff.push({
      uid: authUid(email), tenantId: tenant.tenantId, tenantName: tenant.name,
      role: 'staff', name, email, phone: `09${String(10000000 + (hash32(email) % 90000000))}`,
      sourceContact: '', age, roleTitle: role[0], specialties: role[1],
      color: colors[index % colors.length], appointments: 0,
    });
  }

  const serviceDocs = services.map((service, index) => ({
    id: `${tenant.tenantId}-service-${String(index + 1).padStart(2, '0')}`,
    data: {
      tenantId: tenant.tenantId, name: service[0], price: service[1],
      duration: service[2], durationMin: service[2], category: service[3],
      resources: [], resourceIds: [], isActive: true,
    },
  }));
  const customerCount = Math.max(16, tenant.staffCount * 4);
  const customers = Array.from({ length: customerCount }, (_, index) => {
    const female = index % 2 === 0;
    const given = female
      ? femaleNames[(index * 2 + tenant.sourceId) % femaleNames.length]
      : maleNames[(index * 2 + tenant.sourceId) % maleNames.length];
    const name = `${familyNames[(index * 5 + tenant.sourceId + 2) % familyNames.length]} ${given}`;
    return {
      id: `${tenant.tenantId}-customer-${String(index + 1).padStart(3, '0')}`,
      name,
      phone: `09${String(10000000 + (hash32(`${tenant.tenantId}:customer:${index}`) % 90000000))}`,
      email: `customer.${tenant.sourceId}.${index + 1}@example.test`,
      visits: 0, spent: 0, lastVisit: tenant.startDate,
    };
  });
  const bookings = [];
  const payments = [];
  const slots = new Map();
  const tenantStats = new Map();
  const staffStats = new Map();
  const serviceStats = new Map();
  let bookingSequence = 0;
  const dates = daysInclusive(tenant.startDate, tenant.journeyEnd);
  dates.forEach((date, dayIndex) => {
    const weekday = dateFromYmd(date).getUTCDay();
    let daily = Math.max(2, Math.round(tenant.staffCount * (0.8 + random() * 0.45)));
    if (weekday === 0) daily = Math.max(1, Math.round(daily * 0.65));
    if (tenant.taperDay !== null && dayIndex >= tenant.taperDay) {
      daily = Math.max(1, Math.round(daily * (0.28 + random() * 0.12)));
    }
    for (let index = 0; index < daily; index += 1) {
      bookingSequence += 1;
      const member = staff[index % staff.length];
      const round = Math.floor(index / staff.length);
      const service = serviceDocs[Math.floor(random() * serviceDocs.length)];
      const customer = customers[Math.floor(random() * customers.length)];
      const startMinutes = 9 * 60 + round * 120 + (index % 3) * 15;
      const startHour = String(Math.floor(startMinutes / 60)).padStart(2, '0');
      const startMinute = String(startMinutes % 60).padStart(2, '0');
      const startTime = localTimestamp(date, `${startHour}:${startMinute}`);
      const endTime = Timestamp.fromMillis(startTime.toMillis() + service.data.duration * 60000);
      const roll = random();
      const status = roll < 0.88 ? 'completed' : roll < 0.95 ? 'cancelled' : 'no_show';
      const bookingId = `${tenant.tenantId}-booking-${String(bookingSequence).padStart(5, '0')}`;
      const amount = status === 'completed' ? service.data.price : 0;
      const paymentId = status === 'completed' ? `${tenant.tenantId}-payment-${String(bookingSequence).padStart(5, '0')}` : null;
      bookings.push({
        id: bookingId,
        data: {
          tenantId: tenant.tenantId, staffId: member.uid, customerId: customer.id,
          serviceId: service.id, startTime, endTime, status,
          customerName: customer.name, staffName: member.name, serviceName: service.data.name,
          notes: 'Dữ liệu mô phỏng hành trình dùng thử từ danh sách tiếp cận.',
          createdBy: owner.uid, createdAt: startTime, updatedAt: endTime,
          reminder24Sent: true, reminder1hSent: true, resourceIds: [],
          paymentStatus: status === 'completed' ? 'paid' : null,
          paymentId, paymentAmount: amount || null,
          paymentMethod: status === 'completed' ? (random() < 0.62 ? 'cash' : 'bank_transfer') : null,
          paymentPaidAt: status === 'completed' ? endTime : null,
        },
      });
      member.appointments += 1;
      customer.visits += status === 'completed' ? 1 : 0;
      customer.spent += amount;
      if (status === 'completed') customer.lastVisit = date;
      if (status === 'completed') {
        payments.push({
          id: paymentId,
          data: {
            tenantId: tenant.tenantId, type: 'manual', bookingId, status: 'paid',
            method: bookings.at(-1).data.paymentMethod, amount,
            reference: `SIM-${tenant.sourceId}-${bookingSequence}`,
            recordedBy: owner.uid, recordedAt: endTime, paidAt: endTime, createdAt: endTime,
            reconciliationStatus: 'matched',
          },
        });
        incrementStats(tenantStats, date, amount);
        incrementStats(staffStats, `${member.uid}|${date}`, amount);
        incrementStats(serviceStats, `${service.id}|${date}`, amount);
      }
      if (!['cancelled', 'no_show'].includes(status)) {
        const slotId = `${date}_${member.uid}`;
        const slot = slots.get(slotId) || { staffId: member.uid, date, intervals: [] };
        slot.intervals.push({ startTime, endTime, bookingId });
        slots.set(slotId, slot);
      }
    }
  });

  const customerDocs = customers.map((customer, index) => ({
    id: customer.id,
    data: {
      tenantId: tenant.tenantId, name: customer.name, phone: customer.phone,
      email: customer.email, birthday: `199${index % 8}-${String((index % 12) + 1).padStart(2, '0')}-${String((index % 27) + 1).padStart(2, '0')}`,
      notes: index % 3 === 0 ? 'Khách quay lại định kỳ.' : '', allergies: '',
      lastVisit: localTimestamp(customer.lastVisit), visitCount: customer.visits,
      totalVisits: customer.visits, spent: customer.spent,
      avatar: initials(customer.name), color: colors[index % colors.length],
      emailMarketingConsent: index % 4 !== 0, emailOptedOut: false,
      createdAt: localTimestamp(tenant.startDate),
    },
  }));

  return {
    tenant, owner, staff,
    docs: {
      services: serviceDocs, customers: customerDocs, bookings, payments,
      slots: [...slots.entries()].map(([id, slot]) => ({
        id: `${tenant.tenantId}_${id}`,
        data: {
          tenantId: tenant.tenantId, staffId: slot.staffId,
          date: localTimestamp(slot.date), intervals: slot.intervals,
        },
      })),
      tenantStatsDaily: statsDocs(tenantStats, tenant, null, null),
      staffStatsDaily: statsDocs(staffStats, tenant, 'staffId', staff),
      serviceStatsDaily: statsDocs(serviceStats, tenant, 'serviceId', serviceDocs),
    },
  };
}

function incrementStats(map, key, amount) {
  const current = map.get(key) || { completedBookings: 0, revenue: 0 };
  current.completedBookings += 1;
  current.revenue += amount;
  map.set(key, current);
}

function statsDocs(map, tenant, entityField, entities) {
  return [...map.entries()].map(([key, stats]) => {
    const parts = key.split('|');
    const entityId = entityField ? parts[0] : null;
    const date = entityField ? parts[1] : parts[0];
    const entity = entityField ? entities.find((item) => (item.uid || item.id) === entityId) : null;
    return {
      id: entityField ? `${tenant.tenantId}_${entityId}_${date}` : `${tenant.tenantId}_${date}`,
      data: {
        tenantId: tenant.tenantId, date: localTimestamp(date), dateKey: date,
        ...stats,
        ...(entityField ? { [entityField]: entityId } : {}),
        ...(entityField === 'staffId' ? { staffName: entity.name } : {}),
        ...(entityField === 'serviceId' ? { serviceName: entity.data.name } : {}),
      },
    };
  });
}

function initials(name) {
  return name.split(/\s+/).slice(-2).map((part) => part[0]).join('').toUpperCase();
}

function allAccounts(plans) {
  return plans.flatMap((plan) => [plan.owner, ...plan.staff]);
}

async function inspectAccount(account) {
  let user = null;
  try {
    user = await auth.getUserByEmail(account.email);
  } catch (error) {
    if (error.code !== 'auth/user-not-found') throw error;
  }
  if (!user) {
    try {
      const uidUser = await auth.getUser(account.uid);
      throw new Error(`UID collision for ${account.email}: ${uidUser.email}`);
    } catch (error) {
      if (error.code !== 'auth/user-not-found') throw error;
    }
    return { account, state: 'new' };
  }
  const profile = await db.collection('users').doc(user.uid).get();
  if (
    user.uid !== account.uid ||
    profile.data()?.simulationBatchId !== batchId ||
    profile.data()?.tenantId !== account.tenantId
  ) {
    throw new Error(`Existing non-simulation account collision: ${account.email}`);
  }
  return {
    account: { ...account, uid: user.uid },
    state: 'existing',
    mustChangePassword:
      user.customClaims?.mustChangePassword === true ||
      profile.data()?.mustChangePassword === true,
  };
}

async function inspectAccounts(accounts) {
  const results = [];
  for (let index = 0; index < accounts.length; index += 8) {
    results.push(...await Promise.all(accounts.slice(index, index + 8).map(inspectAccount)));
  }
  return results;
}

async function inspectTenants(plans) {
  for (const plan of plans) {
    const snapshot = await db.collection('tenants').doc(plan.tenant.tenantId).get();
    if (snapshot.exists && snapshot.data()?.simulationBatchId !== batchId) {
      throw new Error(`Existing non-simulation tenant collision: ${plan.tenant.tenantId}`);
    }
  }
}

function summary(plans) {
  return plans.map((plan) => ({
    tenant: plan.tenant.name,
    staff: plan.staff.length,
    customers: plan.docs.customers.length,
    bookings: plan.docs.bookings.length,
    completed: plan.docs.payments.length,
    start: plan.tenant.startDate,
    end: plan.tenant.journeyEnd,
    taperAfterDays: plan.tenant.taperDay ?? 'steady',
  }));
}

async function ensureAuthAccount(record) {
  const account = record.account;
  const mustChangePassword =
    record.state === 'new' || record.mustChangePassword === true;
  if (record.state === 'new') {
    await auth.createUser({
      uid: account.uid, email: account.email, password: account.temporaryPassword,
      displayName: account.name, disabled: false,
    });
  } else {
    await auth.updateUser(account.uid, { displayName: account.name, disabled: false });
  }
  const permissions = account.role === 'owner'
    ? ['booking.manage', 'booking.status.own', 'customer.read', 'customer.write', 'staff.manage', 'report.read', 'campaign.send']
    : ['booking.status.own', 'customer.read'];
  await auth.setCustomUserClaims(account.uid, {
    role: account.role, tenantId: account.tenantId, permissions,
    mustChangePassword, simulationBatchId: batchId,
  });
}

async function writeAccountProfile(account, plan, record) {
  const isOwner = account.role === 'owner';
  const mustChangePassword =
    record.state === 'new' || record.mustChangePassword === true;
  const birthDate = !isOwner
    ? localTimestamp(`${Number(plan.tenant.startDate.slice(0, 4)) - account.age}-${plan.tenant.startDate.slice(5)}`)
    : null;
  await db.collection('users').doc(account.uid).set({
    tenantId: account.tenantId, role: account.role, name: account.name,
    email: account.email, phone: account.phone, active: true,
    mustChangePassword, simulationBatchId: batchId,
    createdAt: localTimestamp(plan.tenant.startDate), updatedAt: FieldValue.serverTimestamp(),
    ...(isOwner ? {} : {
      role_title: account.roleTitle, status: 'available', color: account.color,
      appointments: account.appointments, rating: 4.5 + ((account.age % 5) / 10),
      specialties: account.specialties, age: account.age, birthDate,
      permissions: ['booking.status.own', 'customer.read'],
      shift: { mon: 'full', tue: 'full', wed: 'full', thu: 'full', fri: 'full', sat: 'full', sun: 'off' },
    }),
  }, { merge: true });
}

async function writeTenant(plan) {
  const tenant = plan.tenant;
  const active = !tenant.endDate;
  await db.collection('tenants').doc(tenant.tenantId).set({
    tenantId: tenant.tenantId, ownerUid: plan.owner.uid, name: tenant.name,
    type: tenant.type, address: tenant.area, phone: plan.owner.phone,
    website: '', hoursWeekday: '08:30 - 19:30', hoursWeekend: '09:00 - 18:00',
    description: tenant.note || `${tenant.type} tại ${tenant.area}`,
    staffReminderLeadMinutes: 60, timezone: 'Asia/Ho_Chi_Minh',
    bookingPolicy: { timezone: 'Asia/Ho_Chi_Minh', weekdayHours: '08:30 - 19:30', weekendHours: '09:00 - 18:00' },
    branchCount: tenant.branches, staffBand: tenant.staffBand,
    sourceStatus: tenant.status, sourceNote: tenant.note, source: tenant.source,
    trialStatus: active ? 'active' : 'expired', planTier: 'basic',
    planStartedAt: localTimestamp(tenant.startDate),
    planExpiresAt: localTimestamp(tenant.endDate || addDays(tenant.startDate, 29)),
    simulationBatchId: batchId, createdAt: localTimestamp(tenant.startDate),
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });
}

async function writeJourney(plan) {
  const writer = db.bulkWriter();
  writer.onWriteError((error) => error.failedAttempts < 3);
  for (const [collection, docs] of Object.entries(plan.docs)) {
    for (const item of docs) {
      writer.set(db.collection(collection).doc(item.id), {
        ...item.data, simulationBatchId: batchId,
        updatedAt: item.data.updatedAt || FieldValue.serverTimestamp(),
      }, { merge: true });
    }
  }
  await writer.close();
}

async function writeSimulation(plans, accountStates) {
  const stateByEmail = new Map(accountStates.map((item) => [item.account.email, item]));
  const credentials = accountStates.map((item) => ({
    tenantName: item.account.tenantName, tenantId: item.account.tenantId,
    role: item.account.role, name: item.account.name, email: item.account.email,
    temporaryPassword: item.account.temporaryPassword || '',
    accountStatus: item.state, sourceContact: item.account.sourceContact,
  }));
  writeCredentials(credentials);

  console.log('Phase 1/3: tenant owners and business profiles');
  for (const plan of plans) {
    const record = stateByEmail.get(plan.owner.email);
    await ensureAuthAccount(record);
    await writeTenant(plan);
    await writeAccountProfile(record.account, plan, record);
  }

  console.log('Phase 2/3: Vietnamese staff accounts and profiles');
  for (const plan of plans) {
    for (const member of plan.staff) {
      const record = stateByEmail.get(member.email);
      await ensureAuthAccount(record);
      await writeAccountProfile(record.account, plan, record);
    }
  }

  console.log('Phase 3/3: customer and usage journeys');
  for (const plan of plans) {
    await writeJourney(plan);
    console.log(`  ${plan.tenant.name}: ${plan.docs.bookings.length} bookings`);
  }
}

async function count(collection, tenantId) {
  const result = await db.collection(collection).where('tenantId', '==', tenantId).count().get();
  return result.data().count;
}

async function verify(plans) {
  const collections = ['users', 'services', 'customers', 'bookings', 'payments', 'slots', 'tenantStatsDaily', 'staffStatsDaily', 'serviceStatsDaily'];
  for (const plan of plans) {
    const expected = {
      users: plan.staff.length + 1,
      ...Object.fromEntries(Object.entries(plan.docs).map(([name, docs]) => [name, docs.length])),
    };
    const actual = Object.fromEntries(await Promise.all(
      collections.map(async (name) => [name, await count(name, plan.tenant.tenantId)]),
    ));
    assert.deepEqual(actual, expected, `Count mismatch for ${plan.tenant.name}`);
    const tenantSnapshot = await db.collection('tenants').doc(plan.tenant.tenantId).get();
    assert.equal(tenantSnapshot.data()?.simulationBatchId, batchId);
    for (const account of [plan.owner, ...plan.staff]) {
      const user = await auth.getUser(account.uid);
      assert.equal(user.customClaims?.tenantId, plan.tenant.tenantId);
      assert.equal(user.customClaims?.role, account.role);
    }
    console.log(`Verified ${plan.tenant.name}: ${actual.users} users, ${actual.bookings} bookings`);
  }
}

async function main() {
  const plans = buildPlan(extractWorkbook());
  console.table(summary(plans));
  console.log(`Totals: ${plans.length} tenants, ${plans.reduce((sum, p) => sum + p.staff.length, 0)} staff, ${plans.reduce((sum, p) => sum + p.docs.bookings.length, 0)} bookings`);
  if (mode === 'verify') {
    await verify(plans);
    return;
  }
  await inspectTenants(plans);
  const states = await inspectAccounts(allAccounts(plans));
  console.log(`Account check: ${states.filter((item) => item.state === 'new').length} new, ${states.filter((item) => item.state === 'existing').length} existing simulation accounts`);
  if (mode === 'dry-run') return;
  for (const item of states) {
    if (item.state === 'new') item.account.temporaryPassword = temporaryPassword();
  }
  await writeSimulation(plans, states);
  await verify(plans);
  console.log(`Credentials written to ${credentialsPath}`);
}

main().then(() => process.exit(0)).catch((error) => {
  console.error(error.message || error);
  process.exit(1);
});
