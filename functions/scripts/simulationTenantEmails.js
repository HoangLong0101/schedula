const crypto = require('node:crypto');

const suppliedTenantEmails = Object.freeze({
  'An Nhiên Spa & Wellness': 'annhienspa@gmail.com',
  'Hoa Mai Spa & Beauty': 'hoamaispa@gmail.com',
  'Serenity Wellness Spa': 'serenitywellness@gmail.com',
  'Bình An Spa': 'binhanspa@gmail.com',
  'Rose Garden Beauty': 'rosegardenbeauty@gmail.com',
  'Thiên Hương Spa': 'thienhuongspa@gmail.com',
  'Luna Skin & Spa': 'lunaskinspa@gmail.com',
  'Hoàng Gia Beauty Spa': 'hoanggiabeautyspa@gmail.com',
  'Ngọc Bích Spa': 'ngocbichspa@gmail.com',
  'Sakura Beauty Lounge': 'sakurabeautylounge@gmail.com',
});

const currentSimulationTenantNames = Object.freeze([
  'An Nhiên Spa & Wellness',
  'Cát Tường Spa',
  'Lotus Beauty Spa',
  'Oasis Spa',
  'Xinh Xinh Nail & Eyelash',
  'Ngọc Anh Beauty Spa',
  'Dưỡng sinh Cô Ba',
  'Katie Spa',
  'Kim Dung Beauty',
  'Mị Spa',
  'Pure Spa',
]);

function tenantAdminEmail(name) {
  const supplied = suppliedTenantEmails[name];
  const source = supplied ? supplied.split('@')[0] : name;
  const localPart = source.normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/đ/g, 'd')
    .replace(/Đ/g, 'D')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '');
  return `${localPart}@gmail.com`;
}

function tenantIdFor(name) {
  const normalizedName = name.normalize('NFKC').trim().toLowerCase();
  if (!normalizedName) throw new Error('Tenant name is required');
  return crypto.createHash('sha256')
    .update(`schedula:tenant:v1:${normalizedName}`)
    .digest('base64')
    .replace(/[^A-Za-z0-9]/g, '')
    .slice(0, 20);
}

module.exports = { currentSimulationTenantNames, tenantAdminEmail, tenantIdFor };
