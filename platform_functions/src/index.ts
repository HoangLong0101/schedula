import { randomBytes } from 'node:crypto';

import * as admin from 'firebase-admin';
import { AggregateField, FieldValue, Timestamp } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { defineSecret } from 'firebase-functions/params';

import {
  isPlatformRole,
  requirePlatformAdmin,
  type PlatformContext,
  type PlatformPermission,
} from './access';

export {
  auditCustomerCrud,
  auditServiceCrud,
  auditProductCrud,
  auditEquipmentCrud,
} from './directCrud';
export { activeSimulationMigration } from './activeSimulationMigration';

if (admin.apps.length === 0) admin.initializeApp();

const db = admin.firestore();
const payosClientId = defineSecret('PAYOS_CLIENT_ID');
const payosApiKey = defineSecret('PAYOS_API_KEY');
const tenantLimit = 250;
const paymentLimit = 1000;
const bookingActivityLimit = 10000;
const simulationTrialTenantNames = new Set([
  'Kim Dung Beauty',
  'Pure Spa',
  'Katie Spa',
  'Dưỡng sinh Cô Ba',
  'Mị Spa',
]);

type WorkspaceInput = {
  startAt?: string;
  endAt?: string;
  province?: string;
  businessType?: string;
  plan?: string;
  subscriptionStatus?: string;
  transactionStatus?: string;
  query?: string;
};

type PaymentRecord = FirebaseFirestore.DocumentData & { id: string };
type BookingActivity = { tenantId: string; startTime: number | null };

export function isPlatformAdmin(
  token: Record<string, unknown> | undefined,
): boolean {
  return token?.platformAdmin === true;
}

export const getPlatformWorkspace = onCall(
  { secrets: [payosClientId, payosApiKey] },
  async (request) => {
  const actor = await requirePlatformAdmin(
    db,
    request.auth,
    'dashboard.read',
  );
  const input = (request.data ?? {}) as WorkspaceInput;
  const range = parseRange(input.startAt, input.endAt);
  const previousStart = new Date(
    range.start.getTime() - (range.end.getTime() - range.start.getTime()),
  );
  const [
    tenantSnapshot,
    paymentSnapshot,
    planSnapshot,
    bookingActivitySnapshot,
  ] = await Promise.all([
    db.collection('tenants')
      .orderBy('createdAt', 'desc')
      .limit(tenantLimit + 1)
      .get(),
    db.collection('payments')
      .where('createdAt', '>=', Timestamp.fromDate(previousStart))
      .where('createdAt', '<=', Timestamp.fromDate(range.end))
      .orderBy('createdAt', 'desc')
      .limit(paymentLimit + 1)
      .get(),
    db.collection('subscriptionPlans').limit(100).get(),
    db.collection('bookings')
      .where('startTime', '>=', Timestamp.fromDate(range.start))
      .where('startTime', '<=', Timestamp.fromDate(range.end))
      .orderBy('startTime', 'desc')
      .limit(bookingActivityLimit)
      .select('tenantId', 'startTime')
      .get(),
  ]);

  const tenantDocs = tenantSnapshot.docs.slice(0, tenantLimit);
  const ownerRefs = tenantDocs
    .map((document) => document.data().ownerUid)
    .filter((uid): uid is string => typeof uid === 'string' && uid.length > 0)
    .map((uid) => db.collection('users').doc(uid));
  const ownerDocs = ownerRefs.length ? await db.getAll(...ownerRefs) : [];
  const owners = new Map(ownerDocs.map((document) => [document.id, document.data()]));

  const bookingActivity: BookingActivity[] = bookingActivitySnapshot.docs.map((document) => ({
    tenantId: String(document.data().tenantId ?? ''),
    startTime: toMillis(document.data().startTime),
  }));
  const latestBookingByTenant = new Map<string, number>();
  for (const booking of bookingActivity) {
    const { tenantId, startTime: startedAt } = booking;
    if (tenantId && startedAt != null && !latestBookingByTenant.has(tenantId)) {
      latestBookingByTenant.set(tenantId, startedAt);
    }
  }
  const allBusinesses = tenantDocs.map((document) => {
    const data = document.data();
    const owner = owners.get(String(data.ownerUid ?? '')) ?? {};
    return serializeBusiness(
      document.id,
      data,
      owner,
      latestBookingByTenant.get(document.id),
    );
  });
  const businesses = filterBusinesses(allBusinesses, input);
  const businessById = new Map(allBusinesses.map((business) => [business.id, business]));

  const allPayments: PaymentRecord[] = paymentSnapshot.docs
    .slice(0, paymentLimit)
    .map<PaymentRecord>((document) => ({ id: document.id, ...document.data() }))
    .filter((payment) => payment.type === 'subscription');
  if (actor.permissions.includes('transaction.reconcile')) {
    await refreshPendingPayOSPayments(actor, allPayments);
  }
  const currentPayments = allPayments.filter((payment) =>
    inRange(payment.createdAt, range.start, range.end));
  const previousPayments = allPayments.filter((payment) =>
    inRange(payment.createdAt, previousStart, range.start));
  const payments = filterPayments(currentPayments, input, businessById);

  const plans = planSnapshot.docs.map((document) => ({
    id: document.id,
    ...serializeRecord(document.data()),
  }));
  const metrics = buildMetrics(
    businesses,
    payments,
    filterPayments(previousPayments, input, businessById),
    plans,
    range,
    bookingActivity,
  );

  const canMonitor = actor.permissions.includes('monitoring.read');
  const [auditSnapshot, adminSnapshot] = await Promise.all([
    canMonitor
      ? db.collection('auditEvents')
        .where('platform', '==', true)
        .orderBy('createdAt', 'desc')
        .limit(100)
        .get()
      : Promise.resolve(null),
    actor.permissions.includes('admin.write')
      ? db.collection('platformAdmins').limit(100).get()
      : Promise.resolve(null),
  ]);

  return {
    generatedAt: Date.now(),
    range: { startAt: range.start.getTime(), endAt: range.end.getTime() },
    actor,
    metrics,
    businesses,
    transactions: payments.map((payment) =>
      serializePayment(payment, businessById.get(String(payment.tenantId ?? '')))),
    plans,
    analytics: buildAnalytics(businesses, payments, bookingActivity, range),
    auditEvents: auditSnapshot?.docs.map((document) => ({
      id: document.id,
      ...serializeRecord(document.data()),
    })) ?? [],
    admins: adminSnapshot?.docs.map((document) => ({
      id: document.id,
      ...serializeRecord(document.data()),
      role: isPlatformRole(document.data().role)
        ? document.data().role
        : 'super_admin',
    })) ?? [],
  };
  },
);

// Kept for the already-deployed first admin client.
export const getPlatformDashboard = onCall(async (request) => {
  await requirePlatformAdmin(db, request.auth, 'dashboard.read');
  const now = new Date();
  const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);
  const expiryLimit = new Date(now);
  expiryLimit.setDate(expiryLimit.getDate() + 30);
  const tenants = db.collection('tenants');
  const [total, suspended, created, users, bookings, payments, expiring, recent] =
    await Promise.all([
      tenants.count().get(),
      tenants.where('status', '==', 'suspended').count().get(),
      tenants.where('createdAt', '>=', monthStart).count().get(),
      db.collection('users').count().get(),
      db.collection('bookings').where('startTime', '>=', monthStart).count().get(),
      db.collection('payments').count().get(),
      tenants.where('planExpiresAt', '>=', now)
        .where('planExpiresAt', '<=', expiryLimit).count().get(),
      tenants.orderBy('createdAt', 'desc').limit(8).get(),
    ]);
  return {
    generatedAt: Date.now(),
    metrics: {
      totalBusinesses: total.data().count,
      activeBusinesses: Math.max(0, total.data().count - suspended.data().count),
      suspendedBusinesses: suspended.data().count,
      newBusinessesThisMonth: created.data().count,
      totalUsers: users.data().count,
      bookingsThisMonth: bookings.data().count,
      totalPayments: payments.data().count,
      expiringSubscriptions: expiring.data().count,
    },
    recentBusinesses: recent.docs.map((document) => {
      const data = document.data();
      return {
        id: document.id,
        name: String(data.name ?? 'Chưa đặt tên'),
        ownerName: '',
        ownerEmail: '',
        planTier: String(data.planTier ?? 'basic'),
        status: normalizeBusinessStatus(data.status),
        createdAt: toMillis(data.createdAt),
        planExpiresAt: toMillis(data.planExpiresAt),
      };
    }),
  };
});

