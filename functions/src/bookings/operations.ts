import * as admin from 'firebase-admin';
import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

if (admin.apps.length === 0) {
  admin.initializeApp();
}

const db = admin.firestore();
const defaultTimezone = 'Asia/Ho_Chi_Minh';
const activeStatuses = new Set(['pending', 'confirmed', 'in_progress']);
const transitions: Record<string, Set<string>> = {
  pending: new Set(['confirmed', 'cancelled', 'no_show']),
  confirmed: new Set(['in_progress', 'cancelled', 'no_show']),
  in_progress: new Set(['completed', 'cancelled', 'no_show']),
  completed: new Set(),
  cancelled: new Set(),
  no_show: new Set(),
};

type AuthContext = {
  uid: string;
  tenantId: string;
  role: string;
  permissions: string[];
};

type BookingInput = {
  bookingId?: string;
  action?: string;
  staffId?: string;
  customerId?: string;
  serviceId?: string;
  startTime?: string;
  endTime?: string;
  status?: string;
  notes?: string | null;
  customerName?: string;
  staffName?: string;
  serviceName?: string;
  resourceIds?: string[];
  reason?: string;
};

export const mutateBooking = onCall(
  { region: 'asia-southeast1' },
  async (request) => {
    const auth = authContext(request.auth?.uid, request.auth?.token);
    const input = request.data as BookingInput;
    const action = requiredString(input.action, 'action');

    if (!['create', 'update', 'status', 'cancel'].includes(action)) {
      throw new HttpsError('invalid-argument', 'Thao tác lịch hẹn không hỗ trợ');
    }
    if (action !== 'status' || auth.role !== 'staff') {
      requireCanBook(auth);
    }

    const bookingRef = action === 'create'
      ? db.collection('bookings').doc()
      : db.collection('bookings').doc(
        requiredString(input.bookingId, 'bookingId'),
      );

    await db.runTransaction(async (tx) => {
      const existingSnapshot = action === 'create'
        ? null
        : await tx.get(bookingRef);
      if (existingSnapshot && !existingSnapshot.exists) {
        throw new HttpsError('not-found', 'Không tìm thấy lịch hẹn');
      }

      const existing = existingSnapshot?.data() ?? {};
      if (existingSnapshot && existing.tenantId !== auth.tenantId) {
        throw new HttpsError('permission-denied', 'Không đúng cơ sở');
      }
      if (
        auth.role === 'staff' &&
        existing.staffId !== auth.uid
      ) {
        throw new HttpsError(
          'permission-denied',
          'Nhân viên chỉ có thể cập nhật lịch được phân công',
        );
      }

      if (action === 'cancel' || action === 'status') {
        const nextStatus = action === 'cancel'
          ? 'cancelled'
          : requiredString(input.status, 'status');
        assertTransition(String(existing.status ?? ''), nextStatus);
        if (nextStatus === 'completed' && existing.paymentStatus !== 'paid') {
          throw new HttpsError(
            'failed-precondition',
            'Phải ghi nhận thanh toán trước khi hoàn thành lịch hẹn',
          );
        }
        const update = {
          status: nextStatus,
          ifCancelledReason: action === 'cancel'
            ? optionalString(input.reason)
            : null,
          updatedAt: FieldValue.serverTimestamp(),
        };
        const data: Record<string, unknown> = {
          status: update.status,
          updatedAt: update.updatedAt,
        };
        if (update.ifCancelledReason) {
          data.cancelReason = update.ifCancelledReason;
        }
        tx.update(bookingRef, data);
        if (existing.staffId) {
          tx.update(db.collection('users').doc(String(existing.staffId)), {
            status: nextStatus === 'in_progress'
              ? 'in_session'
              : ['completed', 'cancelled', 'no_show'].includes(nextStatus)
                ? 'available'
                : existing.staffStatus ?? 'available',
            updatedAt: FieldValue.serverTimestamp(),
          });
        }
        if (nextStatus === 'completed') {
          incrementBookingAggregates(tx, existing);
        }
        writeAudit(tx, auth, bookingRef.id, `booking.${action}`, existing, {
          ...existing,
          ...data,
        });
        return;
      }

      const candidate = bookingCandidate(input, existing, auth.tenantId);
      const resourceSnapshot = await validateSchedule(
        tx,
        bookingRef.id,
        candidate,
        auth.tenantId,
      );

      const now = FieldValue.serverTimestamp();
      const data: Record<string, unknown> = {
        tenantId: auth.tenantId,
        staffId: candidate.staffId,
        customerId: candidate.customerId,
        serviceId: candidate.serviceId,
        startTime: candidate.startTime,
        endTime: candidate.endTime,
        status: candidate.status,
        notes: candidate.notes,
        customerName: candidate.customerName,
        staffName: candidate.staffName,
        serviceName: candidate.serviceName,
        resourceIds: candidate.resourceIds,
        resourceSnapshot,
        updatedAt: now,
      };
      if (action === 'create') {
        Object.assign(data, {
          createdBy: auth.uid,
          createdAt: now,
          reminder24Sent: false,
          reminder1hSent: false,
        });
        tx.set(bookingRef, data);
      } else {
        tx.update(bookingRef, data);
      }
      writeAudit(
        tx,
        auth,
        bookingRef.id,
        `booking.${action}`,
        existing,
        data,
      );
    });

    return { bookingId: bookingRef.id };
  },
);

