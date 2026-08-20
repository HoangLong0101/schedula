const assert = require('node:assert/strict');
const admin = require('firebase-admin');
const {
  currentSimulationTenantNames,
  tenantAdminEmail,
  tenantIdFor,
} = require('./simulationTenantEmails');

const projectId = process.env.FIREBASE_PROJECT_ID || 'schedula-543b1';
const batchId = 'outreach-trials-2026-08';
const write = process.argv.includes('--write');

admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  projectId,
});
const db = admin.firestore();
const auth = admin.auth();
const { FieldValue } = admin.firestore;

function desiredIdentity(name) {
  return { tenantId: tenantIdFor(name), email: tenantAdminEmail(name) };
}

async function loadTenants() {
  const snapshot = await db.collection('tenants')
    .where('simulationBatchId', '==', batchId)
    .get();
  const allowedNames = new Set(currentSimulationTenantNames);
  const groups = new Map();
  for (const document of snapshot.docs) {
    const name = String(document.data().name || '');
    if (!allowedNames.has(name)) throw new Error(`Unexpected simulation tenant: ${name}`);
    const documents = groups.get(name) || [];
    documents.push(document);
    groups.set(name, documents);
  }
  const missing = currentSimulationTenantNames.filter((name) => !groups.has(name));
  if (missing.length) throw new Error(`Missing simulation tenants: ${missing.join(', ')}`);

  return currentSimulationTenantNames.map((name) => {
    const identity = desiredIdentity(name);
    const documents = groups.get(name);
    const target = documents.find((document) => document.id === identity.tenantId) || null;
    const sources = documents.filter((document) => document.id !== identity.tenantId);
    if (sources.length > 1) throw new Error(`Multiple legacy tenant documents for ${name}`);
    if (target && target.data().simulationBatchId !== batchId) {
      throw new Error(`Target tenant ID collision for ${name}: ${identity.tenantId}`);
    }
    const source = sources[0] || null;
    const document = target || source;
    const legacyTenantId = source?.id || String(document.data().legacyTenantId || '');
    const ownerUid = String(document.data().ownerUid || '');
    if (!ownerUid) throw new Error(`Tenant ${name} has no ownerUid`);
    return { name, ...identity, source, target, document, legacyTenantId, ownerUid };
  });
}

async function inspectAccounts(changes) {
  const accountsByTenant = new Map();
  for (const change of changes) {
    const accountTenantId = change.source?.id || change.tenantId;
    const profiles = await db.collection('users').where('tenantId', '==', accountTenantId).get();
    if (profiles.empty) throw new Error(`No accounts found for ${change.name}`);
    const accounts = [];
    for (const profile of profiles.docs) {
      const user = await auth.getUser(profile.id);
      if (user.customClaims?.simulationBatchId !== batchId) {
        throw new Error(`Account ${profile.id} is outside the simulation cohort`);
      }
      accounts.push({ profile, user });
    }
    const owner = accounts.find(({ profile }) => profile.id === change.ownerUid);
    if (!owner) throw new Error(`Owner profile missing for ${change.name}`);
    try {
      const collision = await auth.getUserByEmail(change.email);
      if (collision.uid !== change.ownerUid) throw new Error(`Email collision: ${change.email}`);
    } catch (error) {
      if (error.code !== 'auth/user-not-found') throw error;
    }
    accountsByTenant.set(change.name, accounts);
  }
  return accountsByTenant;
}

async function inspectReferences(changes) {
  const legacyToTarget = new Map(
    changes.filter((change) => change.legacyTenantId)
      .map((change) => [change.legacyTenantId, change.tenantId]),
  );
  const legacyIds = [...legacyToTarget.keys()];
  const updates = new Map();
  if (!legacyIds.length) return updates;

  const collections = (await db.listCollections())
    .filter((collection) => collection.id !== 'tenants');
  for (const collection of collections) {
    for (const field of ['tenantId', 'entityId']) {
      const snapshot = await collection.where(field, 'in', legacyIds).get();
      for (const document of snapshot.docs) {
        const fields = updates.get(document.ref.path)?.fields || {};
        fields[field] = legacyToTarget.get(String(document.data()[field]));
        updates.set(document.ref.path, { ref: document.ref, fields });
      }
    }
  }
  return updates;
}