export const getPlatformBusinessDetail = onCall(async (request) => {
  await requirePlatformAdmin(db, request.auth, 'business.read');
  const tenantId = requiredString(request.data?.tenantId, 'tenantId');
  const activityDays = parseActivityDays(request.data?.activityDays);
  const activityStart = Timestamp.fromMillis(Date.now() - activityDays * 86400000);
  const tenantRef = db.collection('tenants').doc(tenantId);
  const tenant = await tenantRef.get();
  if (!tenant.exists) throw new HttpsError('not-found', 'Không tìm thấy doanh nghiệp.');
  const data = tenant.data() ?? {};
  const ownerUid = String(data.ownerUid ?? '');
  const [owner, bookings, customers, users, services, products, equipment, revenue, payments, audits] =
    await Promise.all([
      ownerUid ? db.collection('users').doc(ownerUid).get() : Promise.resolve(null),
      db.collection('bookings').where('tenantId', '==', tenantId).get(),
      db.collection('customers').where('tenantId', '==', tenantId).get(),
      db.collection('users').where('tenantId', '==', tenantId).get(),
      db.collection('services').where('tenantId', '==', tenantId).get(),
      db.collection('products').where('tenantId', '==', tenantId).get(),
      db.collection('equipment').where('tenantId', '==', tenantId).get(),
      db.collection('payments')
        .where('tenantId', '==', tenantId)
        .where('type', '==', 'subscription')
        .where('status', '==', 'paid')
        .aggregate({ total: AggregateField.sum('amount') })
        .get()
        .catch((error: unknown) => {
          // Keep the business profile available while a newly deployed
          // aggregate index is still building. Only the revenue row is
          // temporarily unavailable; all other errors must still surface.
          if ((error as { code?: number }).code !== 9) throw error;
          console.warn('Business revenue index is not ready.', { tenantId });
          return null;
        }),
      db.collection('payments').where('tenantId', '==', tenantId)
        .orderBy('createdAt', 'desc').limit(50).get(),
      db.collection('auditEvents').where('tenantId', '==', tenantId)
        .where('createdAt', '>=', activityStart)
        .orderBy('createdAt', 'desc').limit(1000).get(),
    ]);
  const paymentRows: PaymentRecord[] = payments.docs.map((document) => ({
    id: document.id,
    ...document.data(),
  }));
  const staff = users.docs.filter((document) =>
    ['staff', 'receptionist'].includes(String(document.data().role)) &&
    document.data().active !== false,
  );
  const records = {
    bookings: bookings.docs.map((document) => serializeTenantRecord('bookings', document)),
    customers: customers.docs.map((document) => serializeTenantRecord('customers', document)),
    staff: staff.map((document) => serializeTenantRecord('staff', document)),
    services: services.docs.map((document) => serializeTenantRecord('services', document)),
    products: products.docs.map((document) => serializeTenantRecord('products', document)),
    equipment: equipment.docs.map((document) => serializeTenantRecord('equipment', document)),
  };
  return {
    business: serializeBusiness(tenant.id, data, owner?.data() ?? {}),
    usage: {
      bookings: records.bookings.length,
      customers: records.customers.length,
      staff: records.staff.length,
      services: records.services.length,
      products: records.products.length,
      equipment: records.equipment.length,
    },
    records,
    lifetimeRevenue: revenue == null ? null : money(revenue.data().total),
    lifetimeRevenueAvailable: revenue != null,
    payments: paymentRows.map((payment) => serializePayment(payment)),
    activityDays,
    activity: audits.docs.map((document) => {
      const audit = document.data();
      return {
        id: document.id,
        type: String(audit.entityType ?? 'system'),
        action: String(audit.action ?? 'updated'),
        status: String(audit.status ?? 'succeeded'),
        createdAt: toMillis(audit.createdAt),
      };
    }),
  };
});

export const platformAdminAction = onCall(async (request) => {
  const action = requiredString(request.data?.action, 'action');
  const permission = permissionForAction(action);
  const actor = await requirePlatformAdmin(db, request.auth, permission);
  const resourceId = requiredString(request.data?.resourceId, 'resourceId');
  const payload = isRecord(request.data?.payload) ? request.data.payload : {};

  if (action.startsWith('business.') || action.startsWith('subscription.')) {
    return mutateTenant(actor, action, resourceId, payload);
  }
  if (action.startsWith('record.')) {
    return mutateTenantRecord(actor, action, resourceId, payload);
  }
  if (action.startsWith('plan.')) return mutatePlan(actor, action, resourceId, payload);
  if (action.startsWith('transaction.')) {
    return mutateTransaction(actor, action, resourceId, payload);
  }
  if (action === 'admin.create' || action === 'admin.update') {
    return mutateAdmin(actor, action, resourceId, payload);
  }
  throw new HttpsError('invalid-argument', 'Thao tác quản trị không hợp lệ.');
});

export const reconcilePayOSTransaction = onCall(
  { secrets: [payosClientId, payosApiKey] },
  async (request) => {
    const actor = await requirePlatformAdmin(
      db,
      request.auth,
      'transaction.reconcile',
    );
    const paymentId = requiredString(request.data?.paymentId, 'paymentId');
    const paymentRef = db.collection('payments').doc(paymentId);
    const payment = await paymentRef.get();
    if (!payment.exists) throw new HttpsError('not-found', 'Không tìm thấy giao dịch.');
    const before = payment.data() ?? {};
    const orderCode = Number(before.orderCode);
    if (!Number.isSafeInteger(orderCode)) {
      throw new HttpsError('failed-precondition', 'Giao dịch không có mã PayOS hợp lệ.');
    }

    const update = await reconcilePayOSPayment(
      actor,
      paymentId,
      before,
      'transaction.reconcile',
    );
    return {
      paymentId,
      status: update.status,
      reconciliationStatus: update.reconciliationStatus,
    };
  },
);

async function refreshPendingPayOSPayments(
  actor: PlatformContext,
  payments: PaymentRecord[],
) {
  const staleBefore = Date.now() - 5 * 60 * 1000;
  const candidates = payments.filter((payment) =>
    payment.status === 'pending' &&
    Number.isSafeInteger(Number(payment.orderCode)) &&
    (!toMillis(payment.providerCheckedAt) ||
      (toMillis(payment.providerCheckedAt) ?? 0) < staleBefore),
  ).slice(0, 10);

  await Promise.all(candidates.map(async (payment) => {
    try {
      const update = await reconcilePayOSPayment(
        actor,
        payment.id,
        payment,
        'transaction.auto_reconcile',
      );
      Object.assign(payment, update, { providerCheckedAt: Timestamp.now() });
    } catch (error) {
      console.warn(`Không thể tự đối soát PayOS ${payment.id}`, error);
    }
  }));
}