export const recordManualPayment = onCall(
  { region: 'asia-southeast1' },
  async (request) => {
    const auth = authContext(request.auth?.uid, request.auth?.token);
    requireCanBook(auth);
    const data = request.data as {
      bookingId?: string;
      method?: string;
      amount?: number;
      reference?: string;
    };
    const bookingId = requiredString(data.bookingId, 'bookingId');
    const method = requiredString(data.method, 'method');
    if (!['cash', 'bank_transfer'].includes(method)) {
      throw new HttpsError('invalid-argument', 'Phương thức thanh toán không hợp lệ');
    }
    const amount = Number(data.amount);
    if (!Number.isInteger(amount) || amount <= 0) {
      throw new HttpsError('invalid-argument', 'Số tiền phải lớn hơn 0');
    }

    const bookingRef = db.collection('bookings').doc(bookingId);
    const paymentRef = db.collection('payments').doc();
    await db.runTransaction(async (tx) => {
      const snapshot = await tx.get(bookingRef);
      if (!snapshot.exists) {
        throw new HttpsError('not-found', 'Không tìm thấy lịch hẹn');
      }
      const booking = snapshot.data() ?? {};
      if (booking.tenantId !== auth.tenantId) {
        throw new HttpsError('permission-denied', 'Không đúng cơ sở');
      }
      if (booking.paymentStatus === 'paid') {
        throw new HttpsError('already-exists', 'Thanh toán đã được ghi nhận');
      }

      const payment = {
        tenantId: auth.tenantId,
        type: 'manual',
        bookingId,
        status: 'paid',
        method,
        amount,
        reference: optionalString(data.reference),
        recordedBy: auth.uid,
        recordedAt: FieldValue.serverTimestamp(),
        createdAt: FieldValue.serverTimestamp(),
      };
      tx.set(paymentRef, payment);
      tx.update(bookingRef, {
        paymentStatus: 'paid',
        paymentId: paymentRef.id,
        paymentAmount: amount,
        paymentMethod: method,
        paymentReference: payment.reference,
        paymentRecordedBy: auth.uid,
        paymentRecordedAt: FieldValue.serverTimestamp(),
        paymentPaidAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      writeAudit(
        tx,
        auth,
        bookingId,
        'booking.payment_recorded',
        booking,
        payment,
      );
    });

    return { bookingId, paymentId: paymentRef.id };
  },
);

function authContext(
  uid: string | undefined,
  token: Record<string, unknown> | undefined,
): AuthContext {
  const tenantId = token?.tenantId;
  const role = token?.role;
  if (!uid || typeof tenantId !== 'string' || typeof role !== 'string') {
    throw new HttpsError('unauthenticated', 'Phiên đăng nhập không hợp lệ');
  }
  const permissions = Array.isArray(token?.permissions)
    ? token.permissions.filter((value): value is string => typeof value === 'string')
    : [];
  return { uid, tenantId, role, permissions };
}

function requireCanBook(auth: AuthContext): void {
  if (
    auth.role !== 'owner' &&
    !auth.permissions.includes('booking.manage')
  ) {
    throw new HttpsError(
      'permission-denied',
      'Bạn không có quyền quản lý lịch hẹn',
    );
  }
}

function requiredString(value: unknown, field: string): string {
  if (typeof value !== 'string' || value.trim().length === 0) {
    throw new HttpsError('invalid-argument', `Thiếu trường ${field}`);
  }
  return value.trim();
}

function optionalString(value: unknown): string | null {
  return typeof value === 'string' && value.trim() ? value.trim() : null;
}

function parseDate(value: unknown, field: string): Timestamp {
  const date = typeof value === 'string' ? new Date(value) : null;
  if (!date || Number.isNaN(date.getTime())) {
    throw new HttpsError('invalid-argument', `Trường ${field} không hợp lệ`);
  }
  return Timestamp.fromDate(date);
}

function bookingCandidate(
  input: BookingInput,
  existing: FirebaseFirestore.DocumentData,
  tenantId: string,
) {
  const startTime = input.startTime
    ? parseDate(input.startTime, 'startTime')
    : existing.startTime as Timestamp;
  const endTime = input.endTime
    ? parseDate(input.endTime, 'endTime')
    : existing.endTime as Timestamp;
  if (!(startTime instanceof Timestamp) || !(endTime instanceof Timestamp)) {
    throw new HttpsError('invalid-argument', 'Vui lòng chọn thời gian lịch hẹn');
  }
  if (endTime.toMillis() <= startTime.toMillis()) {
    throw new HttpsError('invalid-argument', 'Giờ kết thúc phải sau giờ bắt đầu');
  }
  const status = input.status ?? String(existing.status ?? 'confirmed');
  if (!(status in transitions)) {
    throw new HttpsError('invalid-argument', 'Trạng thái lịch hẹn không hợp lệ');
  }
  return {
    tenantId,
    staffId: input.staffId
      ? requiredString(input.staffId, 'staffId')
      : requiredString(existing.staffId, 'staffId'),
    customerId: input.customerId
      ? requiredString(input.customerId, 'customerId')
      : requiredString(existing.customerId, 'customerId'),
    serviceId: input.serviceId
      ? requiredString(input.serviceId, 'serviceId')
      : requiredString(existing.serviceId, 'serviceId'),
    startTime,
    endTime,
    status,
    notes: input.notes === undefined ? existing.notes ?? null : optionalString(input.notes),
    customerName: input.customerName ?? existing.customerName ?? '',
    staffName: input.staffName ?? existing.staffName ?? '',
    serviceName: input.serviceName ?? existing.serviceName ?? '',
    resourceIds: Array.isArray(input.resourceIds)
      ? input.resourceIds.filter((id): id is string => typeof id === 'string' && id.length > 0)
      : Array.isArray(existing.resourceIds)
        ? existing.resourceIds as string[]
        : [],
  };
}

async function validateSchedule(
  tx: FirebaseFirestore.Transaction,
  bookingId: string,
  booking: ReturnType<typeof bookingCandidate>,
  tenantId: string,
): Promise<Array<{ id: string; name: string; quantity: number }>> {
  const tenantSnapshot = await tx.get(db.collection('tenants').doc(tenantId));
  const staffSnapshot = await tx.get(db.collection('users').doc(booking.staffId));
  const serviceSnapshot = await tx.get(
    db.collection('services').doc(booking.serviceId),
  );
  const customerSnapshot = await tx.get(
    db.collection('customers').doc(booking.customerId),
  );
  if (!staffSnapshot.exists || staffSnapshot.data()?.tenantId !== tenantId) {
    throw new HttpsError('failed-precondition', 'Nhân viên không khả dụng');
  }
  if (staffSnapshot.data()?.status === 'absent') {
    throw new HttpsError('failed-precondition', 'Nhân viên đang vắng mặt');
  }
  if (!serviceSnapshot.exists || serviceSnapshot.data()?.tenantId !== tenantId) {
    throw new HttpsError('failed-precondition', 'Dịch vụ không khả dụng');
  }
  if (
    !customerSnapshot.exists ||
    customerSnapshot.data()?.tenantId !== tenantId
  ) {
    throw new HttpsError('failed-precondition', 'Khách hàng không khả dụng');
  }
  const service = serviceSnapshot.data() ?? {};
  const legacyResources = Array.isArray(service.resources)
    ? service.resources
    : [];
  const canonicalResourceIds = Array.isArray(service.resourceIds)
    ? service.resourceIds.filter(
      (value): value is string => typeof value === 'string' && value.length > 0,
    )
    : [];
  const unmapped = Array.isArray(service.unmappedResources)
    ? service.unmappedResources
    : legacyResources.length > canonicalResourceIds.length
      ? legacyResources
      : [];
  if (unmapped.length > 0) {
    throw new HttpsError(
      'failed-precondition',
      'Thiết bị của dịch vụ phải được ánh xạ trước khi đặt lịch',
    );
  }
  booking.resourceIds = canonicalResourceIds;
  booking.staffName = String(
    staffSnapshot.data()?.name ?? staffSnapshot.data()?.email ?? booking.staffName,
  );
  booking.customerName = String(
    customerSnapshot.data()?.name ?? booking.customerName,
  );
  booking.serviceName = String(service.name ?? booking.serviceName);

  const tenant = tenantSnapshot.data() ?? {};
  const timezone = typeof tenant.bookingPolicy?.timezone === 'string'
    ? tenant.bookingPolicy.timezone
    : typeof tenant.timezone === 'string'
      ? tenant.timezone
      : defaultTimezone;
  validateBusinessHours(booking.startTime, booking.endTime, tenant, timezone);
  validateWeeklyShift(
    booking.startTime,
    booking.endTime,
    staffSnapshot.data()?.shift,
    timezone,
  );

  const leaveQuery = db.collection('staffLeaves')
    .where('tenantId', '==', tenantId)
    .where('staffId', '==', booking.staffId);
  const leaveSnapshot = await tx.get(leaveQuery);
  const onLeave = leaveSnapshot.docs.some((doc) => {
    const leave = doc.data();
    if (leave.active === false) return false;
    const start = leave.startTime as Timestamp | undefined;
    const end = leave.endTime as Timestamp | undefined;
    return start && end &&
      start.toMillis() < booking.endTime.toMillis() &&
      end.toMillis() > booking.startTime.toMillis();
  });
  if (onLeave) {
    throw new HttpsError('failed-precondition', 'Nhân viên đang nghỉ phép');
  }

  const overlapQuery = db.collection('bookings')
    .where('tenantId', '==', tenantId)
    .where('startTime', '<', booking.endTime);
  const overlapSnapshot = await tx.get(overlapQuery);
  const overlaps = overlapSnapshot.docs.filter((doc) => {
    if (doc.id === bookingId) return false;
    const data = doc.data();
    const end = data.endTime as Timestamp | undefined;
    return end &&
      activeStatuses.has(String(data.status)) &&
      end.toMillis() > booking.startTime.toMillis();
  });
  if (overlaps.some((doc) => doc.data().staffId === booking.staffId)) {
    throw new HttpsError('already-exists', 'Khung giờ của nhân viên đã có lịch');
  }

  const resourceSnapshot = [];
  for (const resourceId of new Set(booking.resourceIds)) {
    const equipmentSnapshot = await tx.get(
      db.collection('equipment').doc(resourceId),
    );
    if (
      !equipmentSnapshot.exists ||
      equipmentSnapshot.data()?.tenantId !== tenantId ||
      equipmentSnapshot.data()?.status === 'maintenance'
    ) {
      throw new HttpsError('failed-precondition', 'Thiết bị cần dùng không khả dụng');
    }
    const quantity = Math.max(1, Number(equipmentSnapshot.data()?.quantity) || 1);
    resourceSnapshot.push({
      id: resourceId,
      name: String(equipmentSnapshot.data()?.name ?? resourceId),
      quantity,
    });
    const used = overlaps.filter((doc) => {
      const ids = doc.data().resourceIds;
      return Array.isArray(ids) && ids.includes(resourceId);
    }).length;
    if (used >= quantity) {
      throw new HttpsError('already-exists', 'Thiết bị cần dùng đã được đặt');
    }
  }
  return resourceSnapshot;
}

function validateBusinessHours(
  start: Timestamp,
  end: Timestamp,
  tenant: FirebaseFirestore.DocumentData,
  timezone: string,
): void {
  const startLocal = localParts(start.toDate(), timezone);
  const endLocal = localParts(end.toDate(), timezone);
  if (startLocal.date !== endLocal.date) {
    throw new HttpsError('failed-precondition', 'Lịch hẹn phải kết thúc trong ngày');
  }
  const weekend = startLocal.weekday === 'sat' || startLocal.weekday === 'sun';
  const policy = tenant.bookingPolicy ?? {};
  const range = weekend
    ? [
      policy.weekendStart,
      policy.weekendEnd,
      policy.weekendHours ?? tenant.hoursWeekend,
    ]
    : [
      policy.weekdayStart,
      policy.weekdayEnd,
      policy.weekdayHours ?? tenant.hoursWeekday,
    ];
  const parsed = parseHours(range[0], range[1], range[2]);
  if (!parsed) return;
  if (startLocal.minutes < parsed.start || endLocal.minutes > parsed.end) {
    throw new HttpsError('failed-precondition', 'Lịch hẹn ngoài giờ hoạt động');
  }
}

function validateWeeklyShift(
  start: Timestamp,
  end: Timestamp,
  shift: unknown,
  timezone: string,
): void {
  if (!shift || typeof shift !== 'object') return;
  const startLocal = localParts(start.toDate(), timezone);
  const endLocal = localParts(end.toDate(), timezone);
  const value = (shift as Record<string, unknown>)[startLocal.weekday];
  if (value === 'off') {
    throw new HttpsError('failed-precondition', 'Nhân viên không làm ca này');
  }
  if (value === 'morning' && endLocal.minutes > 12 * 60) {
    throw new HttpsError('failed-precondition', 'Lịch hẹn vượt quá ca sáng');
  }
  if (value === 'afternoon' && startLocal.minutes < 12 * 60) {
    throw new HttpsError('failed-precondition', 'Lịch hẹn bắt đầu trước ca chiều');
  }
}

function localParts(date: Date, timezone: string) {
  const formatter = new Intl.DateTimeFormat('en-CA', {
    timeZone: timezone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    hourCycle: 'h23',
    weekday: 'short',
  });
  const parts = Object.fromEntries(
    formatter.formatToParts(date).map((part) => [part.type, part.value]),
  );
  return {
    date: `${parts.year}-${parts.month}-${parts.day}`,
    weekday: parts.weekday.toLowerCase().slice(0, 3),
    minutes: Number(parts.hour) * 60 + Number(parts.minute),
  };
}

function parseHours(
  startValue: unknown,
  endValue: unknown,
  legacyValue: unknown,
): { start: number; end: number } | null {
  const start = parseMinute(startValue);
  const end = parseMinute(endValue);
  if (start !== null && end !== null) return { start, end };
  if (typeof legacyValue !== 'string') return null;
  const matches = legacyValue.match(/\d{1,2}:\d{2}/g);
  if (!matches || matches.length < 2) return null;
  const legacyStart = parseMinute(matches[0]);
  const legacyEnd = parseMinute(matches[1]);
  return legacyStart === null || legacyEnd === null
    ? null
    : { start: legacyStart, end: legacyEnd };
}

function parseMinute(value: unknown): number | null {
  if (typeof value !== 'string') return null;
  const match = /^(\d{1,2}):(\d{2})$/.exec(value.trim());
  if (!match) return null;
  const hour = Number(match[1]);
  const minute = Number(match[2]);
  return hour < 24 && minute < 60 ? hour * 60 + minute : null;
}

function assertTransition(current: string, next: string): void {
  if (!transitions[current]?.has(next)) {
    throw new HttpsError(
      'failed-precondition',
      `Không thể đổi trạng thái lịch hẹn từ ${current} sang ${next}`,
    );
  }
}

function writeAudit(
  tx: FirebaseFirestore.Transaction,
  auth: AuthContext,
  entityId: string,
  action: string,
  before: unknown,
  after: unknown,
): void {
  tx.set(db.collection('auditEvents').doc(), {
    tenantId: auth.tenantId,
    actorId: auth.uid,
    actorRole: auth.role,
    entityType: 'booking',
    entityId,
    action,
    before: auditValue(before),
    after: auditValue(after),
    createdAt: FieldValue.serverTimestamp(),
  });
}

function incrementBookingAggregates(
  tx: FirebaseFirestore.Transaction,
  booking: FirebaseFirestore.DocumentData,
): void {
  const start = booking.startTime as Timestamp | undefined;
  if (!start || !booking.tenantId) return;
  const date = start.toDate();
  const dateKey = [
    date.getUTCFullYear(),
    String(date.getUTCMonth() + 1).padStart(2, '0'),
    String(date.getUTCDate()).padStart(2, '0'),
  ].join('-');
  const amount = Number(booking.paymentAmount) || 0;
  const entries = [
    {
      ref: db.collection('tenantStatsDaily').doc(
        `${booking.tenantId}_${dateKey}`,
      ),
      data: { tenantId: booking.tenantId },
    },
    {
      ref: db.collection('staffStatsDaily').doc(
        `${booking.tenantId}_${booking.staffId}_${dateKey}`,
      ),
      data: {
        tenantId: booking.tenantId,
        staffId: booking.staffId,
        staffName: booking.staffName ?? null,
      },
    },
    {
      ref: db.collection('serviceStatsDaily').doc(
        `${booking.tenantId}_${booking.serviceId}_${dateKey}`,
      ),
      data: {
        tenantId: booking.tenantId,
        serviceId: booking.serviceId,
        serviceName: booking.serviceName ?? null,
      },
    },
  ];
  for (const entry of entries) {
    tx.set(entry.ref, {
      ...entry.data,
      date: Timestamp.fromDate(
        new Date(Date.UTC(
          date.getUTCFullYear(),
          date.getUTCMonth(),
          date.getUTCDate(),
        )),
      ),
      dateKey,
      completedBookings: FieldValue.increment(1),
      revenue: FieldValue.increment(amount),
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
  }
}

function auditValue(value: unknown): unknown {
  if (!value || typeof value !== 'object') return value ?? null;
  return Object.fromEntries(
    Object.entries(value as Record<string, unknown>)
      .filter(([, entry]) => !(entry instanceof FieldValue)),
  );
}

export const __testing = {
  parseHours,
  assertTransition,
};
