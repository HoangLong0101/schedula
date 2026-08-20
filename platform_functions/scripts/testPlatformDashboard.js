const assert = require('node:assert/strict');
const { isPlatformAdmin, __testing } = require('../lib');
const { __testing: access } = require('../lib/access');
const { crudAction } = require('../lib/directCrud');

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
assert.equal(__testing.isSelectablePlan({}), true);
assert.equal(__testing.isSelectablePlan({ status: 'active' }), true);
assert.equal(__testing.isSelectablePlan({ status: 'inactive' }), false);
assert.equal(__testing.isSelectablePlan({ status: 'archived' }), false);
assert.equal(__testing.inferSubscriptionStatus({ planTier: 'enterprise' }), 'active');
assert.equal(__testing.inferSubscriptionStatus({
  name: 'Mị Spa', planTier: 'enterprise', simulationBatchId: 'outreach-trials-2026-08',
}), 'trial');
assert.equal(__testing.inferSubscriptionStatus({
  name: 'An Nhiên Spa & Wellness', planTier: 'enterprise', simulationBatchId: 'outreach-trials-2026-08',
}), 'expired');
assert.equal(__testing.retainedSubscriptionStatus({ subscriptionStatus: 'trial' }), 'active');
assert.equal(__testing.retainedSubscriptionStatus({
  name: 'Kim Dung Beauty', subscriptionStatus: 'trial', simulationBatchId: 'outreach-trials-2026-08',
}), 'trial');
assert.equal(__testing.retainedSubscriptionStatus({
  name: 'Oasis Spa', subscriptionStatus: 'expired', simulationBatchId: 'outreach-trials-2026-08',
}), 'expired');
assert.equal(__testing.retainedSubscriptionStatus({
  name: 'Oasis Spa', subscriptionStatus: 'active', simulationBatchId: 'outreach-trials-2026-08',
}), 'active');
assert.equal(__testing.retainedSubscriptionStatus({ subscriptionStatus: 'active' }), 'active');
const trends = __testing.buildBusinessTrends(
  [
    { id: 'tenant-1', createdAt: Date.parse('2026-08-12T02:00:00Z'), planExpiresAt: null, subscriptionStatus: 'trial' },
    { id: 'tenant-2', createdAt: Date.parse('2026-07-01T02:00:00Z'), planExpiresAt: Date.parse('2026-08-20T17:00:00Z'), usageEndedAt: Date.parse('2026-08-12T17:00:00Z'), subscriptionStatus: 'cancelled' },
    { id: 'tenant-3', createdAt: Date.parse('2026-07-19T02:00:00Z'), planExpiresAt: Date.parse('2026-08-18T17:00:00Z'), usageEndedAt: Date.parse('2026-08-12T10:00:00Z'), subscriptionStatus: 'trial' },
  ],
  [
    { tenantId: 'tenant-1', startTime: Date.parse('2026-08-13T03:00:00Z') },
    { tenantId: 'tenant-2', startTime: Date.parse('2026-08-13T04:00:00Z') },
  ],
  {
    start: new Date('2026-08-07T00:00:00Z'),
    end: new Date('2026-08-13T12:00:00Z'),
  },
);
assert.equal(trends.usageRateByDay['2026-08-13'], 66.7);
assert.equal(trends.newBusinessesByDay['2026-08-12'], 1);
assert.equal(trends.churnedBusinessesByDay['2026-08-13'], 1);
assert.equal(trends.churnedBusinessesByDay['2026-08-12'], 1);
assert.equal(crudAction(undefined, {}), 'created');
assert.equal(crudAction({}, {}), 'updated');
assert.equal(crudAction({}, undefined), 'deleted');
console.log('Platform authorization and reconciliation checks passed.');
