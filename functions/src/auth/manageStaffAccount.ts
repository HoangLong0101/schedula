import { randomBytes } from 'node:crypto';

import * as admin from 'firebase-admin';
import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { defineSecret, defineString } from 'firebase-functions/params';

if (admin.apps.length === 0) {
  admin.initializeApp();
}

const db = admin.firestore();
const resendApiKey = defineSecret('RESEND_API_KEY');
const mailFrom = defineString('REMINDER_MAIL_FROM');

type CreateStaffData = {
  name?: string;
  email?: string;
  phone?: string;
  roleTitle?: string;
  status?: string;
  color?: string;
  specialties?: string[];
  shift?: Record<string, string>;
};

export const createStaffAccount = onCall(
  { region: 'asia-southeast1' },
  async (request) => {
    const tenantId = ownerTenantId(request.auth?.token);
    const data = request.data as CreateStaffData;
    const name = data.name?.trim();
    const email = data.email?.trim().toLowerCase();

    if (!name || !email || !email.includes('@')) {
      throw new HttpsError(
        'invalid-argument',
        'Vui lòng nhập tên và email hợp lệ',
      );
    }

    const temporaryPassword = `Sc!${randomBytes(9).toString('base64url')}`;
    let uid: string | undefined;

    try {
      const user = await admin.auth().createUser({
        email,
        password: temporaryPassword,
        displayName: name,
      });
      uid = user.uid;
      await admin.auth().setCustomUserClaims(uid, {
        role: 'staff',
        tenantId,
        permissions: ['booking.status.own', 'customer.read'],
      });
      await db.collection('users').doc(uid).set({
        tenantId,
        role: 'staff',
        permissions: ['booking.status.own', 'customer.read'],
        role_title: data.roleTitle?.trim() ?? '',
        name,
        email,
        phone: data.phone?.trim() ?? '',
        status: data.status ?? 'available',
        color: data.color ?? '#148a9c',
        specialties: data.specialties ?? [],
        shift: data.shift ?? {},
        appointments: 0,
        rating: 5,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      return { uid, temporaryPassword };
    } catch (error) {
      if (uid) {
        await admin.auth().deleteUser(uid).catch(() => undefined);
      }
      if (errorCode(error) === 'auth/email-already-exists') {
        throw new HttpsError('already-exists', 'Email đã được sử dụng');
      }
      throw error;
    }
  },
);

export const deleteStaffAccount = onCall(
  { region: 'asia-southeast1' },
  async (request) => {
    const tenantId = ownerTenantId(request.auth?.token);
    const uid = (request.data as { uid?: string }).uid;
    if (!uid) {
      throw new HttpsError('invalid-argument', 'Thiếu mã nhân viên');
    }

    const ref = db.collection('users').doc(uid);
    const snapshot = await ref.get();
    if (!snapshot.exists ||
        snapshot.data()?.tenantId !== tenantId ||
        !isStaffRole(snapshot.data()?.role)) {
      throw new HttpsError('not-found', 'Không tìm thấy tài khoản nhân viên');
    }

    const futureBookings = await db.collection('bookings')
      .where('tenantId', '==', tenantId)
      .where('staffId', '==', uid)
      .where('startTime', '>=', Timestamp.now())
      .limit(1)
      .get();
    if (!futureBookings.empty) {
      throw new HttpsError(
        'failed-precondition',
        'Hãy xử lý lịch hẹn tương lai trước khi xóa vĩnh viễn',
      );
    }
    await admin.auth().deleteUser(uid);
    const batch = db.batch();
    batch.delete(ref);
    batch.set(db.collection('auditEvents').doc(), {
      tenantId,
      actorId: request.auth!.uid,
      actorRole: 'owner',
      entityType: 'user',
      entityId: uid,
      action: 'staff.deleted',
      before: snapshot.data(),
      createdAt: FieldValue.serverTimestamp(),
    });
    await batch.commit();
    return { success: true };
  },
);

export const archiveStaffAccount = onCall(
  { region: 'asia-southeast1' },
  async (request) => {
    const tenantId = ownerTenantId(request.auth?.token);
    const data = request.data as {
      uid?: string;
      cancelFuture?: boolean;
      reassignTo?: string;
    };
    const uid = data.uid;
    if (!uid) {
      throw new HttpsError('invalid-argument', 'Thiếu mã nhân viên');
    }
    const staffRef = db.collection('users').doc(uid);
    const staffSnapshot = await staffRef.get();
    if (
      !staffSnapshot.exists ||
      staffSnapshot.data()?.tenantId !== tenantId ||
      !isStaffRole(staffSnapshot.data()?.role)
    ) {
      throw new HttpsError('not-found', 'Không tìm thấy tài khoản nhân viên');
    }

    const bookingSnapshot = await db.collection('bookings')
      .where('tenantId', '==', tenantId)
      .where('staffId', '==', uid)
      .where('startTime', '>=', Timestamp.now())
      .get();
    const futureBookings = bookingSnapshot.docs.filter((document) =>
      ['pending', 'confirmed', 'in_progress'].includes(
        String(document.data().status),
      ),
    );
    // ponytail: one atomic batch is safer for small operators; use chunked
    // lifecycle jobs if a staff member can own more than 200 future bookings.
    if (futureBookings.length > 200) {
      throw new HttpsError(
        'resource-exhausted',
        'Hãy xử lý lịch hẹn tương lai theo từng nhóm nhỏ trước khi lưu trữ',
      );
    }
    let replacement: FirebaseFirestore.DocumentData | undefined;
    if (data.reassignTo) {
      const replacementSnapshot = await db
        .collection('users')
        .doc(data.reassignTo)
        .get();
      if (
        data.reassignTo === uid ||
        !replacementSnapshot.exists ||
        replacementSnapshot.data()?.tenantId !== tenantId ||
        replacementSnapshot.data()?.active === false ||
        !isStaffRole(replacementSnapshot.data()?.role)
      ) {
        throw new HttpsError(
          'invalid-argument',
          'Nhân viên thay thế không hợp lệ',
        );
      }
      replacement = replacementSnapshot.data();
    }
    if (
      futureBookings.length > 0 &&
      data.cancelFuture !== true &&
      !data.reassignTo
    ) {
      throw new HttpsError(
        'failed-precondition',
        'Lịch hẹn tương lai phải được chuyển giao hoặc hủy',
        { count: futureBookings.length },
      );
    }

    const batch = db.batch();
    for (const booking of futureBookings) {
      batch.update(
        booking.ref,
        data.reassignTo
          ? {
            staffId: data.reassignTo,
            staffName: replacement?.name ?? replacement?.email ?? '',
            updatedAt: FieldValue.serverTimestamp(),
          }
          : {
            status: 'cancelled',
            cancelReason: 'Tài khoản nhân viên đã được lưu trữ',
            updatedAt: FieldValue.serverTimestamp(),
          },
      );
      batch.set(db.collection('auditEvents').doc(), {
        tenantId,
        actorId: request.auth!.uid,
        actorRole: 'owner',
        entityType: 'booking',
        entityId: booking.id,
        action: data.reassignTo
          ? 'booking.reassigned'
          : 'booking.cancelled_for_staff_archive',
        before: { staffId: uid, status: booking.data().status },
        after: data.reassignTo
          ? { staffId: data.reassignTo, status: booking.data().status }
          : { staffId: uid, status: 'cancelled' },
        createdAt: FieldValue.serverTimestamp(),
      });
    }
    batch.update(staffRef, {
      active: false,
      status: 'absent',
      archivedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    batch.set(db.collection('auditEvents').doc(), {
      tenantId,
      actorId: request.auth!.uid,
      actorRole: 'owner',
      entityType: 'staff',
      entityId: uid,
      action: 'staff.archived',
      before: { active: staffSnapshot.data()?.active !== false },
      after: {
        active: false,
        cancelledBookings: data.reassignTo ? 0 : futureBookings.length,
        reassignedBookings: data.reassignTo ? futureBookings.length : 0,
        reassignTo: data.reassignTo ?? null,
      },
      createdAt: FieldValue.serverTimestamp(),
    });
    await batch.commit();
    await admin.auth().updateUser(uid, { disabled: true });
    return {
      archived: true,
      cancelledBookings: data.reassignTo ? 0 : futureBookings.length,
      reassignedBookings: data.reassignTo ? futureBookings.length : 0,
    };
  },
);

export const sendStaffPasswordReset = onCall(
  {
    region: 'asia-southeast1',
    secrets: [resendApiKey],
  },
  async (request) => {
    const tenantId = ownerTenantId(request.auth?.token);
    const uid = (request.data as { uid?: string }).uid;
    if (!uid) {
      throw new HttpsError('invalid-argument', 'Thiếu mã nhân viên');
    }
    const staffSnapshot = await db.collection('users').doc(uid).get();
    if (
      !staffSnapshot.exists ||
      staffSnapshot.data()?.tenantId !== tenantId ||
      !isStaffRole(staffSnapshot.data()?.role)
    ) {
      throw new HttpsError('not-found', 'Không tìm thấy tài khoản nhân viên');
    }
    const user = await admin.auth().getUser(uid);
    if (!user.email) {
      throw new HttpsError('failed-precondition', 'Nhân viên chưa có email');
    }
    const apiKey = resendApiKey.value();
    const from = mailFrom.value();
    if (!apiKey || !from) {
      throw new HttpsError('failed-precondition', 'Email chưa được cấu hình');
    }
    const link = await admin.auth().generatePasswordResetLink(user.email);
    const response = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from,
        to: [user.email],
        subject: 'Đặt lại mật khẩu Schedula',
        text: `Mở liên kết sau để đặt lại mật khẩu Schedula: ${link}`,
      }),
    });
    if (!response.ok) {
      throw new HttpsError(
        'internal',
        'Không thể gửi email đặt lại mật khẩu',
      );
    }
    return { sent: true };
  },
);

