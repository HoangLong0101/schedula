const admin = require('firebase-admin');

const projectId = process.env.FIREBASE_PROJECT_ID || 'schedula-543b1';
const tenantId = process.env.SEED_TENANT_ID || 'demo-tenant';
const testUserEmail = process.env.TEST_USER_EMAIL;

admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  projectId,
});

const db = admin.firestore();

async function countCollection(collection) {
  const snapshot = await db
    .collection(collection)
    .where('tenantId', '==', tenantId)
    .count()
    .get();
  return snapshot.data().count;
}

async function main() {
  console.log(`Project: ${projectId}`);
  console.log(`Expected tenantId: ${tenantId}`);

  if (testUserEmail) {
    try {
      const user = await admin.auth().getUserByEmail(testUserEmail);
      console.log(`User: ${testUserEmail}`);
      console.log(`UID: ${user.uid}`);
      console.log('Custom claims:', user.customClaims || {});
    } catch (error) {
      console.log(`User not found: ${testUserEmail}`);
    }
  } else {
    console.log('TEST_USER_EMAIL is not set, so user claims were not checked.');
  }

  const collections = [
    'users',
    'customers',
    'services',
    'bookings',
    'slots',
    'equipment',
    'dashboardChartData',
    'weeklyRevenue',
    'aiInsights',
  ];

  for (const collection of collections) {
    const count = await countCollection(collection);
    console.log(`${collection}: ${count}`);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
