import * as admin from 'firebase-admin';
import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import * as logger from 'firebase-functions/logger';
import { defineSecret, defineString } from 'firebase-functions/params';
import { onSchedule } from 'firebase-functions/v2/scheduler';

if (admin.apps.length === 0) {
  admin.initializeApp();
}

const resendApiKey = defineSecret('RESEND_API_KEY');
const mailFrom = defineString('REMINDER_MAIL_FROM');

const db = admin.firestore();
const minute = 60 * 1000;
const customerReminderLead = 24 * 60 * minute;
const defaultStaffReminderLeadMinutes = 60;
const maxStaffReminderLeadMinutes = 24 * 60;
const windowSize = 15 * minute;

type BookingData = {
  tenantId?: string;
  staffId?: string;
  customerId?: string;
  serviceName?: string;
  staffName?: string;
  customerName?: string;
  startTime?: Timestamp;
  endTime?: Timestamp;
  reminder24Sent?: boolean;
  reminder1hSent?: boolean;
};

type ContactData = {
  name?: string;
  email?: string;
  phone?: string;
  fcmToken?: string;
};

type SendResult = {
  channel: string;
  status: 'sent' | 'skipped' | 'failed';
  reason?: string;
  providerId?: string;
};

export const sendReminders = onSchedule(
  {
    schedule: 'every 15 minutes',
    region: 'asia-southeast1',
    secrets: [resendApiKey],
  },
  async () => {
    await Promise.all([
      sendCustomer24hReminders(),
      sendStaff1hReminders(),
    ]);
  },
);

async function sendCustomer24hReminders(): Promise<void> {
  const docs = await upcomingBookings(customerReminderLead);

  for (const doc of docs) {
    const booking = doc.data() as BookingData;
    if (booking.reminder24Sent === true) {
      continue;
    }

    const customer = await contact('customers', booking.customerId);
    const results = [await sendCustomerEmail(booking, customer)];

    await writeNotification(doc.id, booking, {
      type: 'customer_24h',
      title: 'Nhắc lịch hẹn cho khách hàng',
      message: customerMessage(booking, customer),
      channels: results,
    });

    await doc.ref.update({
      reminder24Sent: true,
      reminder24SentAt: FieldValue.serverTimestamp(),
      reminder24Channels: results,
      updatedAt: FieldValue.serverTimestamp(),
    });
  }
}

async function sendStaff1hReminders(): Promise<void> {
  const docs = await upcomingBookingsRange(
    0,
    maxStaffReminderLeadMinutes * minute + windowSize,
  );
  const tenantLeadCache = new Map<string, Promise<number>>();

  for (const doc of docs) {
    const booking = doc.data() as BookingData;
    if (booking.reminder1hSent === true) {
      continue;
    }
    const leadTimeMs = await staffReminderLeadMs(
      booking.tenantId,
      tenantLeadCache,
    );
    if (!isReminderWindow(booking.startTime, leadTimeMs)) {
      continue;
    }

    const staff = await contact('users', booking.staffId);
    const pushResult = await sendStaffPush(doc.id, booking, staff);

    await writeNotification(doc.id, booking, {
      type: 'staff_1h',
      title: 'Sắp đến lịch hẹn',
      message: staffMessage(booking),
      channels: [pushResult],
      recipientUserId: booking.staffId,
    });

    await doc.ref.update({
      reminder1hSent: true,
      reminder1hSentAt: FieldValue.serverTimestamp(),
      reminder1hChannels: [pushResult],
      updatedAt: FieldValue.serverTimestamp(),
    });
  }
}

async function upcomingBookings(leadTimeMs: number) {
  const start = Date.now() + leadTimeMs;
  const end = start + windowSize;
  return upcomingBookingsRange(start - Date.now(), end - Date.now());
}

async function upcomingBookingsRange(fromNowMs: number, toNowMs: number) {
  const now = Date.now();
  const start = now + fromNowMs;
  const end = now + toNowMs;

  const snapshot = await db
    .collection('bookings')
    .where('status', '==', 'confirmed')
    .where('startTime', '>=', Timestamp.fromMillis(start))
    .where('startTime', '<', Timestamp.fromMillis(end))
    .get();

  return snapshot.docs;
}

async function staffReminderLeadMs(
  tenantId: string | undefined,
  cache: Map<string, Promise<number>>,
): Promise<number> {
  if (!tenantId) {
    return defaultStaffReminderLeadMinutes * minute;
  }
  if (!cache.has(tenantId)) {
    cache.set(tenantId, readStaffReminderLeadMinutes(tenantId));
  }
  return (await cache.get(tenantId)!) * minute;
}

async function readStaffReminderLeadMinutes(tenantId: string): Promise<number> {
  const snapshot = await db.collection('tenants').doc(tenantId).get();
  const value = snapshot.data()?.staffReminderLeadMinutes;
  if (typeof value !== 'number' || !Number.isFinite(value)) {
    return defaultStaffReminderLeadMinutes;
  }
  return Math.min(maxStaffReminderLeadMinutes, Math.max(15, Math.round(value)));
}

