const admin = require('firebase-admin');

const tenantId = process.env.SEED_TENANT_ID || 'demo-tenant';
const projectId = process.env.FIREBASE_PROJECT_ID || 'schedula-543b1';
const testUserEmail = process.env.TEST_USER_EMAIL;
const testUserPassword = process.env.TEST_USER_PASSWORD;
const sourceBaseDate = '2026-03-11';
const seedBaseDate = process.env.SEED_BASE_DATE || formatYmd(new Date());

admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  projectId,
});

const db = admin.firestore();
const { Timestamp, FieldValue } = admin.firestore;

const staff = [
  {
    id: 'staff-1',
    sourceId: 1,
    name: 'Dr. Phạm Xuân Hoàng',
    specialty: 'Chuyên gia da mặt',
    status: 'available',
    avatar:
      'https://images.unsplash.com/photo-1706565029539-d09af5896340?w=100&h=100&fit=crop&crop=face',
    color: '#22c55e',
    appointments: 4,
    rating: 4.9,
  },
  {
    id: 'staff-2',
    sourceId: 2,
    name: 'Hoàng Long',
    specialty: 'Massage',
    status: 'in_session',
    avatar:
      'https://images.unsplash.com/photo-1676552055618-22ec8cde399a?w=100&h=100&fit=crop&crop=face',
    color: '#f97316',
    appointments: 6,
    rating: 4.7,
  },
  {
    id: 'staff-3',
    sourceId: 3,
    name: 'Dr. Bảo Trâm',
    specialty: 'Chuyên gia da liễu',
    status: 'absent',
    avatar:
      'https://images.unsplash.com/photo-1712482937676-398342a92e81?w=100&h=100&fit=crop&crop=face',
    color: '#eab308',
    appointments: 3,
    rating: 4.8,
  },
  {
    id: 'staff-4',
    sourceId: 4,
    name: 'Nguyễn Thị Mai',
    specialty: 'Chăm sóc tóc',
    status: 'available',
    avatar:
      'https://images.unsplash.com/photo-1731514771613-991a02407132?w=100&h=100&fit=crop&crop=face',
    color: '#22c55e',
    appointments: 5,
    rating: 4.6,
  },
];

const customers = [
  {
    id: 'customer-1',
    sourceId: 1,
    name: 'Trần Bình Minh',
    phone: '0901234567',
    email: 'minh@email.com',
    lastVisit: '2026-03-11',
    totalVisits: 12,
    status: 'active',
    service: 'Làm trắng da, tẩy da chết, nạn mụn',
    avatar: 'TB',
    color: '#14b8a6',
    spent: 2400000,
  },
  {
    id: 'customer-2',
    sourceId: 2,
    name: 'Lê Thị Hoa',
    phone: '0912345678',
    email: 'hoa@email.com',
    lastVisit: '2026-03-10',
    totalVisits: 8,
    status: 'active',
    service: 'Massage thư giãn',
    avatar: 'LH',
    color: '#8b5cf6',
    spent: 1800000,
  },
  {
    id: 'customer-3',
    sourceId: 3,
    name: 'Nguyễn Văn An',
    phone: '0923456789',
    email: 'an@email.com',
    lastVisit: '2026-03-08',
    totalVisits: 5,
    status: 'follow_up',
    service: 'Điều trị da liễu',
    avatar: 'NA',
    color: '#f97316',
    spent: 950000,
  },
  {
    id: 'customer-4',
    sourceId: 4,
    name: 'Phạm Thu Hương',
    phone: '0934567890',
    email: 'huong@email.com',
    lastVisit: '2026-03-05',
    totalVisits: 3,
    status: 'new',
    service: 'Chăm sóc cơ bản',
    avatar: 'PH',
    color: '#ec4899',
    spent: 600000,
  },
  {
    id: 'customer-5',
    sourceId: 5,
    name: 'Vũ Minh Tuấn',
    phone: '0945678901',
    email: 'tuan@email.com',
    lastVisit: '2026-02-28',
    totalVisits: 1,
    status: 'new',
    service: 'Tư vấn da',
    avatar: 'VT',
    color: '#3b82f6',
    spent: 200000,
  },
  {
    id: 'customer-6',
    sourceId: 6,
    name: 'Trần Thị Lan',
    phone: '0956789012',
    email: 'lan@email.com',
    lastVisit: '2026-03-12',
    totalVisits: 4,
    status: 'active',
    service: 'Trị nám, tàn nhang',
    avatar: 'TL',
    color: '#14b8a6',
    spent: 1500000,
  },
];