export const manageStaffLeave = onCall(
  { region: 'asia-southeast1' },
  async (request) => {
    const tenantId = ownerTenantId(request.auth?.token);
    const data = request.data as {
      staffId?: string;
      startTime?: string;
      endTime?: string;
    };
    const staffId = data.staffId;
    const start = data.startTime ? new Date(data.startTime) : null;
    const end = data.endTime ? new Date(data.endTime) : null;
    if (
      !staffId ||
      !start ||
      !end ||
      Number.isNaN(start.getTime()) ||
      Number.isNaN(end.getTime()) ||
      end <= start
    ) {
      throw new HttpsError('invalid-argument', 'Khoảng ngày nghỉ không hợp lệ');
    }
    const staff = await db.collection('users').doc(staffId).get();
    if (!staff.exists || staff.data()?.tenantId !== tenantId) {
      throw new HttpsError('not-found', 'Không tìm thấy tài khoản nhân viên');
    }
    const leaveRef = db.collection('staffLeaves').doc();
    const batch = db.batch();
    batch.set(leaveRef, {
      tenantId,
      staffId,
      startTime: Timestamp.fromDate(start),
      endTime: Timestamp.fromDate(end),
      active: true,
      createdBy: request.auth!.uid,
      createdAt: FieldValue.serverTimestamp(),
    });
    batch.set(db.collection('auditEvents').doc(), {
      tenantId,
      actorId: request.auth!.uid,
      actorRole: 'owner',
      entityType: 'staffLeave',
      entityId: leaveRef.id,
      action: 'staff.leave.created',
      after: { staffId, startTime: data.startTime, endTime: data.endTime },
      createdAt: FieldValue.serverTimestamp(),
    });
    await batch.commit();
    return { id: leaveRef.id };
  },
);

function ownerTenantId(
  token: Record<string, unknown> | undefined,
): string {
  if (token?.role !== 'owner' || typeof token.tenantId !== 'string') {
    throw new HttpsError('permission-denied', 'Chỉ chủ cơ sở được thực hiện');
  }
  return token.tenantId;
}

function isStaffRole(value: unknown): boolean {
  return value === 'staff' || value === 'receptionist';
}

function errorCode(error: unknown): unknown {
  return typeof error === 'object' && error !== null && 'code' in error
    ? (error as { code?: unknown }).code
    : undefined;
}
