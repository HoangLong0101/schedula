import * as admin from 'firebase-admin';
import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { createHmac, timingSafeEqual } from 'node:crypto';
import { HttpsError, onCall, onRequest } from 'firebase-functions/v2/https';
import { defineSecret, defineString } from 'firebase-functions/params';

if (admin.apps.length === 0) {
  admin.initializeApp();
}

const payosClientId = defineSecret('PAYOS_CLIENT_ID');
const payosApiKey = defineSecret('PAYOS_API_KEY');
const payosChecksumKey = defineSecret('PAYOS_CHECKSUM_KEY');
const payosReturnUrl = defineString('PAYOS_RETURN_URL');
const payosCancelUrl = defineString('PAYOS_CANCEL_URL');

type CreatePayOSPaymentData = {
  bookingId: string;
  amount: number;
};

type PayOSCreatePaymentResponse = {
  code: string;
  desc: string;
  data?: {
    paymentLinkId: string;
    checkoutUrl: string;
    qrCode?: string;
    status: string;
    orderCode: number;
    amount: number;
  };
};

const db = admin.firestore();

export const createPayOSPayment = onCall(
  {
    region: 'asia-southeast1',
    secrets: [payosClientId, payosApiKey, payosChecksumKey],
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Authentication is required');
    }

    const role = request.auth.token.role;
    if (role !== 'owner' && role !== 'receptionist') {
      throw new HttpsError('permission-denied', 'Owners and receptionists only');
    }

    const { bookingId, amount } = request.data as CreatePayOSPaymentData;
    if (!bookingId || !Number.isInteger(amount) || amount <= 0) {
      throw new HttpsError('invalid-argument', 'Bad payment payload');
    }

    const bookingRef = db.collection('bookings').doc(bookingId);
    const bookingSnap = await bookingRef.get();
    if (!bookingSnap.exists) {
      throw new HttpsError('not-found', 'Booking not found');
    }

    const booking = bookingSnap.data() ?? {};
    const tenantId = booking.tenantId as string | undefined;
    if (!tenantId || tenantId !== request.auth.token.tenantId) {
      throw new HttpsError('permission-denied', 'Booking is outside your tenant');
    }

    const existingPaymentSnap = await db
      .collection('payments')
      .where('bookingId', '==', bookingId)
      .where('status', 'in', ['pending', 'paid'])
      .limit(1)
      .get();

    if (!existingPaymentSnap.empty) {
      const existing = existingPaymentSnap.docs[0].data();
      return {
        paymentId: existingPaymentSnap.docs[0].id,
        checkoutUrl: existing.checkoutUrl,
        status: existing.status,
        orderCode: existing.orderCode,
        paymentLinkId: existing.paymentLinkId,
      };
    }

    const orderCode = generateOrderCode();
    const description = buildDescription(orderCode);
    const payload = {
      orderCode,
      amount,
      description,
      returnUrl: payosReturnUrl.value(),
      cancelUrl: payosCancelUrl.value(),
      items: [
        {
          name: String(booking.serviceName ?? booking.serviceId ?? 'Booking'),
          quantity: 1,
          price: amount,
        },
      ],
    };

    if (!payload.returnUrl || !payload.cancelUrl) {
      throw new HttpsError(
        'failed-precondition',
        'PAYOS_RETURN_URL and PAYOS_CANCEL_URL must be configured',
      );
    }

    const signature = signPayOSData(
      {
        amount: payload.amount,
        cancelUrl: payload.cancelUrl,
        description: payload.description,
        orderCode: payload.orderCode,
        returnUrl: payload.returnUrl,
      },
      payosChecksumKey.value(),
    );

    const response = await fetch('https://api-merchant.payos.vn/v2/payment-requests', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-client-id': payosClientId.value(),
        'x-api-key': payosApiKey.value(),
      },
      body: JSON.stringify({ ...payload, signature }),
    });

    const result = (await response.json()) as PayOSCreatePaymentResponse;
    if (!response.ok || result.code !== '00' || !result.data?.checkoutUrl) {
      throw new HttpsError(
        'internal',
        result.desc || 'PayOS payment link creation failed',
      );
    }

    const paymentRef = db.collection('payments').doc();
    await paymentRef.set({
      tenantId,
      bookingId,
      orderCode,
      amount,
      description,
      status: 'pending',
      paymentLinkId: result.data.paymentLinkId,
      checkoutUrl: result.data.checkoutUrl,
      qrCode: result.data.qrCode ?? null,
      createdBy: request.auth.uid,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });

    await bookingRef.update({
      paymentStatus: 'pending',
      paymentId: paymentRef.id,
      paymentAmount: amount,
      paymentOrderCode: orderCode,
      paymentCheckoutUrl: result.data.checkoutUrl,
      updatedAt: FieldValue.serverTimestamp(),
    });

    return {
      paymentId: paymentRef.id,
      checkoutUrl: result.data.checkoutUrl,
      status: 'pending',
      orderCode,
      paymentLinkId: result.data.paymentLinkId,
    };
  },
);

