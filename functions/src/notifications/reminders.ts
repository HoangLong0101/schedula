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
const zaloZnsAccessToken = defineSecret('ZALO_ZNS_ACCESS_TOKEN');
const zaloZnsTemplateId = defineString('ZALO_ZNS_TEMPLATE_ID');

const db = admin.firestore();
const minute = 60 * 1000;
const customerReminderLead = 24 * 60 * minute;
const staffReminderLead = 60 * minute;
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
    secrets: [resendApiKey, zaloZnsAccessToken],
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
    const results = await Promise.all([
      sendCustomerEmail(booking, customer),
      sendCustomerZalo(booking, customer),
    ]);

    await writeNotification(doc.id, booking, {
      type: 'customer_24h',
      title: 'Nhac lich hen cho khach hang',
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
  const docs = await upcomingBookings(staffReminderLead);

  for (const doc of docs) {
    const booking = doc.data() as BookingData;
    if (booking.reminder1hSent === true) {
      continue;
    }

    const staff = await contact('users', booking.staffId);
    const pushResult = await sendStaffPush(doc.id, booking, staff);

    await writeNotification(doc.id, booking, {
      type: 'staff_1h',
      title: 'Sap den lich hen',
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

  const snapshot = await db
    .collection('bookings')
    .where('status', '==', 'confirmed')
    .where('startTime', '>=', Timestamp.fromMillis(start))
    .where('startTime', '<', Timestamp.fromMillis(end))
    .get();

  return snapshot.docs;
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
        title: 'Sap den lich hen',
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
        subject: 'Nhac lich hen Schedula',
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

async function sendCustomerZalo(
  booking: BookingData,
  customer: ContactData | null,
): Promise<SendResult> {
  const phone = normalizeVietnamPhone(customer?.phone);
  if (!phone) {
    return { channel: 'zalo_zns', status: 'skipped', reason: 'missing_phone' };
  }

  const accessToken = safeSecretValue(zaloZnsAccessToken);
  const templateId = safeStringValue(zaloZnsTemplateId);
  if (!accessToken || !templateId) {
    return { channel: 'zalo_zns', status: 'skipped', reason: 'zalo_not_configured' };
  }

  try {
    const response = await fetch(
      `https://business.openapi.zalo.me/message/template?access_token=${encodeURIComponent(accessToken)}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          phone,
          template_id: templateId,
          template_data: {
            customer_name: displayName(customer, booking.customerName),
            appointment_time: formatAppointmentTime(booking.startTime),
            service_name: booking.serviceName ?? '',
            staff_name: booking.staffName ?? '',
          },
          tracking_id: `booking_${booking.tenantId ?? 'unknown'}_${Date.now()}`,
        }),
      },
    );
    const body = await response.json().catch(() => ({})) as {
      error?: number;
      message?: string;
      data?: { msg_id?: string };
    };
    if (!response.ok || (body.error !== undefined && body.error !== 0)) {
      return {
        channel: 'zalo_zns',
        status: 'failed',
        reason: body.message ?? `zalo_${response.status}`,
      };
    }
    return { channel: 'zalo_zns', status: 'sent', providerId: body.data?.msg_id };
  } catch (error) {
    logger.error('Customer reminder Zalo ZNS failed', { booking, error });
    return { channel: 'zalo_zns', status: 'failed', reason: errorMessage(error) };
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
    `Xin chao ${name}, Schedula nhac ban co lich hen vao ${formatAppointmentTime(booking.startTime)}.`,
    booking.serviceName ? `Dich vu: ${booking.serviceName}.` : '',
    booking.staffName ? `Nhan vien phu trach: ${booking.staffName}.` : '',
  ].filter(Boolean).join(' ');
}

function staffMessage(booking: BookingData): string {
  return [
    `Ban co lich hen voi ${booking.customerName ?? 'khach hang'} luc ${formatAppointmentTime(booking.startTime)}.`,
    booking.serviceName ? `Dich vu: ${booking.serviceName}.` : '',
  ].filter(Boolean).join(' ');
}

function displayName(contact: ContactData | null, fallback?: string): string {
  return contact?.name || fallback || 'quy khach';
}

function formatAppointmentTime(value: Timestamp | undefined): string {
  if (!value) {
    return 'thoi gian da hen';
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

function normalizeVietnamPhone(value: string | undefined): string | null {
  if (!value) {
    return null;
  }

  const digits = value.replace(/\D/g, '');
  if (digits.length < 9) {
    return null;
  }
  if (digits.startsWith('84')) {
    return digits;
  }
  if (digits.startsWith('0')) {
    return `84${digits.slice(1)}`;
  }
  return digits;
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