const services = [
  {
    id: 'service-1',
    sourceId: 1,
    name: 'Làm trắng da',
    durationMin: 60,
    price: 500000,
    equipment: ['Máy Laser CO2'],
    category: 'Da mặt',
  },
  {
    id: 'service-2',
    sourceId: 2,
    name: 'Tẩy da chết',
    durationMin: 45,
    price: 300000,
    equipment: [],
    category: 'Da mặt',
  },
  {
    id: 'service-3',
    sourceId: 3,
    name: 'Điều trị mụn nâng cao',
    durationMin: 60,
    price: 800000,
    equipment: ['Máy Laser CO2'],
    category: 'Da liễu',
  },
  {
    id: 'service-4',
    sourceId: 4,
    name: 'Massage toàn thân thư giãn',
    durationMin: 90,
    price: 600000,
    equipment: ['Máy Massage Trị liệu'],
    category: 'Massage',
  },
  {
    id: 'service-5',
    sourceId: 5,
    name: 'Uốn và nhuộm tóc',
    durationMin: 120,
    price: 1200000,
    equipment: [],
    category: 'Tóc',
  },
  {
    id: 'service-6',
    sourceId: 6,
    name: 'RF Nâng cơ',
    durationMin: 75,
    price: 1500000,
    equipment: ['Máy RF Nâng Cơ'],
    category: 'Công nghệ cao',
  },
  {
    id: 'service-7',
    sourceId: 7,
    name: 'Hút chân không giảm mỡ',
    durationMin: 60,
    price: 1000000,
    equipment: ['Máy Hút Chân Không'],
    category: 'Giảm béo',
  },
];

const appointments = [
  {
    id: 'booking-1',
    sourceId: 1,
    customerName: 'Trần Bình Minh',
    staffName: 'Dr. Phạm Xuân Hoàng',
    serviceName: 'Làm trắng da, tẩy da chết, nạn mụn',
    date: '2026-03-11',
    time: '09:30',
    duration: 90,
    status: 'checked_in',
    color: '#14b8a6',
  },
  {
    id: 'booking-2',
    sourceId: 2,
    customerName: 'Lê Thị Hoa',
    staffName: 'Hoàng Long',
    serviceName: 'Massage toàn thân thư giãn',
    date: '2026-03-11',
    time: '10:00',
    duration: 60,
    status: 'checked_in',
    color: '#f97316',
  },
  {
    id: 'booking-3',
    sourceId: 3,
    customerName: 'Nguyễn Văn An',
    staffName: 'Dr. Bảo Trâm',
    serviceName: 'Điều trị mụn nâng cao',
    date: '2026-03-11',
    time: '11:30',
    duration: 60,
    status: 'waiting',
    color: '#8b5cf6',
  },
  {
    id: 'booking-4',
    sourceId: 4,
    customerName: 'Phạm Thu Hương',
    staffName: 'Nguyễn Thị Mai',
    serviceName: 'Uốn và nhuộm tóc',
    date: '2026-03-11',
    time: '14:00',
    duration: 120,
    status: 'waiting',
    color: '#ec4899',
  },
  {
    id: 'booking-5',
    sourceId: 5,
    customerName: 'Vũ Minh Tuấn',
    staffName: 'Dr. Phạm Xuân Hoàng',
    serviceName: 'Tư vấn chăm sóc da',
    date: '2026-03-12',
    time: '09:00',
    duration: 45,
    status: 'confirmed',
    color: '#3b82f6',
  },
  {
    id: 'booking-6',
    sourceId: 6,
    customerName: 'Trần Thị Lan',
    staffName: 'Dr. Bảo Trâm',
    serviceName: 'Trị nám, tàn nhang',
    date: '2026-03-12',
    time: '10:30',
    duration: 75,
    status: 'confirmed',
    color: '#14b8a6',
  },
];