async function reconcilePayOSPayment(
  actor: PlatformContext,
  paymentId: string,
  before: FirebaseFirestore.DocumentData,
  action: 'transaction.reconcile' | 'transaction.auto_reconcile',
) {
  const orderCode = Number(before.orderCode);
  const response = await fetch(
    `https://api-merchant.payos.vn/v2/payment-requests/${orderCode}`,
    {
      headers: {
        'x-client-id': payosClientId.value(),
        'x-api-key': payosApiKey.value(),
      },
    },
  );
  const result = await response.json() as {
    code?: string;
    desc?: string;
    data?: Record<string, unknown>;
  };
  if (!response.ok || result.code !== '00' || !result.data) {
    throw new HttpsError('unavailable', result.desc ?? 'Không thể kết nối PayOS.');
  }

  const providerOrderCode = Number(result.data.orderCode);
  const providerAmount = money(result.data.amount);
  const expectedAmount = money(before.amount);
  const verified = providerOrderCode === orderCode && providerAmount === expectedAmount;
  const status = verified
    ? normalizePayOSStatus(result.data.status)
    : String(before.status ?? 'pending');
  const reconciliationStatus = verified ? 'verified' : 'mismatch';
  const update = {
    provider: 'payos',
    providerStatus: String(result.data.status ?? ''),
    status,
    amountPaid: money(result.data.amountPaid),
    amountRemaining: money(result.data.amountRemaining),
    reconciliationStatus,
    providerCheckedAt: FieldValue.serverTimestamp(),
    providerResponse: result.data,
    updatedAt: FieldValue.serverTimestamp(),
  };
  const canApplySubscription =
    verified &&
    status === 'paid' &&
    before.type === 'subscription' &&
    before.tenantId &&
    (await db.collection('tenants').doc(String(before.tenantId)).get()).exists;
  const paymentRef = db.collection('payments').doc(paymentId);
  await db.runTransaction(async (transaction) => {
    transaction.update(paymentRef, update);
    if (
      action === 'transaction.reconcile' ||
      status !== before.status ||
      reconciliationStatus !== before.reconciliationStatus
    ) {
      writePlatformAudit(
        transaction,
        actor,
        actionTarget('transaction', paymentId),
        action,
        before,
        { ...before, ...update },
      );
    }
    if (canApplySubscription) {
      applyPaidSubscription(transaction, before);
    }
  });
  return { ...update, status, reconciliationStatus };
}

async function mutateTenant(
  actor: PlatformContext,
  action: string,
  tenantId: string,
  payload: Record<string, unknown>,
) {
  const ref = db.collection('tenants').doc(tenantId);
  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    if (!snapshot.exists) throw new HttpsError('not-found', 'Không tìm thấy doanh nghiệp.');
    const before = snapshot.data() ?? {};
    const update: Record<string, unknown> = { updatedAt: FieldValue.serverTimestamp() };
    switch (action) {
      case 'business.update_info':
        Object.assign(update, {
          name: requiredString(payload.name, 'name'),
          ownerName: requiredString(payload.ownerName, 'ownerName'),
          phone: requiredString(payload.phone, 'phone'),
          address: requiredString(payload.address, 'address'),
          province: requiredString(payload.province, 'province'),
          type: requiredString(payload.businessType, 'businessType'),
          businessType: requiredString(payload.businessType, 'businessType'),
        });
        break;
      case 'business.suspend': update.status = 'suspended'; break;
      case 'business.reactivate': update.status = 'active'; break;
      case 'business.cancel': update.status = 'cancelled'; update.subscriptionStatus = 'cancelled'; break;
      case 'subscription.change_plan': {
        const planTier = requiredString(payload.planTier, 'planTier');
        const plan = await transaction.get(
          db.collection('subscriptionPlans').doc(planTier),
        );
        if (!plan.exists || !isSelectablePlan(plan.data())) {
          throw new HttpsError('failed-precondition', 'Gói SaaS không hoạt động.');
        }
        update.planTier = planTier;
        update.subscriptionStatus = retainedSubscriptionStatus(before);
        update.trialStatus = update.subscriptionStatus === 'trial' ? 'active' : 'expired';
        break;
      }
      case 'subscription.extend': {
        const days = integer(payload.days, 'days', 1, 366);
        const current = before.planExpiresAt instanceof Timestamp
          ? before.planExpiresAt.toDate()
          : new Date();
        const base = current.getTime() > Date.now() ? current : new Date();
        base.setDate(base.getDate() + days);
        update.planExpiresAt = Timestamp.fromDate(base);
        update.subscriptionStatus = retainedSubscriptionStatus(before);
        update.trialStatus = update.subscriptionStatus === 'trial' ? 'active' : 'expired';
        break;
      }
      case 'subscription.cancel': update.subscriptionStatus = 'cancelled'; break;
      case 'subscription.reactivate':
        update.subscriptionStatus = retainedSubscriptionStatus(before);
        update.trialStatus = update.subscriptionStatus === 'trial' ? 'active' : 'expired';
        break;
      default: throw new HttpsError('invalid-argument', 'Thao tác doanh nghiệp không hợp lệ.');
    }
    transaction.update(ref, update);
    if (action === 'business.update_info' && before.ownerUid) {
      transaction.set(db.collection('users').doc(String(before.ownerUid)), {
        name: update.ownerName,
        phone: update.phone,
        updatedAt: FieldValue.serverTimestamp(),
      }, { merge: true });
    }
    writePlatformAudit(transaction, actor, actionTarget('tenant', tenantId),
      action, before, { ...before, ...update });
  });
  return { resourceId: tenantId };
}

type TenantRecordKind =
  | 'bookings'
  | 'customers'
  | 'staff'
  | 'services'
  | 'products'
  | 'equipment';

const tenantRecordCollections: Record<TenantRecordKind, string> = {
  bookings: 'bookings',
  customers: 'customers',
  staff: 'users',
  services: 'services',
  products: 'products',
  equipment: 'equipment',
};

async function mutateTenantRecord(
  actor: PlatformContext,
  action: string,
  resourceId: string,
  payload: Record<string, unknown>,
) {
  if (!['record.save', 'record.delete'].includes(action)) {
    throw new HttpsError('invalid-argument', 'Thao tác dữ liệu không hợp lệ.');
  }
  const tenantId = requiredString(payload.tenantId, 'tenantId');
  const kind = requiredString(payload.kind, 'kind') as TenantRecordKind;
  if (!(kind in tenantRecordCollections)) {
    throw new HttpsError('invalid-argument', 'Loại dữ liệu không hợp lệ.');
  }
  const tenant = await db.collection('tenants').doc(tenantId).get();
  if (!tenant.exists) throw new HttpsError('not-found', 'Không tìm thấy doanh nghiệp.');
  if (kind === 'staff') {
    return mutateStaffRecord(actor, action, resourceId, tenantId, payload);
  }
  if (kind === 'bookings') {
    return mutateBookingRecord(actor, action, resourceId, tenantId, payload);
  }

  const collection = tenantRecordCollections[kind];
  const ref = resourceId === 'new'
    ? db.collection(collection).doc()
    : db.collection(collection).doc(resourceId);
  const snapshot = resourceId === 'new' ? null : await ref.get();
  if (snapshot && (!snapshot.exists || snapshot.data()?.tenantId !== tenantId)) {
    throw new HttpsError('not-found', 'Không tìm thấy bản ghi.');
  }
  if (action === 'record.delete') {
    if (!snapshot) throw new HttpsError('not-found', 'Không tìm thấy bản ghi.');
    if (kind === 'equipment') {
      const assigned = await db.collection('bookings')
        .where('resourceIds', 'array-contains', ref.id).get();
      if (assigned.docs.some((document) =>
        ['pending', 'confirmed', 'in_progress'].includes(String(document.data().status)),
      )) {
        throw new HttpsError('failed-precondition', 'Thiết bị đang được dùng trong lịch hẹn.');
      }
    }
    const batch = db.batch();
    batch.delete(ref);
    writePlatformAudit(batch, actor, actionTarget(kind, ref.id),
      `${kind}.deleted`, snapshot.data(), null);
    await batch.commit();
    return { resourceId: ref.id };
  }

  const update = tenantRecordData(kind, payload, tenantId, snapshot == null);
  const batch = db.batch();
  batch.set(ref, update, { merge: true });
  writePlatformAudit(batch, actor, actionTarget(kind, ref.id),
    snapshot == null ? `${kind}.created` : `${kind}.updated`,
    snapshot?.data() ?? null, update);
  await batch.commit();
  return { resourceId: ref.id };
}

