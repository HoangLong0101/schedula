const assert = require('node:assert/strict');
const admin = require('firebase-admin');

const projectId = 'demo-schedula-functions-test';
const callableBase = `http://127.0.0.1:5001/${projectId}/asia-southeast1`;
const authBase = 'http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1';

admin.initializeApp({ projectId });

async function signIn(email, password, shouldSucceed = true) {
  const response = await fetch(
    `${authBase}/accounts:signInWithPassword?key=fake-api-key`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password, returnSecureToken: true }),
    },
  );
  if (shouldSucceed) {
    if (!response.ok) {
      throw new Error(await response.text());
    }
    return (await response.json()).idToken;
  }
  assert.equal(response.ok, false);
  return null;
}

async function call(name, token, data, shouldSucceed = true) {
  const response = await fetch(`${callableBase}/${name}`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ data }),
  });
  const body = await response.json();
  if (shouldSucceed) {
    assert.equal(response.ok, true, JSON.stringify(body));
    return body.result;
  }
  assert.equal(response.ok, false, JSON.stringify(body));
  return body.error;
}

async function createOwner(uid, email, tenantId) {
  await admin.auth().createUser({ uid, email, password: 'OwnerPass123!' });
  await admin.auth().setCustomUserClaims(uid, { role: 'owner', tenantId });
  await admin.firestore().collection('users').doc(uid).set({
    tenantId,
    role: 'owner',
    email,
  });
  return signIn(email, 'OwnerPass123!');
}

async function main() {
  const ownerToken = await createOwner(
    'owner-1',
    'owner@example.com',
    'tenant-1',
  );
  const otherOwnerToken = await createOwner(
    'owner-2',
    'other-owner@example.com',
    'tenant-2',
  );

  const created = await call('createStaffAccount', ownerToken, {
    name: 'Staff One',
    email: 'staff@example.com',
    phone: '0900000000',
    roleTitle: 'Therapist',
  });
  assert.match(created.temporaryPassword, /^Sc!/);

  const staffUser = await admin.auth().getUser(created.uid);
  assert.equal(staffUser.customClaims.role, 'staff');
  assert.equal(staffUser.customClaims.tenantId, 'tenant-1');
  assert.equal(staffUser.customClaims.mustChangePassword, true);
  const staffProfile = await admin
    .firestore()
    .collection('users')
    .doc(created.uid)
    .get();
  assert.equal(staffProfile.data().mustChangePassword, true);
  await signIn('staff@example.com', created.temporaryPassword);

  const rotated = await call(
    'rotateStaffTemporaryPassword',
    ownerToken,
    { uid: created.uid },
  );
  assert.notEqual(rotated.temporaryPassword, created.temporaryPassword);
  await signIn('staff@example.com', created.temporaryPassword, false);
  const staffToken = await signIn(
    'staff@example.com',
    rotated.temporaryPassword,
  );

  const crossTenantError = await call(
    'rotateStaffTemporaryPassword',
    otherOwnerToken,
    { uid: created.uid },
    false,
  );
  assert.equal(crossTenantError.status, 'NOT_FOUND');

  await call('recordPasswordChange', staffToken, {});
  const updatedUser = await admin.auth().getUser(created.uid);
  assert.equal(updatedUser.customClaims.mustChangePassword, false);
  const updatedProfile = await admin
    .firestore()
    .collection('users')
    .doc(created.uid)
    .get();
  assert.equal(updatedProfile.data().mustChangePassword, false);

  await call('archiveStaffAccount', ownerToken, {
    uid: created.uid,
    cancelFuture: false,
  });
  const archivedUser = await admin.auth().getUser(created.uid);
  assert.equal(archivedUser.disabled, true);
  const archivedProfile = await admin
    .firestore()
    .collection('users')
    .doc(created.uid)
    .get();
  assert.equal(archivedProfile.data().active, false);

  console.log('Staff account callable functions passed');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
