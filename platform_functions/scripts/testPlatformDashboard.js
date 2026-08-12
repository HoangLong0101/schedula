const assert = require('node:assert/strict');
const { isPlatformAdmin, __testing } = require('../lib');
const { __testing: access } = require('../lib/access');

assert.equal(isPlatformAdmin(undefined), false);
assert.equal(isPlatformAdmin({ platformAdmin: false }), false);
assert.equal(isPlatformAdmin({ platformAdmin: true }), true);
assert.equal(access.isPlatformRole('finance_admin'), true);
assert.equal(access.isPlatformRole('owner'), false);
assert.equal(access.permissionsFor('analyst').includes('admin.write'), false);
assert.equal(__testing.normalizePayOSStatus('PAID'), 'paid');
assert.equal(__testing.normalizePayOSStatus('CANCELLED'), 'cancelled');
assert.equal(__testing.normalizePayOSStatus('PROCESSING'), 'pending');
assert.equal(__testing.normalizePayOSStatus('EXPIRED'), 'failed');
assert.equal(__testing.percentChange(150, 100), 50);
console.log('Platform authorization and reconciliation checks passed.');