export const payosWebhook = onRequest(
  {
    region: 'asia-southeast1',
    secrets: [payosChecksumKey],
  },
  async (request, response) => {
    if (request.method !== 'POST') {
      response.status(405).send('Method Not Allowed');
      return;
    }

    const body = request.body as {
      code?: string;
      desc?: string;
      success?: boolean;
      data?: Record<string, unknown>;
      signature?: string;
    };

    if (!body.data || !body.signature) {
      response.status(400).send('Bad Request');
      return;
    }

    if (!verifyPayOSSignature(body.data, body.signature, payosChecksumKey.value())) {
      response.status(401).send('Invalid signature');
      return;
    }

    const orderCode = Number(body.data.orderCode);
    if (!Number.isInteger(orderCode)) {
      response.status(400).send('Bad orderCode');
      return;
    }

    const paymentSnap = await db
      .collection('payments')
      .where('orderCode', '==', orderCode)
      .limit(1)
      .get();

    if (paymentSnap.empty) {
      response.status(200).send('Payment not found');
      return;
    }

    const paymentDoc = paymentSnap.docs[0];
    const payment = paymentDoc.data();
    const paid = body.success === true && body.code === '00';
    const status = paid ? 'paid' : 'failed';

    await db.runTransaction(async (tx) => {
      tx.update(paymentDoc.ref, {
        status,
        webhookCode: body.code ?? null,
        webhookDesc: body.desc ?? null,
        payosData: body.data,
        paidAt: paid ? parsePayOSDate(body.data?.transactionDateTime) : null,
        updatedAt: FieldValue.serverTimestamp(),
      });

      if (payment.bookingId) {
        tx.update(db.collection('bookings').doc(String(payment.bookingId)), {
          paymentStatus: status,
          paymentPaidAt: paid ? parsePayOSDate(body.data?.transactionDateTime) : null,
          updatedAt: FieldValue.serverTimestamp(),
        });
      }
    });

    response.status(200).send('OK');
  },
);

function generateOrderCode(): number {
  return Math.floor(Date.now() / 1000) * 1000 + Math.floor(Math.random() * 1000);
}

function buildDescription(orderCode: number): string {
  return `SD${String(orderCode).slice(-7)}`.slice(0, 9);
}

function signPayOSData(data: Record<string, unknown>, checksumKey: string): string {
  return createHmac('sha256', checksumKey).update(toSortedQuery(data)).digest('hex');
}

function verifyPayOSSignature(
  data: Record<string, unknown>,
  signature: string,
  checksumKey: string,
): boolean {
  const expected = signPayOSData(data, checksumKey);
  const expectedBuffer = Buffer.from(expected, 'hex');
  const signatureBuffer = Buffer.from(signature, 'hex');
  return (
    expectedBuffer.length === signatureBuffer.length &&
    timingSafeEqual(expectedBuffer, signatureBuffer)
  );
}

function toSortedQuery(data: Record<string, unknown>): string {
  return Object.keys(data)
    .sort()
    .map((key) => `${key}=${formatSignatureValue(data[key])}`)
    .join('&');
}

function formatSignatureValue(value: unknown): string {
  if (value === null || value === undefined) {
    return '';
  }
  if (Array.isArray(value) || typeof value === 'object') {
    return JSON.stringify(value);
  }
  return String(value);
}

function parsePayOSDate(value: unknown): Timestamp | null {
  if (typeof value !== 'string' || value.trim().length === 0) {
    return null;
  }

  const normalized = value.includes('T') ? value : value.replace(' ', 'T');
  const parsed = new Date(normalized);
  if (Number.isNaN(parsed.getTime())) {
    return null;
  }
  return Timestamp.fromDate(parsed);
}