function tenantRecordData(
  kind: Exclude<TenantRecordKind, 'bookings' | 'staff'>,
  payload: Record<string, unknown>,
  tenantId: string,
  creating: boolean,
): Record<string, unknown> {
  const common = {
    tenantId,
    updatedAt: FieldValue.serverTimestamp(),
    ...(creating ? { createdAt: FieldValue.serverTimestamp() } : {}),
  };
  switch (kind) {
    case 'customers': {
      const isVip = payload.isVip === true;
      return {
        ...common,
        name: requiredString(payload.name, 'name'),
        phone: requiredString(payload.phone, 'phone'),
        email: optionalString(payload.email) ?? '',
        birthday: optionalString(payload.birthday) ?? '',
        notes: optionalString(payload.notes) ?? '',
        allergies: optionalString(payload.allergies) ?? '',
        isVip,
        customerTier: isVip ? 'vip' : 'standard',
        visitCount: integer(payload.visitCount ?? 0, 'visitCount', 0, 100000),
        avatar: requiredString(payload.name, 'name').trim().substring(0, 1).toUpperCase(),
        color: '#22AFC2',
      };
    }
    case 'services':
      return {
        ...common,
        name: requiredString(payload.name, 'name'),
        price: integer(payload.price, 'price', 0, 1000000000),
        duration: integer(payload.duration, 'duration', 1, 1440),
        durationMin: integer(payload.duration, 'duration', 1, 1440),
        category: requiredString(payload.category, 'category'),
      };
    case 'products':
      return {
        ...common,
        name: requiredString(payload.name, 'name'),
        price: integer(payload.price, 'price', 0, 1000000000),
        unit: requiredString(payload.unit, 'unit'),
        category: requiredString(payload.category, 'category'),
      };
    case 'equipment': {
      const status = String(payload.status ?? 'available');
      if (!['available', 'in_use', 'maintenance'].includes(status)) {
        throw new HttpsError('invalid-argument', 'Trạng thái thiết bị không hợp lệ.');
      }
      return {
        ...common,
        name: requiredString(payload.name, 'name'),
        status,
        location: optionalString(payload.location) ?? '',
        quantity: integer(payload.quantity ?? 1, 'quantity', 1, 1000),
        lastMaintenance: optionalTimestamp(payload.lastMaintenance),
      };
    }
  }
}

async function mutateStaffRecord(
  actor: PlatformContext,
  action: string,
  resourceId: string,
  tenantId: string,
  payload: Record<string, unknown>,
) {
  const creating = resourceId === 'new';
  const ref = creating ? db.collection('users').doc() : db.collection('users').doc(resourceId);
  const snapshot = creating ? null : await ref.get();
  if (snapshot && (
    !snapshot.exists ||
    snapshot.data()?.tenantId !== tenantId ||
    !['staff', 'receptionist'].includes(String(snapshot.data()?.role))
  )) {
    throw new HttpsError('not-found', 'Không tìm thấy nhân viên.');
  }
  if (action === 'record.delete') {
    if (!snapshot) throw new HttpsError('not-found', 'Không tìm thấy nhân viên.');
    const future = await db.collection('bookings')
      .where('tenantId', '==', tenantId)
      .where('staffId', '==', ref.id)
      .where('startTime', '>=', Timestamp.now()).limit(1).get();
    if (!future.empty) {
      throw new HttpsError('failed-precondition', 'Hãy xử lý lịch hẹn tương lai trước khi xóa nhân viên.');
    }
    await admin.auth().updateUser(ref.id, { disabled: true });
    const batch = db.batch();
    batch.update(ref, { active: false, updatedAt: FieldValue.serverTimestamp() });
    writePlatformAudit(batch, actor, actionTarget('staff', ref.id),
      'staff.deleted', snapshot.data(), { active: false });
    await batch.commit();
    return { resourceId: ref.id };
  }

  const name = requiredString(payload.name, 'name');
  const email = requiredString(payload.email, 'email').toLowerCase();
  if (!email.includes('@')) throw new HttpsError('invalid-argument', 'Email không hợp lệ.');
  const status = String(payload.status ?? 'available');
  if (!['available', 'in_session', 'absent'].includes(status)) {
    throw new HttpsError('invalid-argument', 'Trạng thái nhân viên không hợp lệ.');
  }
  const update = {
    tenantId,
    role: 'staff',
    permissions: ['booking.status.own', 'customer.read'],
    name,
    email,
    phone: requiredString(payload.phone, 'phone'),
    role_title: requiredString(payload.roleTitle, 'roleTitle'),
    status,
    active: true,
    color: String(snapshot?.data()?.color ?? '#148a9c'),
    specialties: stringList(payload.specialties),
    updatedAt: FieldValue.serverTimestamp(),
    ...(creating ? {
      appointments: 0,
      rating: 5,
      createdAt: FieldValue.serverTimestamp(),
      mustChangePassword: true,
    } : {}),
  };
  let temporaryPassword: string | undefined;
  let uid = ref.id;
  if (creating) {
    temporaryPassword = `Sc!${randomBytes(9).toString('base64url')}`;
    const user = await admin.auth().createUser({ email, password: temporaryPassword, displayName: name });
    uid = user.uid;
    await admin.auth().setCustomUserClaims(uid, {
      role: 'staff', tenantId, permissions: update.permissions, mustChangePassword: true,
    });
  } else {
    await admin.auth().updateUser(uid, { email, displayName: name, disabled: false });
  }
  const targetRef = db.collection('users').doc(uid);
  try {
    const batch = db.batch();
    batch.set(targetRef, update, { merge: true });
    writePlatformAudit(batch, actor, actionTarget('staff', uid),
      creating ? 'staff.created' : 'staff.updated', snapshot?.data() ?? null, update);
    await batch.commit();
  } catch (error) {
    if (creating) await admin.auth().deleteUser(uid).catch(() => undefined);
    throw error;
  }
  return { resourceId: uid, temporaryPassword };
}