async function applyMigration(changes, accountsByTenant, referenceUpdates) {
  const tenantBatch = db.batch();
  for (const change of changes) {
    if (!change.source) continue;
    tenantBatch.set(db.collection('tenants').doc(change.tenantId), {
      ...change.source.data(),
      tenantId: change.tenantId,
      email: change.email,
      legacyTenantId: change.source.id,
      updatedAt: FieldValue.serverTimestamp(),
    });
  }
  await tenantBatch.commit();

  const writer = db.bulkWriter();
  writer.onWriteError((error) => error.failedAttempts < 3);
  for (const { ref, fields } of referenceUpdates.values()) {
    writer.update(ref, { ...fields, updatedAt: FieldValue.serverTimestamp() });
  }
  await writer.close();

  for (const change of changes) {
    const accounts = accountsByTenant.get(change.name);
    for (const { user } of accounts) {
      if (user.customClaims?.tenantId !== change.tenantId) {
        await auth.setCustomUserClaims(user.uid, {
          ...user.customClaims,
          tenantId: change.tenantId,
        });
      }
    }
    const owner = accounts.find(({ user }) => user.uid === change.ownerUid).user;
    if (owner.email !== change.email) {
      await auth.updateUser(change.ownerUid, { email: change.email });
    }
  }

  const finishBatch = db.batch();
  for (const change of changes) {
    const targetRef = db.collection('tenants').doc(change.tenantId);
    finishBatch.set(targetRef, {
      tenantId: change.tenantId,
      email: change.email,
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
    finishBatch.set(db.collection('users').doc(change.ownerUid), {
      email: change.email,
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
    if (change.source) finishBatch.delete(change.source.ref);
    if (change.source || change.document.data().email !== change.email) {
      finishBatch.set(db.collection('auditEvents').doc(), {
        platform: true,
        actorId: 'system:tenant-identity-migration',
        actorEmail: 'system@schedula.internal',
        actorRole: 'system',
        action: 'business.identity_updated',
        entityType: 'tenant',
        entityId: change.tenantId,
        before: {
          tenantId: change.source?.id || change.tenantId,
          ownerEmail: String(change.document.data().email || ''),
        },
        after: { tenantId: change.tenantId, ownerEmail: change.email },
        status: 'succeeded',
        createdAt: FieldValue.serverTimestamp(),
      });
    }
  }
  await finishBatch.commit();
}

async function verifyMigration(changes) {
  const refreshed = await loadTenants();
  assert.equal(refreshed.length, currentSimulationTenantNames.length);
  for (const change of refreshed) {
    assert.equal(change.document.id, change.tenantId);
    assert.equal(change.document.data().tenantId, change.tenantId);
    assert.equal(change.document.data().email, change.email);
    assert.match(change.tenantId, /^[A-Za-z0-9]{20}$/);
    assert.match(change.email, /^[a-z0-9]+@gmail\.com$/);
    const profiles = await db.collection('users').where('tenantId', '==', change.tenantId).get();
    assert(!profiles.empty, `No migrated accounts for ${change.name}`);
    for (const profile of profiles.docs) {
      const user = await auth.getUser(profile.id);
      assert.equal(user.customClaims?.tenantId, change.tenantId);
      if (profile.id === change.ownerUid) {
        assert.equal(profile.data().email, change.email);
        assert.equal(user.email, change.email);
      }
    }
  }
  const residualReferences = await inspectReferences(refreshed);
  assert.equal(residualReferences.size, 0, 'Legacy tenant references remain');
}

async function main() {
  const changes = await loadTenants();
  const accountsByTenant = await inspectAccounts(changes);
  const referenceUpdates = await inspectReferences(changes);
  console.table(changes.map((change) => ({
    tenant: change.name,
    oldId: change.source?.id || 'already migrated',
    newId: change.tenantId,
    email: change.email,
    accounts: accountsByTenant.get(change.name).length,
  })));
  console.log(`References to update: ${referenceUpdates.size}`);
  if (!write) {
    console.log('Dry run complete. Re-run with --write to apply.');
    return;
  }
  await applyMigration(changes, accountsByTenant, referenceUpdates);
  await verifyMigration(changes);
  console.log(`Migrated and verified ${changes.length} tenant identities.`);
}

main().then(() => process.exit(0)).catch((error) => {
  console.error(error);
  process.exit(1);
});