function isReminderWindow(
  startTime: Timestamp | undefined,
  leadTimeMs: number,
): boolean {
  if (!startTime) {
    return false;
  }
  const diff = startTime.toMillis() - Date.now();
  return diff >= leadTimeMs && diff < leadTimeMs + windowSize;
}

async function contact(
  collection: 'customers' | 'users',
  id: string | undefined,
): Promise<ContactData | null> {
  if (!id) {
    return null;
  }

  const snapshot = await db.collection(collection).doc(id).get();
  return snapshot.exists ? (snapshot.data() as ContactData) : null;
}

async function sendStaffPush(
  bookingId: string,
  booking: BookingData,
  staff: ContactData | null,
): Promise<SendResult> {
  if (!staff?.fcmToken) {
    return { channel: 'fcm', status: 'skipped', reason: 'missing_fcm_token' };
  }

  try {
    const providerId = await admin.messaging().send({
      token: staff.fcmToken,
      notification: {
        title: 'Sắp đến lịch hẹn',
        body: staffMessage(booking),
      },
      data: {
        bookingId,
        type: 'staff_1h',
      },
    });
    return { channel: 'fcm', status: 'sent', providerId };
  } catch (error) {
    logger.error('Staff reminder FCM failed', { bookingId, error });
    return { channel: 'fcm', status: 'failed', reason: errorMessage(error) };
  }
}

async function sendCustomerEmail(
  booking: BookingData,
  customer: ContactData | null,
): Promise<SendResult> {
  if (!customer?.email) {
    return { channel: 'email', status: 'skipped', reason: 'missing_email' };
  }

  const apiKey = safeSecretValue(resendApiKey);
  const from = safeStringValue(mailFrom);
  if (!apiKey || !from) {
    return { channel: 'email', status: 'skipped', reason: 'email_not_configured' };
  }

  try {
    const response = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from,
        to: [customer.email],
        subject: 'Nhắc lịch hẹn Schedula',
        text: customerMessage(booking, customer),
      }),
    });
    const body = await response.json().catch(() => ({})) as { id?: string; message?: string };
    if (!response.ok) {
      return {
        channel: 'email',
        status: 'failed',
        reason: body.message ?? `resend_${response.status}`,
      };
    }
    return { channel: 'email', status: 'sent', providerId: body.id };
  } catch (error) {
    logger.error('Customer reminder email failed', { booking, error });
    return { channel: 'email', status: 'failed', reason: errorMessage(error) };
  }
}

async function writeNotification(
  bookingId: string,
  booking: BookingData,
  data: {
    type: string;
    title: string;
    message: string;
    channels: SendResult[];
    recipientUserId?: string;
  },
): Promise<void> {
  await db.collection('notifications').add({
    tenantId: booking.tenantId ?? '',
    bookingId,
    staffId: booking.staffId ?? '',
    customerId: booking.customerId ?? '',
    recipientUserId: data.recipientUserId ?? null,
    type: data.type,
    title: data.title,
    message: data.message,
    channels: data.channels,
    status: data.channels.some((channel) => channel.status === 'failed')
      ? 'partial'
      : 'sent',
    scheduledAt: booking.startTime ?? null,
    sentAt: FieldValue.serverTimestamp(),
    createdAt: FieldValue.serverTimestamp(),
    read: false,
  });
}

function customerMessage(booking: BookingData, customer: ContactData | null): string {
  const name = displayName(customer, booking.customerName);
  return [
    `Xin chào ${name}, Schedula nhắc bạn có lịch hẹn vào ${formatAppointmentTime(booking.startTime)}.`,
    booking.serviceName ? `Dịch vụ: ${booking.serviceName}.` : '',
    booking.staffName ? `Nhân viên phụ trách: ${booking.staffName}.` : '',
  ].filter(Boolean).join(' ');
}

function staffMessage(booking: BookingData): string {
  return [
    `Bạn có lịch hẹn với ${booking.customerName ?? 'khách hàng'} lúc ${formatAppointmentTime(booking.startTime)}.`,
    booking.serviceName ? `Dịch vụ: ${booking.serviceName}.` : '',
  ].filter(Boolean).join(' ');
}

function displayName(contact: ContactData | null, fallback?: string): string {
  return contact?.name || fallback || 'quý khách';
}

function formatAppointmentTime(value: Timestamp | undefined): string {
  if (!value) {
    return 'thời gian đã hẹn';
  }

  return new Intl.DateTimeFormat('vi-VN', {
    timeZone: 'Asia/Ho_Chi_Minh',
    hour: '2-digit',
    minute: '2-digit',
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
  }).format(value.toDate());
}

function safeSecretValue(secret: { value: () => string }): string {
  try {
    return secret.value().trim();
  } catch (_) {
    return '';
  }
}

function safeStringValue(param: { value: () => string }): string {
  try {
    return param.value().trim();
  } catch (_) {
    return '';
  }
}

function errorMessage(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}