async function mutateBookingRecord(
  actor: PlatformContext,
  action: string,
  resourceId: string,
  tenantId: string,
  payload: Record<string, unknown>,
) {
  const creating = resourceId === 'new';
  const ref = creating ? db.collection('bookings').doc() : db.collection('bookings').doc(resourceId);
  await db.runTransaction(async (transaction) => {
    const snapshot = creating ? null : await transaction.get(ref);
    if (snapshot && (!snapshot.exists || snapshot.data()?.tenantId !== tenantId)) {
      throw new HttpsError('not-found', 'Không tìm thấy lịch hẹn.');
    }
    const before = snapshot?.data() ?? {};
    const oldResources = stringList(before.resourceIds);
    if (action === 'record.delete') {
      if (!snapshot) throw new HttpsError('not-found', 'Không tìm thấy lịch hẹn.');
      const release = await releasableAdminEquipment(transaction, tenantId, ref.id, oldResources);
      transaction.delete(ref);
      for (const equipmentRef of release) transaction.update(equipmentRef, {
        status: 'available', updatedAt: FieldValue.serverTimestamp(),
      });
      writePlatformAudit(transaction, actor, actionTarget('bookings', ref.id),
        'bookings.deleted', before, null);
      return;
    }

    const staffId = requiredString(payload.staffId, 'staffId');
    const customerId = requiredString(payload.customerId, 'customerId');
    const serviceId = requiredString(payload.serviceId, 'serviceId');
    const startTime = requiredTimestamp(payload.startTime, 'startTime');
    const endTime = requiredTimestamp(payload.endTime, 'endTime');
    if (endTime.toMillis() <= startTime.toMillis()) {
      throw new HttpsError('invalid-argument', 'Giờ kết thúc phải sau giờ bắt đầu.');
    }
    const status = String(payload.status ?? 'pending');
    if (!['pending', 'confirmed', 'in_progress', 'completed', 'cancelled', 'no_show'].includes(status)) {
      throw new HttpsError('invalid-argument', 'Trạng thái lịch hẹn không hợp lệ.');
    }
    const [staff, customer, service] = await Promise.all([
      transaction.get(db.collection('users').doc(staffId)),
      transaction.get(db.collection('customers').doc(customerId)),
      transaction.get(db.collection('services').doc(serviceId)),
    ]);
    for (const document of [staff, customer, service]) {
      if (!document.exists || document.data()?.tenantId !== tenantId) {
        throw new HttpsError('failed-precondition', 'Nhân viên, khách hàng hoặc dịch vụ không hợp lệ.');
      }
    }
    const resourceIds = stringList(payload.resourceIds);
    const resourceSnapshot: Array<Record<string, unknown>> = [];
    for (const id of resourceIds) {
      const equipment = await transaction.get(db.collection('equipment').doc(id));
      if (!equipment.exists || equipment.data()?.tenantId !== tenantId || equipment.data()?.status === 'maintenance') {
        throw new HttpsError('failed-precondition', 'Thiết bị không khả dụng.');
      }
      resourceSnapshot.push({ id, name: String(equipment.data()?.name ?? id), quantity: equipment.data()?.quantity ?? 1 });
    }
    const overlaps = await transaction.get(
      db.collection('bookings').where('tenantId', '==', tenantId).where('startTime', '<', endTime),
    );
    const active = new Set(['pending', 'confirmed', 'in_progress']);
    const conflicting = overlaps.docs.filter((document) => {
      if (document.id === ref.id) return false;
      const row = document.data();
      return active.has(String(row.status)) &&
        row.endTime instanceof Timestamp && row.endTime.toMillis() > startTime.toMillis();
    });
    if (conflicting.some((document) => document.data().staffId === staffId)) {
      throw new HttpsError('already-exists', 'Khung giờ của nhân viên đã có lịch.');
    }
    for (const id of resourceIds) {
      const equipment = resourceSnapshot.find((item) => item.id === id)!;
      const used = conflicting.filter((document) => stringList(document.data().resourceIds).includes(id)).length;
      if (used >= Number(equipment.quantity ?? 1)) {
        throw new HttpsError('already-exists', 'Thiết bị đã được đặt trong khung giờ này.');
      }
    }
    const release = await releasableAdminEquipment(
      transaction, tenantId, ref.id, oldResources.filter((id) => !resourceIds.includes(id)),
    );
    const update = {
      tenantId, staffId, customerId, serviceId, startTime, endTime, status,
      notes: optionalString(payload.notes) ?? '',
      staffName: String(staff.data()?.name ?? ''),
      customerName: String(customer.data()?.name ?? ''),
      serviceName: String(service.data()?.name ?? ''),
      resourceIds, resourceSnapshot,
      updatedAt: FieldValue.serverTimestamp(),
      ...(creating ? {
        createdBy: actor.uid, createdAt: FieldValue.serverTimestamp(),
        reminder24Sent: false, reminder1hSent: false,
      } : {}),
    };
    transaction.set(ref, update, { merge: true });
    for (const id of resourceIds) transaction.update(db.collection('equipment').doc(id), {
      status: 'in_use', updatedAt: FieldValue.serverTimestamp(),
    });
    for (const equipmentRef of release) transaction.update(equipmentRef, {
      status: 'available', updatedAt: FieldValue.serverTimestamp(),
    });
    writePlatformAudit(transaction, actor, actionTarget('bookings', ref.id),
      creating ? 'bookings.created' : 'bookings.updated', before, update);
  });
  return { resourceId: ref.id };
}

async function releasableAdminEquipment(
  transaction: FirebaseFirestore.Transaction,
  tenantId: string,
  bookingId: string,
  resourceIds: string[],
) {
  const result: FirebaseFirestore.DocumentReference[] = [];
  for (const id of resourceIds) {
    const ref = db.collection('equipment').doc(id);
    const assigned = await transaction.get(
      db.collection('bookings').where('resourceIds', 'array-contains', id),
    );
    const stillUsed = assigned.docs.some((document) => {
      const row = document.data();
      return document.id !== bookingId && row.tenantId === tenantId &&
        ['pending', 'confirmed', 'in_progress'].includes(String(row.status));
    });
    if (!stillUsed) result.push(ref);
  }
  return result;
}

async function mutatePlan(
  actor: PlatformContext,
  action: string,
  planId: string,
  payload: Record<string, unknown>,
) {
  if (!/^[a-z0-9_-]{2,40}$/.test(planId)) {
    throw new HttpsError('invalid-argument', 'Mã gói không hợp lệ.');
  }
  const ref = db.collection('subscriptionPlans').doc(planId);
  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    const before = snapshot.data() ?? null;
    let update: Record<string, unknown>;
    if (action === 'plan.save') {
      update = {
        name: requiredString(payload.name, 'name'),
        price: integer(payload.monthlyPrice, 'monthlyPrice', 0, 1000000000),
        yearlyPrice: integer(payload.annualPrice, 'annualPrice', 0, 10000000000),
        trialDays: integer(payload.trialDays, 'trialDays', 0, 365),
        description: optionalString(payload.description),
        features: stringList(payload.features),
        limits: isRecord(payload.limits) ? payload.limits : {},
        status: ['active', 'inactive', 'archived'].includes(String(payload.status))
          ? payload.status
          : 'active',
        updatedAt: FieldValue.serverTimestamp(),
        ...(snapshot.exists ? {} : { createdAt: FieldValue.serverTimestamp() }),
      };
    } else {
      update = {
        status: action === 'plan.activate' ? 'active' :
          action === 'plan.deactivate' ? 'inactive' :
            action === 'plan.archive' ? 'archived' : '',
        updatedAt: FieldValue.serverTimestamp(),
      };
      if (!update.status) throw new HttpsError('invalid-argument', 'Thao tác gói không hợp lệ.');
      if (!snapshot.exists) throw new HttpsError('not-found', 'Không tìm thấy gói.');
    }
    transaction.set(ref, update, { merge: true });
    if (before && (before.price !== update.price || before.yearlyPrice !== update.yearlyPrice)) {
      transaction.set(ref.collection('pricingHistory').doc(), {
        previousMonthlyPrice: money(before.price),
        newMonthlyPrice: money(update.price ?? before.price),
        previousAnnualPrice: money(before.yearlyPrice),
        newAnnualPrice: money(update.yearlyPrice ?? before.yearlyPrice),
        changedBy: actor.uid,
        reason: optionalString(payload.reason),
        createdAt: FieldValue.serverTimestamp(),
      });
    }
    writePlatformAudit(transaction, actor, actionTarget('plan', planId),
      action, before, update);
  });
  return { resourceId: planId };
}

