const assert = require('node:assert/strict');
const { __testing } = require('../lib/campaigns/sendCampaign');

assert.equal(
  __testing.renderContent('Xin chào {{name}}.', 'Nguyễn An'),
  'Xin chào Nguyễn An.',
);
assert.equal(
  __testing.renderContent('{{name}}, hẹn gặp lại {{name}}.', 'Lan'),
  'Lan, hẹn gặp lại Lan.',
);

console.log('Campaign content rendering passed');
