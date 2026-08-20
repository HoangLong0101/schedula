const admin = require('firebase-admin');

admin.initializeApp();

async function main() {
  const uid = process.argv[2];
  if (!uid) {
    throw new Error('Usage: node scripts/setPlatformAdmin.js <firebase-auth-uid>');
  }

  const user = await admin.auth().getUser(uid);
  await admin.auth().setCustomUserClaims(uid, {
    ...(user.customClaims || {}),
    platformAdmin: true,
  });
  const profileRef = admin.firestore().collection('platformAdmins').doc(uid);
  const profile = await profileRef.get();
  await profileRef.set(
    {
      email: user.email || '',
      name: user.displayName || '',
      role: 'super_admin',
      active: true,
      ...(profile.exists ? {} : {
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      }),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  console.log(`Platform admin enabled for ${uid}.`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