async function mutateTransaction(
  actor: PlatformContext,
  action: string,
  paymentId: string,
  payload: Record<string, unknown>,
) {
  if (!['transaction.note', 'transaction.investigate'].includes(action)) {
    throw new HttpsError('invalid-argument', 'Không được sửa dữ liệu tài chính.');
  }
  const ref = db.collection('payments').doc(paymentId);
  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    if (!snapshot.exists) throw new HttpsError('not-found', 'Không tìm thấy giao dịch.');
    const before = snapshot.data() ?? {};
    const update = action === 'transaction.note'
      ? { internalNote: requiredString(payload.note, 'note'), noteUpdatedAt: FieldValue.serverTimestamp() }
      : { investigationStatus: 'open', investigationReason: requiredString(payload.reason, 'reason'), investigatedAt: FieldValue.serverTimestamp() };
    transaction.update(ref, update);
    writePlatformAudit(transaction, actor, actionTarget('transaction', paymentId),
      action, before, { ...before, ...update });
  });
  return { resourceId: paymentId };
}

async function mutateAdmin(
  actor: PlatformContext,
  action: string,
  uid: string,
  payload: Record<string, unknown>,
) {
  const role = payload.role;
  if (!isPlatformRole(role)) throw new HttpsError('invalid-argument', 'Vai trò không hợp lệ.');
  const active = action === 'admin.create' ? true : payload.active;
  if (typeof active !== 'boolean') throw new HttpsError('invalid-argument', 'Trạng thái không hợp lệ.');
  if (uid === actor.uid && (!active || role !== 'super_admin')) {
    throw new HttpsError('failed-precondition', 'Không thể tự hạ quyền hoặc vô hiệu hóa chính mình.');
  }
  const ref = db.collection('platformAdmins').doc(uid);
  const snapshot = await ref.get();
  if (action === 'admin.update' && !snapshot.exists) {
    throw new HttpsError('not-found', 'Không tìm thấy quản trị viên.');
  }
  if (action === 'admin.create' && snapshot.exists) {
    throw new HttpsError('already-exists', 'Tài khoản đã là quản trị viên.');
  }
  const before = snapshot.data() ?? {};
  const user = await admin.auth().getUser(uid);
  await admin.auth().setCustomUserClaims(uid, {
    ...user.customClaims,
    platformAdmin: active,
  });
  const batch = db.batch();
  batch.set(ref, {
    email: user.email ?? '',
    name: user.displayName ?? '',
    role,
    active,
    updatedAt: FieldValue.serverTimestamp(),
    ...(snapshot.exists ? {} : { createdAt: FieldValue.serverTimestamp() }),
  }, { merge: true });
  writePlatformAudit(batch, actor, actionTarget('platformAdmin', uid),
    action, before, { ...before, role, active });
  await batch.commit();
  return { resourceId: uid };
}

function permissionForAction(action: string): PlatformPermission {
  if (action.startsWith('business.')) return 'business.write';
  if (action.startsWith('record.')) return 'business.write';
  if (action.startsWith('subscription.')) return 'subscription.write';
  if (action.startsWith('plan.')) return 'plan.write';
  if (action.startsWith('transaction.')) return 'transaction.reconcile';
  if (action.startsWith('admin.')) return 'admin.write';
  throw new HttpsError('invalid-argument', 'Thao tác quản trị không hợp lệ.');
}

function writePlatformAudit(
  writer: FirebaseFirestore.Transaction | FirebaseFirestore.WriteBatch,
  actor: PlatformContext,
  target: { type: string; id: string },
  action: string,
  before: unknown,
  after: unknown,
) {
  (writer as FirebaseFirestore.WriteBatch).set(db.collection('auditEvents').doc(), {
    platform: true,
    actorId: actor.uid,
    actorEmail: actor.email,
    actorRole: actor.role,
    action,
    entityType: target.type,
    entityId: target.id,
    before: serializeValue(before),
    after: serializeValue(after),
    createdAt: FieldValue.serverTimestamp(),
  });
}

function applyPaidSubscription(
  transaction: FirebaseFirestore.Transaction,
  payment: FirebaseFirestore.DocumentData,
) {
  if (!payment.tenantId || !payment.planTier) return;
  const update: Record<string, unknown> = {
    planTier: String(payment.planTier),
    subscriptionStatus: 'active',
    trialStatus: 'expired',
    planStartedAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  };
  if (payment.planExpiresAt instanceof Timestamp) update.planExpiresAt = payment.planExpiresAt;
  transaction.update(db.collection('tenants').doc(String(payment.tenantId)), update);
}

function parseRange(startValue: unknown, endValue: unknown) {
  const end = parseDate(endValue) ?? new Date();
  const start = parseDate(startValue) ?? new Date(end.getTime() - 29 * 86400000);
  if (start >= end || end.getTime() - start.getTime() > 10 * 366 * 86400000) {
    throw new HttpsError('invalid-argument', 'Khoảng thời gian phải từ 1 ngày đến 10 năm.');
  }
  return { start, end };
}

function parseDate(value: unknown): Date | null {
  if (typeof value !== 'string') return null;
  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
}

function parseActivityDays(value: unknown): number {
  const days = Number(value ?? 30);
  if (![1, 3, 7, 15, 30].includes(days)) {
    throw new HttpsError('invalid-argument', 'Khoảng hoạt động không hợp lệ.');
  }
  return days;
}

function serializeBusiness(
  id: string,
  data: FirebaseFirestore.DocumentData,
  owner: FirebaseFirestore.DocumentData,
  latestBookingAt?: number,
) {
  const storedLastActiveAt = toMillis(data.lastActiveAt);
  return {
    id,
    tenantId: String(data.tenantId ?? id),
    name: String(data.name ?? 'Chưa đặt tên'),
    ownerUid: String(data.ownerUid ?? ''),
    ownerName: String(owner.name ?? data.ownerName ?? ''),
    ownerEmail: String(owner.email ?? data.email ?? ''),
    ownerPhone: String(owner.phone ?? data.phone ?? ''),
    businessType: String(data.type ?? data.businessType ?? ''),
    province: String(data.province ?? ''),
    address: String(data.address ?? ''),
    phone: String(data.phone ?? ''),
    planTier: String(data.planTier ?? 'basic'),
    subscriptionStatus: String(data.subscriptionStatus ?? inferSubscriptionStatus(data)),
    status: normalizeBusinessStatus(data.status),
    createdAt: toMillis(data.createdAt),
    lastActiveAt: Math.max(storedLastActiveAt ?? 0, latestBookingAt ?? 0) || null,
    planStartedAt: toMillis(data.planStartedAt),
    planExpiresAt: toMillis(data.planExpiresAt),
    usageEndedAt: toMillis(data.usageEndedAt),
  };
}

function serializeTenantRecord(
  kind: TenantRecordKind,
  document: FirebaseFirestore.QueryDocumentSnapshot,
) {
  const data = document.data();
  const fields: Record<TenantRecordKind, string[]> = {
    bookings: [
      'customerId', 'customerName', 'staffId', 'staffName', 'serviceId',
      'serviceName', 'startTime', 'endTime', 'status', 'notes', 'resourceIds',
    ],
    customers: [
      'name', 'phone', 'email', 'birthday', 'notes', 'allergies', 'isVip',
      'customerTier', 'visitCount', 'lastVisit',
    ],
    staff: [
      'name', 'phone', 'email', 'role_title', 'status', 'specialties', 'active',
    ],
    services: ['name', 'price', 'duration', 'durationMin', 'category', 'resourceIds'],
    products: ['name', 'price', 'unit', 'category'],
    equipment: ['name', 'status', 'location', 'lastMaintenance', 'quantity'],
  };
  return {
    id: document.id,
    ...Object.fromEntries(fields[kind].map((field) => [field, serializeValue(data[field])])),
  };
}

