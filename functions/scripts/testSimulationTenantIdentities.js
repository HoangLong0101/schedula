const assert = require('node:assert/strict');
const {
  currentSimulationTenantNames,
  tenantAdminEmail,
  tenantIdFor,
} = require('./simulationTenantEmails');

const emails = currentSimulationTenantNames.map(tenantAdminEmail);
const ids = currentSimulationTenantNames.map(tenantIdFor);

assert.equal(new Set(emails).size, currentSimulationTenantNames.length);
assert.equal(new Set(ids).size, currentSimulationTenantNames.length);
assert(emails.every((email) => /^[a-z0-9]+@gmail\.com$/.test(email)));
assert(ids.every((id) => /^[A-Za-z0-9]{20}$/.test(id)));
assert(ids.every((id) => !id.startsWith('sim-')));
assert.equal(tenantIdFor('Pure Spa'), tenantIdFor('Pure Spa'));

console.log(`Verified ${ids.length} realistic tenant IDs and dotless admin emails.`);
