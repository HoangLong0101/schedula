import * as admin from 'firebase-admin';
import { Timestamp } from 'firebase-admin/firestore';
import { onSchedule } from 'firebase-functions/v2/scheduler';

if (admin.apps.length === 0) {
  admin.initializeApp();
}

export const sendReminders = onSchedule('every 15 minutes', async () => {
  const now = Date.now();
  const reminderWindowStart = now + 24 * 60 * 60 * 1000;
  const reminderWindowEnd = reminderWindowStart + 15 * 60 * 1000;
  const db = admin.firestore();

  const snapshot = await db
    .collection('bookings')
    .where('status', '==', 'confirmed')
    .where('reminder24Sent', '==', false)
    .where('startTime', '>=', Timestamp.fromMillis(reminderWindowStart))
    .where('startTime', '<', Timestamp.fromMillis(reminderWindowEnd))
    .get();

  const batch = db.batch();

  for (const doc of snapshot.docs) {
    const booking = doc.data();
    const userSnapshot = await db.collection('users').doc(booking.customerId).get();
    const fcmToken = userSnapshot.data()?.fcmToken;

    if (fcmToken) {
      await admin.messaging().send({
        token: fcmToken,
        notification: {
          title: 'Nhac lich hen',
          body: 'Ban co lich hen vao ngay mai.',
        },
      });
    }

    batch.update(doc.ref, { reminder24Sent: true });
  }

  await batch.commit();
});