const equipment = [
  {
    id: 'equipment-1',
    name: 'Máy Laser CO2',
    status: 'available',
    location: 'Phòng 1',
    lastMaintenance: '2026-03-01',
  },
  {
    id: 'equipment-2',
    name: 'Máy Massage Trị liệu',
    status: 'in_use',
    location: 'Phòng 2',
    lastMaintenance: '2026-02-28',
  },
  {
    id: 'equipment-3',
    name: 'Máy Hút Chân Không',
    status: 'maintenance',
    location: 'Phòng 3',
    lastMaintenance: '2026-02-15',
  },
  {
    id: 'equipment-4',
    name: 'Máy RF Nâng Cơ',
    status: 'available',
    location: 'Phòng 4',
    lastMaintenance: '2026-03-05',
  },
];

const chartData = [
  { id: 'mon', day: 'Mon', recovery: 60, monitoring: 40, appointments: 55 },
  { id: 'tue', day: 'Tue', recovery: 85, monitoring: 60, appointments: 70 },
  { id: 'wed', day: 'Wed', recovery: 75, monitoring: 80, appointments: 90 },
  { id: 'thu', day: 'Thu', recovery: 50, monitoring: 55, appointments: 45 },
  { id: 'fri', day: 'Fri', recovery: 90, monitoring: 70, appointments: 80 },
  { id: 'sat', day: 'Sat', recovery: 70, monitoring: 65, appointments: 95 },
];

const weeklyRevenue = [
  { id: 'week-1', week: 'T1', revenue: 12500000 },
  { id: 'week-2', week: 'T2', revenue: 18700000 },
  { id: 'week-3', week: 'T3', revenue: 15200000 },
  { id: 'week-4', week: 'T4', revenue: 22400000 },
  { id: 'week-5', week: 'T5', revenue: 19800000 },
  { id: 'week-6', week: 'T6', revenue: 28100000 },
  { id: 'week-7', week: 'T7', revenue: 24600000 },
];

const aiInsights = [
  {
    id: 'insight-1',
    type: 'growth',
    title: 'Tỷ lệ khách hàng mới tăng 15%',
    description: 'Tháng này có xu hướng tăng trưởng tốt về khách hàng mới.',
    icon: 'trending_up',
  },
  {
    id: 'insight-2',
    type: 'opportunity',
    title: 'Khung giờ 13:00 thứ 3 thường trống',
    description: 'AI đề xuất chạy chương trình khuyến mãi cho khung giờ này.',
    icon: 'lightbulb',
  },
  {
    id: 'insight-3',
    type: 'alert',
    title: 'Tỷ lệ hủy lịch tăng nhẹ',
    description: 'Cân nhắc gửi nhắc nhở trước 24h.',
    icon: 'alert',
  },
];

const subscriptionPlans = [
  {
    id: 'basic',
    name: 'Cơ Bản',
    price: 299000,
    period: 'tháng',
    color: '#6b7280',
    gradient: 'from-gray-50 to-gray-100',
    borderColor: 'border-gray-200',
    features: [
      'Tối đa 50 lịch hẹn/tháng',
      '3 nhân viên',
      'Theo dõi 100 khách hàng',
      'Báo cáo cơ bản',
      'Hỗ trợ email',
    ],
    notIncluded: ['Thống kê nâng cao', 'Tích hợp thanh toán', 'API tùy chỉnh'],
    popular: false,
  },
  {
    id: 'pro',
    name: 'Chuyên Nghiệp',
    price: 699000,
    period: 'tháng',
    color: '#14b8a6',
    gradient: 'from-teal-50 to-cyan-50',
    borderColor: 'border-teal-400',
    features: [
      'Không giới hạn lịch hẹn',
      '10 nhân viên',
      'Theo dõi 500 khách hàng',
      'Thống kê nâng cao',
      'Tích hợp thanh toán',
      'Hỗ trợ ưu tiên 24/7',
    ],
    notIncluded: ['API tùy chỉnh'],
    popular: true,
  },
  {
    id: 'enterprise',
    name: 'Doanh Nghiệp',
    price: 1499000,
    period: 'tháng',
    color: '#7c3aed',
    gradient: 'from-violet-50 to-purple-50',
    borderColor: 'border-violet-400',
    features: [
      'Không giới hạn lịch hẹn',
      'Nhân viên không giới hạn',
      'Khách hàng không giới hạn',
      'Thống kê & Báo cáo đầy đủ',
      'Tích hợp thanh toán',
      'API tùy chỉnh',
      'Hỗ trợ riêng 24/7',
    ],
    notIncluded: [],
    popular: false,
  },
];