function filterBusinesses(
  rows: ReturnType<typeof serializeBusiness>[],
  input: WorkspaceInput,
) {
  const query = String(input.query ?? '').trim().toLocaleLowerCase('vi');
  return rows.filter((row) => {
    if (input.province && row.province !== input.province) return false;
    if (input.businessType && row.businessType !== input.businessType) return false;
    if (input.plan && row.planTier !== input.plan) return false;
    if (input.subscriptionStatus && row.subscriptionStatus !== input.subscriptionStatus) return false;
    if (!query) return true;
    return [row.name, row.tenantId, row.ownerName, row.ownerEmail, row.ownerPhone]
      .some((value) => value.toLocaleLowerCase('vi').includes(query));
  });
}

function filterPayments(
  rows: PaymentRecord[],
  input: WorkspaceInput,
  businesses: Map<string, ReturnType<typeof serializeBusiness>>,
) {
  return rows.filter((payment) => {
    const business = businesses.get(String(payment.tenantId ?? ''));
    if (input.transactionStatus && payment.status !== input.transactionStatus) return false;
    if (input.province && business?.province !== input.province) return false;
    if (input.businessType && business?.businessType !== input.businessType) return false;
    if (input.plan && String(payment.planTier ?? business?.planTier ?? '') !== input.plan) return false;
    if (input.subscriptionStatus && business?.subscriptionStatus !== input.subscriptionStatus) return false;
    const query = String(input.query ?? '').trim().toLocaleLowerCase('vi');
    if (query) {
      const values = [
        payment.id,
        String(payment.orderCode ?? ''),
        String(payment.tenantId ?? ''),
        business?.name ?? '',
        business?.id ?? '',
        business?.ownerName ?? '',
        business?.ownerEmail ?? '',
      ];
      if (!values.some((value) => value.toLocaleLowerCase('vi').includes(query))) {
        return false;
      }
    }
    return true;
  });
}

function serializePayment(
  payment: PaymentRecord,
  business?: ReturnType<typeof serializeBusiness>,
) {
  return {
    id: payment.id,
    orderCode: payment.orderCode ?? null,
    tenantId: String(payment.tenantId ?? ''),
    businessName: business?.name ?? '',
    province: business?.province ?? '',
    businessType: business?.businessType ?? '',
    planTier: String(payment.planTier ?? business?.planTier ?? ''),
    billingPeriod: String(payment.billingPeriod ?? ''),
    type: String(payment.type ?? 'booking'),
    amount: money(payment.amount),
    provider: String(payment.provider ?? (payment.orderCode ? 'payos' : 'manual')),
    method: String(payment.method ?? payment.paymentMethod ?? ''),
    status: String(payment.status ?? 'pending'),
    providerStatus: String(payment.providerStatus ?? ''),
    webhookCode: String(payment.webhookCode ?? ''),
    webhookDesc: String(payment.webhookDesc ?? ''),
    reconciliationStatus: String(payment.reconciliationStatus ?? 'unchecked'),
    investigationStatus: String(payment.investigationStatus ?? ''),
    internalNote: String(payment.internalNote ?? ''),
    paymentLinkId: String(payment.paymentLinkId ?? ''),
    checkoutUrl: String(payment.checkoutUrl ?? ''),
    createdAt: toMillis(payment.createdAt ?? payment.recordedAt),
    completedAt: toMillis(payment.paidAt ?? payment.recordedAt),
    providerCheckedAt: toMillis(payment.providerCheckedAt),
  };
}

function buildMetrics(
  businesses: ReturnType<typeof serializeBusiness>[],
  payments: PaymentRecord[],
  previousPayments: PaymentRecord[],
  plans: Array<Record<string, unknown>>,
  range: { start: Date; end: Date },
  bookingActivity: BookingActivity[],
) {
  const paid = payments.filter((payment) => payment.status === 'paid');
  const previousPaid = previousPayments.filter((payment) => payment.status === 'paid');
  const revenue = paid.reduce((sum, payment) => sum + money(payment.amount), 0);
  const previousRevenue = previousPaid.reduce((sum, payment) => sum + money(payment.amount), 0);
  const active = businesses.filter((business) => business.subscriptionStatus === 'active');
  const planPrice = new Map(plans.map((plan) => [String(plan.id), money(plan.price)]));
  const mrr = active.reduce((sum, business) => sum + (planPrice.get(business.planTier) ?? 0), 0);
  const settledAttempts = payments.filter((payment) =>
    payment.orderCode != null &&
    !['pending', 'superseded'].includes(String(payment.status ?? 'pending')),
  );
  const failed = payments.filter((payment) => payment.status === 'failed');
  const businessIds = new Set(businesses.map((business) => business.id));
  const activeBusinessIds = new Set(
    bookingActivity
      .filter((booking) => businessIds.has(booking.tenantId))
      .map((booking) => booking.tenantId),
  );
  const eligibleBusinesses = businesses.filter((business) =>
    business.createdAt == null || business.createdAt <= range.end.getTime());
  const activeBusinesses30d = activeBusinessIds.size;
  return {
    totalRevenue: revenue,
    previousRevenue,
    revenueChangePercent: percentChange(revenue, previousRevenue),
    mrr,
    arr: mrr * 12,
    arpu: active.length ? Math.round(revenue / active.length) : 0,
    activeBusinesses: businesses.filter((business) => business.status === 'active').length,
    newBusinesses: businesses.filter((business) => {
      const createdAt = business.createdAt;
      return createdAt != null && createdAt >= range.start.getTime() && createdAt <= range.end.getTime();
    }).length,
    activeSubscriptions: active.length,
    trialBusinesses: businesses.filter((business) => business.subscriptionStatus === 'trial').length,
    failedPayments: failed.length,
    failedPaymentAmount: failed.reduce((sum, payment) => sum + money(payment.amount), 0),
    churnedBusinesses: businesses.filter((business) => {
      const endedAt = churnedAt(business);
      return endedAt != null && endedAt >= range.start.getTime() && endedAt <= range.end.getTime();
    }).length,
    activeBusinesses30d,
    usageRate30d: eligibleBusinesses.length
      ? Math.round(activeBusinesses30d / eligibleBusinesses.length * 1000) / 10
      : 0,
    transactionSuccessRate: settledAttempts.length
      ? Math.round(settledAttempts.filter((payment) => payment.status === 'paid').length / settledAttempts.length * 1000) / 10
      : 0,
  };
}

function buildAnalytics(
  businesses: ReturnType<typeof serializeBusiness>[],
  payments: PaymentRecord[],
  bookingActivity: BookingActivity[],
  range: { start: Date; end: Date },
) {
  const paid = payments.filter((payment) => payment.status === 'paid');
  return {
    revenueByDay: groupMoney(paid, (payment) => dateKey(payment.createdAt)),
    revenueByPlan: groupMoney(paid, (payment) => String(payment.planTier ?? 'Không xác định')),
    revenueByBusinessType: groupMoney(paid, (payment) =>
      businesses.find((business) => business.id === payment.tenantId)?.businessType || 'Chưa cập nhật'),
    transactionStatus: groupCount(payments, (payment) => String(payment.status ?? 'pending')),
    subscriptionStatus: groupCount(businesses, (business) => business.subscriptionStatus),
    ...buildBusinessTrends(businesses, bookingActivity, range),
  };
}

