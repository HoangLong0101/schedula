const assert = require('node:assert/strict');
const { __testing } = require('../lib/bookings/operations');

assert.deepEqual(__testing.parseHours('08:00', '17:30', ''), {
  start: 480,
  end: 1050,
});
assert.deepEqual(__testing.parseHours(null, null, '08:30 - 18:00'), {
  start: 510,
  end: 1080,
});
assert.doesNotThrow(() => __testing.assertTransition('pending', 'confirmed'));
assert.throws(() => __testing.assertTransition('cancelled', 'confirmed'));

console.log('Booking policy validation passed');