function parseYmd(value) {
  const [year, month, day] = value.split('-').map(Number);
  return Date.UTC(year, month - 1, day);
}

function formatYmd(date) {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

function shiftedDate(value) {
  const dayMs = 24 * 60 * 60 * 1000;
  const offsetDays = Math.round((parseYmd(value) - parseYmd(sourceBaseDate)) / dayMs);
  const shifted = new Date(parseYmd(seedBaseDate) + offsetDays * dayMs);
  const year = shifted.getUTCFullYear();
  const month = String(shifted.getUTCMonth() + 1).padStart(2, '0');
  const day = String(shifted.getUTCDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

function timestampFromDate(value) {
  return Timestamp.fromDate(new Date(`${shiftedDate(value)}T00:00:00+07:00`));
}

function timestampFromDateTime(date, time) {
  return Timestamp.fromDate(new Date(`${shiftedDate(date)}T${time}:00+07:00`));
}

function addMinutes(timestamp, minutes) {
  return Timestamp.fromMillis(timestamp.toMillis() + minutes * 60 * 1000);
}

function bookingStatus(sourceStatus) {
  switch (sourceStatus) {
    case 'checked_in':
      return 'in_progress';
    case 'waiting':
      return 'confirmed';
    default:
      return sourceStatus;
  }
}

function findByName(items, name) {
  return items.find((item) => item.name === name);
}

function serviceForAppointment(appointment) {
  const exact = services.find((service) => service.name === appointment.serviceName);
  if (exact) return exact;

  const partial = services.find((service) =>
    appointment.serviceName.toLowerCase().includes(service.name.toLowerCase()),
  );
  if (partial) return partial;

  return {
    id: `service-custom-${appointment.sourceId}`,
    name: appointment.serviceName,
    durationMin: appointment.duration,
    price: 0,
    equipment: [],
    category: 'Khác',
  };
}

function interval(startTime, duration, bookingId) {
  return {
    startTime,
    endTime: addMinutes(startTime, duration),
    ...(bookingId ? { bookingId } : {}),
  };
}

async function upsert(collection, id, data) {
  await db.collection(collection).doc(id).set(
    {
      ...data,
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
}

async function ensureTestUserClaims() {
  if (!testUserEmail) {
    console.log('Skipped auth claims. Set TEST_USER_EMAIL to grant booking access.');
    return;
  }

  let user;
  try {
    user = await admin.auth().getUserByEmail(testUserEmail);
  } catch (error) {
    if (error.code !== 'auth/user-not-found' || !testUserPassword) {
      throw error;
    }

    user = await admin.auth().createUser({
      email: testUserEmail,
      password: testUserPassword,
      displayName: 'Demo Owner',
    });
  }

  await admin.auth().setCustomUserClaims(user.uid, {
    role: 'owner',
    tenantId,
  });

  await upsert('users', user.uid, {
    tenantId,
    role: 'owner',
    name: user.displayName || 'Demo Owner',
    email: user.email,
    workingHours: {
      monday: ['09:00-18:00'],
      tuesday: ['09:00-18:00'],
      wednesday: ['09:00-18:00'],
      thursday: ['09:00-18:00'],
      friday: ['09:00-18:00'],
      saturday: ['09:00-17:00'],
    },
  });

  console.log(`Set owner claims for ${testUserEmail}: tenantId=${tenantId}`);
}

async function seedFirestore() {
  await upsert('tenants', tenantId, {
    name: 'Schedula Beauty Clinic',
    plan: 'pro',
    timezone: 'Asia/Ho_Chi_Minh',
    createdAt: FieldValue.serverTimestamp(),
  });

  for (const member of staff) {
    await upsert('users', member.id, {
      tenantId,
      role: 'staff',
      name: member.name,
      email: `${member.id}@schedula.test`,
      specialty: member.specialty,
      status: member.status,
      avatar: member.avatar,
      color: member.color,
      appointments: member.appointments,
      rating: member.rating,
      workingHours: {
        monday: ['09:00-18:00'],
        tuesday: ['09:00-18:00'],
        wednesday: ['09:00-18:00'],
        thursday: ['09:00-18:00'],
        friday: ['09:00-18:00'],
        saturday: ['09:00-17:00'],
      },
    });
  }

  for (const customer of customers) {
    await upsert('customers', customer.id, {
      tenantId,
      name: customer.name,
      phone: customer.phone,
      email: customer.email,
      visitCount: customer.totalVisits,
      lastVisit: timestampFromDate(customer.lastVisit),
      notes: customer.service,
      status: customer.status,
      avatar: customer.avatar,
      color: customer.color,
      spent: customer.spent,
    });
  }

  for (const service of services) {
    await upsert('services', service.id, {
      tenantId,
      name: service.name,
      durationMin: service.durationMin,
      price: service.price,
      isActive: true,
      equipment: service.equipment,
      category: service.category,
    });
  }

  for (const item of equipment) {
    await upsert('equipment', item.id, {
      tenantId,
      name: item.name,
      status: item.status,
      location: item.location,
      lastMaintenance: timestampFromDate(item.lastMaintenance),
    });
  }

  const seededServiceIds = new Set(services.map((service) => service.id));

  for (const appointment of appointments) {
    const customer = findByName(customers, appointment.customerName);
    const member = findByName(staff, appointment.staffName);
    const service = serviceForAppointment(appointment);
    const startTime = timestampFromDateTime(appointment.date, appointment.time);

    if (!customer || !member) {
      throw new Error(`Missing customer or staff for appointment ${appointment.id}`);
    }

    if (!seededServiceIds.has(service.id)) {
      await upsert('services', service.id, {
        tenantId,
        name: service.name,
        durationMin: service.durationMin,
        price: service.price,
        isActive: true,
        equipment: service.equipment,
        category: service.category,
      });
      seededServiceIds.add(service.id);
    }

    await upsert('bookings', appointment.id, {
      tenantId,
      staffId: member.id,
      customerId: customer.id,
      serviceId: service.id,
      startTime,
      endTime: addMinutes(startTime, appointment.duration),
      status: bookingStatus(appointment.status),
      notes: `Seeded from provided mockData.ts. Original status: ${appointment.status}.`,
      createdBy: testUserEmail || 'seed-script',
      createdAt: FieldValue.serverTimestamp(),
      reminder24Sent: false,
      reminder1hSent: false,
      customerName: customer.name,
      staffName: member.name,
      serviceName: appointment.serviceName,
      color: appointment.color,
      sourceId: appointment.sourceId,
    });
  }

  const appointmentsByStaffDate = new Map();
  for (const appointment of appointments) {
    const member = findByName(staff, appointment.staffName);
    const key = `${shiftedDate(appointment.date)}_${member.id}`;
    const startTime = timestampFromDateTime(appointment.date, appointment.time);
    const items = appointmentsByStaffDate.get(key) || {
      staffId: member.id,
      date: shiftedDate(appointment.date),
      intervals: [],
    };

    items.intervals.push(interval(startTime, appointment.duration, appointment.id));
    appointmentsByStaffDate.set(key, items);
  }

  for (const [id, slot] of appointmentsByStaffDate.entries()) {
    await upsert('slots', id, {
      tenantId,
      staffId: slot.staffId,
      date: timestampFromDate(slot.date),
      intervals: slot.intervals,
    });
  }

  for (const item of chartData) {
    await upsert('dashboardChartData', item.id, { tenantId, ...item });
  }

  for (const item of weeklyRevenue) {
    await upsert('weeklyRevenue', item.id, { tenantId, ...item });
  }

  for (const insight of aiInsights) {
    await upsert('aiInsights', insight.id, { tenantId, ...insight });
  }

  for (const plan of subscriptionPlans) {
    await upsert('subscriptionPlans', plan.id, plan);
  }

  console.log(
    `Seeded ${staff.length} staff, ${customers.length} customers, ` +
      `${services.length} services, and ${appointments.length} bookings for tenantId=${tenantId}`,
  );
}

async function main() {
  await seedFirestore();
  await ensureTestUserClaims();
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