function buildBusinessTrends(
  businesses: ReturnType<typeof serializeBusiness>[],
  bookingActivity: BookingActivity[],
  range: { start: Date; end: Date },
) {
  const start = new Date(`${localDateKey(range.start)}T00:00:00Z`);
  const end = new Date(`${localDateKey(range.end)}T00:00:00Z`);
  const dates = [];
  for (const date = start; date <= end; date.setUTCDate(date.getUTCDate() + 1)) {
    dates.push(date.toISOString().slice(0, 10));
  }
  const dateSet = new Set(dates);
  const businessIds = new Set(businesses.map((business) => business.id));
  const activeByDay = new Map(dates.map((date) => [date, new Set<string>()]));
  for (const booking of bookingActivity) {
    if (!businessIds.has(booking.tenantId) || booking.startTime == null) continue;
    activeByDay.get(localDateKey(booking.startTime))?.add(booking.tenantId);
  }

  const newBusinessesByDay = Object.fromEntries(dates.map((date) => [date, 0]));
  const churnedBusinessesByDay = Object.fromEntries(dates.map((date) => [date, 0]));
  for (const business of businesses) {
    const created = localDateKey(business.createdAt);
    if (dateSet.has(created)) newBusinessesByDay[created] += 1;
    const ended = localDateKey(churnedAt(business));
    if (dateSet.has(ended)) churnedBusinessesByDay[ended] += 1;
  }

  const usageRateByDay = Object.fromEntries(dates.map((date) => {
    const dayEnd = new Date(`${date}T23:59:59.999Z`).getTime();
    const eligible = businesses.filter(
      (business) => business.createdAt == null || business.createdAt <= dayEnd,
    ).length;
    const active = activeByDay.get(date)?.size ?? 0;
    return [date, eligible ? Math.round(active / eligible * 1000) / 10 : 0];
  }));
  return { usageRateByDay, newBusinessesByDay, churnedBusinessesByDay };
}

function churnedAt(business: ReturnType<typeof serializeBusiness>): number | null {
  if (business.usageEndedAt != null) return business.usageEndedAt;
  return ['cancelled', 'expired'].includes(business.subscriptionStatus)
    ? business.planExpiresAt
    : null;
}

function groupMoney<T>(rows: T[], key: (row: T) => string) {
  const result: Record<string, number> = {};
  for (const row of rows) result[key(row)] = (result[key(row)] ?? 0) + money((row as PaymentRecord).amount);
  return result;
}

function groupCount<T>(rows: T[], key: (row: T) => string) {
  const result: Record<string, number> = {};
  for (const row of rows) result[key(row)] = (result[key(row)] ?? 0) + 1;
  return result;
}

function dateKey(value: unknown): string {
  const millis = toMillis(value);
  return millis == null ? 'Không xác định' : new Date(millis).toISOString().slice(0, 10);
}

function localDateKey(value: unknown): string {
  const millis = toMillis(value);
  return millis == null
    ? 'Không xác định'
    : new Date(millis + 7 * 3600000).toISOString().slice(0, 10);
}

function normalizePayOSStatus(value: unknown): string {
  switch (String(value ?? '').toUpperCase()) {
    case 'PAID': return 'paid';
    case 'CANCELLED': return 'cancelled';
    case 'EXPIRED': return 'failed';
    default: return 'pending';
  }
}

function normalizeBusinessStatus(value: unknown): string {
  const status = String(value ?? 'active');
  return ['active', 'trial', 'expired', 'suspended', 'cancelled', 'inactive'].includes(status)
    ? status
    : 'active';
}

function inferSubscriptionStatus(data: FirebaseFirestore.DocumentData): string {
  if (data.simulationBatchId === 'outreach-trials-2026-08') {
    return simulationTrialTenantNames.has(String(data.name ?? '')) ? 'trial' : 'expired';
  }
  if (data.status === 'cancelled') return 'cancelled';
  if (data.planExpiresAt instanceof Timestamp && data.planExpiresAt.toMillis() < Date.now()) return 'expired';
  return data.planTier && data.planTier !== 'basic' ? 'active' : 'trial';
}

function retainedSubscriptionStatus(data: FirebaseFirestore.DocumentData): string {
  if (data.simulationBatchId !== 'outreach-trials-2026-08') return 'active';
  if (data.subscriptionStatus === 'active') return 'active';
  return simulationTrialTenantNames.has(String(data.name ?? '')) ? 'trial' : 'expired';
}

function inRange(value: unknown, start: Date, end: Date): boolean {
  const millis = toMillis(value);
  return millis != null && millis >= start.getTime() && millis <= end.getTime();
}

function toMillis(value: unknown): number | null {
  if (value instanceof Timestamp) return value.toMillis();
  if (value instanceof Date) return value.getTime();
  return typeof value === 'number' && Number.isFinite(value) ? value : null;
}

function requiredTimestamp(value: unknown, field: string): Timestamp {
  const parsed = typeof value === 'number' ? new Date(value) : new Date(String(value ?? ''));
  if (Number.isNaN(parsed.getTime())) {
    throw new HttpsError('invalid-argument', `Trường ${field} không hợp lệ.`);
  }
  return Timestamp.fromDate(parsed);
}

function optionalTimestamp(value: unknown): Timestamp | null {
  if (value == null || value === '') return null;
  return requiredTimestamp(value, 'date');
}

function serializeValue(value: unknown): unknown {
  if (value instanceof Timestamp) return value.toMillis();
  if (value instanceof FieldValue) return null;
  if (Array.isArray(value)) return value.map(serializeValue);
  if (isRecord(value)) {
    return Object.fromEntries(Object.entries(value).map(([key, entry]) => [key, serializeValue(entry)]));
  }
  return value ?? null;
}

function serializeRecord(value: FirebaseFirestore.DocumentData): Record<string, unknown> {
  return serializeValue(value) as Record<string, unknown>;
}

function percentChange(current: number, previous: number): number {
  if (previous === 0) return current === 0 ? 0 : 100;
  return Math.round((current - previous) / previous * 1000) / 10;
}

export function isSelectablePlan(
  plan: FirebaseFirestore.DocumentData | undefined,
): boolean {
  const status = String(plan?.status ?? 'active');
  return status !== 'inactive' && status !== 'archived';
}

function requiredString(value: unknown, field: string): string {
  if (typeof value !== 'string' || !value.trim()) {
    throw new HttpsError('invalid-argument', `Thiếu trường ${field}.`);
  }
  return value.trim();
}

function optionalString(value: unknown): string | null {
  return typeof value === 'string' && value.trim() ? value.trim() : null;
}

function integer(value: unknown, field: string, min: number, max: number): number {
  const parsed = Number(value);
  if (!Number.isSafeInteger(parsed) || parsed < min || parsed > max) {
    throw new HttpsError('invalid-argument', `Trường ${field} không hợp lệ.`);
  }
  return parsed;
}

function money(value: unknown): number {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? Math.round(parsed) : 0;
}

function stringList(value: unknown): string[] {
  return Array.isArray(value)
    ? [...new Set(value.filter((entry): entry is string => typeof entry === 'string' && entry.trim().length > 0).map((entry) => entry.trim()))]
    : [];
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function actionTarget(type: string, id: string) { return { type, id }; }

export const __testing = {
  buildBusinessTrends,
  inferSubscriptionStatus,
  retainedSubscriptionStatus,
  normalizePayOSStatus,
  percentChange,
  parseRange,
  parseActivityDays,
  isSelectablePlan,
};
