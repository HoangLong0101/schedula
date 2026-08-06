import * as admin from 'firebase-admin';
import { FieldValue } from 'firebase-admin/firestore';
import { defineSecret, defineString } from 'firebase-functions/params';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

if (admin.apps.length === 0) admin.initializeApp();

const db = admin.firestore();
const resendApiKey = defineSecret('RESEND_API_KEY');
const mailFrom = defineString('REMINDER_MAIL_FROM');

const templates = {
  birthday: {
    subject: 'Chúc mừng sinh nhật từ Schedula',
    text: (name: string) =>
      `Chúc mừng sinh nhật ${name}. Cảm ơn bạn đã luôn đồng hành cùng chúng tôi.`,
  },
  follow_up: {
    subject: 'Schedula gửi lời hỏi thăm',
    text: (name: string) =>
      `Xin chào ${name}, đã đến lúc đặt lịch chăm sóc tiếp theo của bạn.`,
  },
} as const;

export const sendCampaign = onCall(
  { region: 'asia-southeast1', secrets: [resendApiKey] },
  async (request) => {
    const token = request.auth?.token;
    const tenantId =
      typeof token?.tenantId === 'string' ? token.tenantId : undefined;
    const permissions = Array.isArray(token?.permissions)
      ? token.permissions
      : [];
    if (
      !tenantId ||
      (token?.role !== 'owner' && !permissions.includes('campaign.send'))
    ) {
      throw new HttpsError(
        'permission-denied',
        'Bạn không có quyền gửi chiến dịch email',
      );
    }

    const data = request.data as {
      templateId?: keyof typeof templates;
      subject?: string;
      body?: string;
      recipientIds?: string[];
    };
    const template = data.templateId ? templates[data.templateId] : undefined;
    const subject = data.subject?.trim() ?? '';
    const emailBody = data.body?.trim() ?? '';
    const recipientIds = [...new Set(data.recipientIds ?? [])].slice(0, 100);
    if (
      !template ||
      recipientIds.length === 0 ||
      subject.length === 0 ||
      subject.length > 150 ||
      emailBody.length === 0 ||
      emailBody.length > 5000
    ) {
      throw new HttpsError(
        'invalid-argument',
        'Mẫu, tiêu đề, nội dung và người nhận không hợp lệ',
      );
    }
    if (!resendApiKey.value() || !mailFrom.value()) {
      throw new HttpsError(
        'failed-precondition',
        'Email chưa được cấu hình trên Firebase Functions',
      );
    }

    const campaignRef = db.collection('campaigns').doc();
    await campaignRef.set({
      tenantId,
      templateId: data.templateId,
      subject,
      body: emailBody,
      recipientCount: recipientIds.length,
      createdBy: request.auth!.uid,
      createdAt: FieldValue.serverTimestamp(),
      status: 'sending',
    });

    let sent = 0;
    let failed = 0;
    for (const customerId of recipientIds) {
      const customer = await db.collection('customers').doc(customerId).get();
      const value = customer.data();
      const eligible =
        customer.exists &&
        value?.tenantId === tenantId &&
        value?.emailMarketingConsent === true &&
        value?.emailOptedOut !== true &&
        typeof value?.email === 'string' &&
        value.email.includes('@');
      let status = 'skipped';
      let providerId: string | undefined;
      let reason: string | undefined;

      if (eligible) {
        try {
          const response = await fetch('https://api.resend.com/emails', {
            method: 'POST',
            headers: {
              Authorization: `Bearer ${resendApiKey.value()}`,
              'Content-Type': 'application/json',
            },
            body: JSON.stringify({
              from: mailFrom.value(),
              to: [value!.email],
              subject: renderContent(subject, value!.name ?? 'bạn'),
              text: renderContent(emailBody, value!.name ?? 'bạn'),
            }),
          });
          const body = (await response.json().catch(() => ({}))) as {
            id?: string;
            message?: string;
          };
          status = response.ok ? 'sent' : 'failed';
          providerId = body.id;
          reason = response.ok ? undefined : body.message;
        } catch (error) {
          status = 'failed';
          reason = error instanceof Error ? error.message : 'unknown_error';
        }
      } else {
        reason = 'not_eligible';
      }

      status === 'sent' ? sent++ : failed++;
      await db.collection('campaignDeliveries').add({
        tenantId,
        campaignId: campaignRef.id,
        customerId,
        email: eligible ? value!.email : null,
        status,
        providerId: providerId ?? null,
        reason: reason ?? null,
        createdAt: FieldValue.serverTimestamp(),
      });
    }

    await campaignRef.update({
      status: failed === 0 ? 'sent' : sent === 0 ? 'failed' : 'partial',
      sent,
      failed,
      completedAt: FieldValue.serverTimestamp(),
    });
    await db.collection('auditEvents').add({
      tenantId,
      actorId: request.auth!.uid,
      entityType: 'campaign',
      entityId: campaignRef.id,
      action: 'campaign.sent',
      after: { templateId: data.templateId, subject, sent, failed },
      createdAt: FieldValue.serverTimestamp(),
    });
    return { campaignId: campaignRef.id, sent, failed };
  },
);

function renderContent(content: string, name: string): string {
  return content.split('{{name}}').join(name);
}

export const __testing = { renderContent };
