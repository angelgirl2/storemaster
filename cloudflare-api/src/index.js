import bcrypt from 'bcryptjs';

const JSON_HEADERS = { 'content-type': 'application/json; charset=utf-8', 'cache-control': 'no-store' };
const DEFAULT_PRICES = { '30': 990000, '90': 2490000, '180': 4490000, '365': 7990000 };
const DEFAULT_FEATURES = ['sales', 'products', 'customers'];
const DEFAULT_BUSINESSES = ['*'];

function json(data, status = 200, headers = {}) {
  return new Response(JSON.stringify(data), { status, headers: { ...JSON_HEADERS, ...headers } });
}
function err(status, message, extra = {}) { return json({ message, ...extra }, status); }
function nowIso() { return new Date().toISOString(); }
function millis(value) { const n = Date.parse(value ?? ''); return Number.isFinite(n) ? n : Date.now(); }
function parseJson(text, fallback = {}) { try { return JSON.parse(text); } catch { return fallback; } }
function base64url(bytes) {
  const arr = bytes instanceof Uint8Array ? bytes : new Uint8Array(bytes);
  let s = ''; for (const b of arr) s += String.fromCharCode(b);
  return btoa(s).replaceAll('+', '-').replaceAll('/', '_').replace(/=+$/g, '');
}
function decode64url(s) {
  const fixed = s.replaceAll('-', '+').replaceAll('_', '/');
  const raw = atob(fixed + '='.repeat((4 - fixed.length % 4) % 4));
  return Uint8Array.from(raw, c => c.charCodeAt(0));
}
async function sha256(text) {
  const bytes = new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(text)));
  return Array.from(bytes, b => b.toString(16).padStart(2, '0')).join('').toUpperCase();
}
function randomToken(bytes = 32) { return base64url(crypto.getRandomValues(new Uint8Array(bytes))); }
function randomReadable(length = 14) {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  return Array.from(crypto.getRandomValues(new Uint8Array(length)), b => chars[b % chars.length]).join('');
}
async function readBody(req) {
  try { const value = await req.json(); return value && typeof value === 'object' ? value : {}; }
  catch { throw Object.assign(new Error('بدنهٔ درخواست JSON معتبر نیست.'), { status: 400 }); }
}
function headersCors(req) {
  const origin = req.headers.get('Origin') || '*';
  return {
    'access-control-allow-origin': origin,
    'access-control-allow-methods': 'GET,POST,PUT,PATCH,DELETE,OPTIONS',
    'access-control-allow-headers': 'Authorization,Content-Type,X-Admin-Key,X-Ticket-Access',
    'access-control-max-age': '86400',
    'vary': 'Origin'
  };
}
async function signJwt(payload, env) {
  const keyText = env.JWT_KEY || '';
  if (keyText.length < 32) throw new Error('JWT_KEY secret is not configured or is too short.');
  const enc = new TextEncoder();
  const key = await crypto.subtle.importKey('raw', enc.encode(keyText), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  const head = base64url(enc.encode(JSON.stringify({ alg: 'HS256', typ: 'JWT' })));
  const body = base64url(enc.encode(JSON.stringify(payload)));
  const sig = await crypto.subtle.sign('HMAC', key, enc.encode(`${head}.${body}`));
  return `${head}.${body}.${base64url(sig)}`;
}
async function verifyJwt(req, env) {
  const header = req.headers.get('Authorization') || '';
  const token = header.match(/^Bearer\s+(.+)$/i)?.[1];
  if (!token) return null;
  const parts = token.split('.'); if (parts.length !== 3) return null;
  try {
    const payload = JSON.parse(new TextDecoder().decode(decode64url(parts[1])));
    if (!payload.exp || payload.exp * 1000 <= Date.now()) return null;
    const keyText = env.JWT_KEY || ''; if (keyText.length < 32) return null;
    const key = await crypto.subtle.importKey('raw', new TextEncoder().encode(keyText), { name: 'HMAC', hash: 'SHA-256' }, false, ['verify']);
    const ok = await crypto.subtle.verify('HMAC', key, decode64url(parts[2]), new TextEncoder().encode(`${parts[0]}.${parts[1]}`));
    return ok ? payload : null;
  } catch { return null; }
}
function sid(claims) { return Number(claims?.storeId) || 0; }
function uid(claims) { return Number(claims?.sub) || 0; }
async function requireAuth(req, env) {
  const claims = await verifyJwt(req, env);
  if (!claims || sid(claims) <= 0 || uid(claims) <= 0) throw Object.assign(new Error('برای این درخواست باید وارد حساب شوید.'), { status: 401 });
  return claims;
}
function adminOk(req, env) {
  const expected = env.ADMIN_KEY || '';
  const supplied = req.headers.get('X-Admin-Key') || '';
  if (!expected || expected.length < 32 || supplied.length !== expected.length) return false;
  // Compare all bytes instead of returning on the first mismatch.
  let mismatch = 0; for (let i = 0; i < expected.length; i++) mismatch |= expected.charCodeAt(i) ^ supplied.charCodeAt(i);
  return mismatch === 0;
}
async function requireAdmin(req, env) {
  if (!adminOk(req, env)) throw Object.assign(new Error('کلید مدیر معتبر نیست.'), { status: 401 });
}
async function storeAndLicense(env, storeId) {
  return env.DB.prepare(`SELECT s.*, l.license_id,l.activation_code,l.plan,l.status AS license_status,l.expires_at,l.features_json,l.business_types_json,l.max_users,l.username AS license_username,l.recovery_code,l.initial_password,l.activation_code_used
    FROM stores s LEFT JOIN licenses l ON l.store_id=s.id WHERE s.id=? ORDER BY l.expires_at DESC LIMIT 1`).bind(storeId).first();
}
async function permissionsFor(env, storeId, userId) {
  const su = await env.DB.prepare('SELECT role,permissions_json FROM store_users WHERE store_id=? AND user_id=? AND active=1').bind(storeId, userId).first();
  return { role: su?.role || '', permissions: parseJson(su?.permissions_json, []) };
}
async function makeSession(env, store, user, su, lic) {
  const permissions = parseJson(su.permissions_json, []);
  const features = parseJson(lic.features_json, []);
  const businesses = parseJson(lic.business_types_json, ['*']);
  const payload = {
    sub: String(user.id), storeId: String(store.id), storeCode: store.code, name: user.name,
    role: su.role, perm: permissions, feature: features,
    iss: env.JWT_ISSUER || 'StoreMaster', aud: env.JWT_AUDIENCE || 'StoreMasterClient',
    iat: Math.floor(Date.now()/1000), exp: Math.floor(Date.parse(lic.expires_at)/1000)
  };
  const accessToken = await signJwt(payload, env);
  return {
    accessToken, refreshToken: '', userId: user.id, storeId: store.id, storeCode: store.code,
    username: user.username, name: user.name, role: su.role, permissions, features, businessTypes: businesses,
    licenseId: lic.license_id, licensePlan: lic.plan, licenseExpiresAt: millis(lic.expires_at), licenseStatus: lic.status,
    storeName: store.name, storeType: store.type, businessTitle: store.business_title, currency: store.currency
  };
}
async function putNotification(env, { storeId = null, eventType, title, message, metadata = {}, dedupeKey = null }) {
  await env.DB.prepare(`INSERT INTO notifications(store_id,event_type,title,message,metadata_json,dedupe_key)
    VALUES(?,?,?,?,?,?) ON CONFLICT(dedupe_key) DO NOTHING`).bind(storeId, eventType, title, message, JSON.stringify(metadata ?? {}), dedupeKey).run();
}
async function ticketForAccess(env, ticketCode, req) {
  const ticket = await env.DB.prepare('SELECT * FROM support_tickets WHERE ticket_code=?').bind(ticketCode).first();
  if (!ticket) throw Object.assign(new Error('تیکت پیدا نشد.'), { status: 404 });
  const supplied = req.headers.get('X-Ticket-Access') || '';
  if (!supplied || !ticket.access_token_hash || await sha256(supplied) !== ticket.access_token_hash)
    throw Object.assign(new Error('کلید دسترسی تیکت معتبر نیست.'), { status: 401 });
  return ticket;
}
function ticketRow(t) {
  return { id: t.id, ticketCode: t.ticket_code, type: t.type, storeCode: t.store_code, licenseId: t.license_id,
    username: t.username, deviceId: t.device_id, contact: t.contact, message: t.message, status: t.status, createdAt: millis(t.created_at) };
}
async function bootstrap(req, env) {
  const x = await readBody(req);
  if (!String(x.storeName || '').trim()) return err(400, 'نام فروشگاه الزامی است.');
  if (!String(x.storeType || '').trim()) return err(400, 'نوع کسب‌وکار الزامی است.');
  const pin = String(x.password || x.adminPin || '').trim();
  if (pin.length < 4 || pin.length > 64) return err(400, 'PIN/رمز باید بین 4 تا 64 کاراکتر باشد.');
  const policy = await env.DB.prepare('SELECT * FROM trial_policy WHERE id=1').first();
  const allowedFeatures = parseJson(policy?.features_json, DEFAULT_FEATURES);
  const allowedBusinesses = parseJson(policy?.business_types_json, DEFAULT_BUSINESSES);
  const business = String(x.storeType).trim().toUpperCase();
  if (!allowedBusinesses.includes('*') && !allowedBusinesses.includes(business)) return err(403, 'فعلاً تریال برای این نوع کسب‌وکار فعال نیست.');
  const code = `SM-${randomReadable(12)}`;
  const username = String(x.username || 'admin').trim() || 'admin';
  const name = String(x.adminName || 'مدیر').trim();
  const hashed = await bcrypt.hash(pin, 10);
  const storeResult = await env.DB.prepare('INSERT INTO stores(code,name,type,business_title,currency) VALUES(?,?,?,?,?)')
    .bind(code, String(x.storeName).trim(), business, String(x.businessTitle || x.storeName).trim(), String(x.currency || 'IRR')).run();
  const storeId = Number(storeResult.meta.last_row_id);
  const ures = await env.DB.prepare('INSERT INTO users(username,name,phone,pin_hash) VALUES(?,?,?,?)')
    .bind(username, name, String(x.phone || ''), hashed).run();
  const userId = Number(ures.meta.last_row_id);
  const perms = ['dashboard.view','sales.create','sales.edit','sales.delete','sales.refund','customers.view','customers.manage','products.view','products.manage','inventory.view','inventory.manage','reports.view','reports.advanced','accounting.expenses','accounting.manage','attendance.manage','attendance.shifts','users.manage','roles.manage','store.manage','warehouses.manage','audit.view','settings.manage','business.modules'];
  const expiry = new Date(Date.now() + Number(env.TRIAL_DAYS || 15) * 86400000).toISOString();
  const activation = String(x.activationCode || code).trim().toUpperCase();
  const licenseId = code;
  const recovery = String(x.recoveryCode || randomReadable(16));
  const stmts = [
    env.DB.prepare('INSERT INTO store_users(store_id,user_id,role,permissions_json) VALUES(?,?,?,?)').bind(storeId,userId,'OWNER',JSON.stringify(perms)),
    env.DB.prepare('INSERT INTO user_devices(store_id,user_id,device_id,platform,name) VALUES(?,?,?,?,?)').bind(storeId,userId,String(x.deviceId||''),String(x.platform||''),String(x.deviceName||'')),
    env.DB.prepare(`INSERT INTO licenses(store_id,license_id,activation_code,plan,status,expires_at,features_json,business_types_json,max_users,username,initial_password,recovery_code)
      VALUES(?,?,?,'TRIAL','ACTIVE',?,?,?,?,?,?,?)`).bind(storeId,licenseId,activation,expiry,JSON.stringify(allowedFeatures),JSON.stringify([business]),5,username,pin,recovery),
  ];
  await env.DB.batch(stmts);
  return json({ storeId, userId, storeCode: code, username, password: pin, recoveryCode: recovery, permissions: perms, licenseId,
    activationCode: activation, licensePlan: 'TRIAL', licenseStatus: 'ACTIVE', licenseExpiresAt: Date.parse(expiry), trialDays: Number(env.TRIAL_DAYS || 15),
    trialFeatures: allowedFeatures, businessTypes: [business] });
}
async function login(req, env) {
  const x = await readBody(req); const requestedStore = String(x.storeCode || '');
  const clientIp = req.headers.get('CF-Connecting-IP') || 'unknown';
  const rateKey = `${clientIp}:${requestedStore}`.slice(0, 250);
  const rate = await env.DB.prepare('SELECT * FROM login_rate_limits WHERE rate_key=?').bind(rateKey).first();
  if (rate?.blocked_until && Date.parse(rate.blocked_until) > Date.now()) return err(429, 'تعداد تلاش‌های ورود زیاد است؛ ۱۵ دقیقه دیگر دوباره تلاش کن.');
  const store = await env.DB.prepare('SELECT * FROM stores WHERE (code=? OR CAST(id AS TEXT)=?) AND active=1').bind(requestedStore, requestedStore).first();
  if (!store) return err(401, 'فروشگاه معتبر نیست');
  const userId = Number(x.userId) || 0; const username = String(x.username || '');
  let pair;
  if (userId > 0) pair = await env.DB.prepare(`SELECT u.*,su.role,su.permissions_json,su.active AS membership_active FROM users u JOIN store_users su ON su.user_id=u.id
    WHERE su.store_id=? AND su.user_id=? AND su.active=1 AND u.active=1`).bind(store.id,userId).first();
  else if (username) pair = await env.DB.prepare(`SELECT u.*,su.role,su.permissions_json,su.active AS membership_active FROM users u JOIN store_users su ON su.user_id=u.id
    WHERE su.store_id=? AND u.username=? AND su.active=1 AND u.active=1 LIMIT 1`).bind(store.id,username).first();
  const credential = String(x.password || x.pin || '');
  if (!pair || !await bcrypt.compare(credential, pair.pin_hash)) {
    const priorCount = rate && Date.now() - Date.parse(rate.window_started_at) < 15 * 60 * 1000 ? Number(rate.count || 0) : 0;
    const count = priorCount + 1;
    const blockedUntil = count >= 10 ? new Date(Date.now() + 15 * 60 * 1000).toISOString() : null;
    await env.DB.prepare(`INSERT INTO login_rate_limits(rate_key,count,window_started_at,blocked_until) VALUES(?,?,?,?)
      ON CONFLICT(rate_key) DO UPDATE SET count=excluded.count,window_started_at=excluded.window_started_at,blocked_until=excluded.blocked_until`)
      .bind(rateKey,count,count===1?nowIso():rate.window_started_at,blockedUntil).run();
    return err(401, 'نام کاربری یا رمز عبور نادرست است');
  }
  await env.DB.prepare('DELETE FROM login_rate_limits WHERE rate_key=?').bind(rateKey).run();
  const lic = await env.DB.prepare("SELECT * FROM licenses WHERE store_id=? AND status='ACTIVE' AND expires_at>? ORDER BY expires_at DESC LIMIT 1").bind(store.id, nowIso()).first();
  if (!lic) return err(403, 'لایسنس فعال یا معتبر برای این فروشگاه وجود ندارد');
  if (String(x.deviceId || '').trim()) {
    await env.DB.prepare(`INSERT INTO user_devices(store_id,user_id,device_id,platform,name,active,last_seen_at) VALUES(?,?,?,?,?,1,?)
      ON CONFLICT(store_id,user_id,device_id) DO UPDATE SET platform=excluded.platform,name=excluded.name,active=1,last_seen_at=excluded.last_seen_at`)
      .bind(store.id,pair.id,String(x.deviceId),String(x.platform||''),String(x.deviceName||''),nowIso()).run();
  }
  return json(await makeSession(env, store, pair, { role: pair.role, permissions_json: pair.permissions_json }, lic));
}
async function adminProvision(req, env) {
  await requireAdmin(req, env); const x = await readBody(req);
  if (!String(x.storeName || '').trim()) return err(400, 'نام فروشگاه الزامی است.');
  if (String(x.adminPin || x.password || '').trim().length < 4) return err(400, 'PIN مدیر حداقل 4 کاراکتر است.');
  const days = Number(x.durationDays || (x.expiresAt ? Math.ceil((Number(x.expiresAt)-Date.now())/86400000) : 0));
  if (days <= 0) return err(400, 'مدت لایسنس نامعتبر است.');
  const code = `SM-${randomReadable(12)}`; const licenseId = String(x.licenseId || `LIC-${randomReadable(16)}`).toUpperCase();
  const activation = String(x.activationCode || randomReadable(18)).toUpperCase();
  const username = String(x.username || 'admin'); const password = String(x.adminPin || x.password).trim();
  const userHash = await bcrypt.hash(password, 10); const expiry = new Date(Date.now()+days*86400000).toISOString();
  const storeR = await env.DB.prepare('INSERT INTO stores(code,name,type,business_title,currency) VALUES(?,?,?,?,?)')
    .bind(code,String(x.storeName).trim(),String(x.storeType||'RETAIL'),String(x.businessTitle||x.storeName),String(x.currency||'تومان')).run();
  const storeId = Number(storeR.meta.last_row_id);
  const ur = await env.DB.prepare('INSERT INTO users(username,name,phone,pin_hash) VALUES(?,?,?,?)')
    .bind(username,String(x.adminName||'مدیر'),String(x.phone||''),userHash).run(); const userId=Number(ur.meta.last_row_id);
  const perms = ['dashboard.view','sales.create','sales.edit','sales.delete','sales.refund','customers.view','customers.manage','products.view','products.manage','inventory.view','inventory.manage','reports.view','reports.advanced','accounting.expenses','accounting.manage','attendance.manage','attendance.shifts','users.manage','roles.manage','store.manage','warehouses.manage','audit.view','settings.manage','business.modules'];
  await env.DB.batch([
    env.DB.prepare('INSERT INTO store_users(store_id,user_id,role,permissions_json) VALUES(?,?,?,?)').bind(storeId,userId,'OWNER',JSON.stringify(perms)),
    env.DB.prepare('INSERT INTO user_devices(store_id,user_id,device_id,platform,name) VALUES(?,?,?,?,?)').bind(storeId,userId,String(x.deviceId||''),String(x.platform||''),String(x.deviceName||'')),
    env.DB.prepare(`INSERT INTO licenses(store_id,license_id,activation_code,plan,status,expires_at,original_price,final_price,discount_code,features_json,business_types_json,max_users,username,initial_password,recovery_code)
      VALUES(?,?,?,?,'ACTIVE',?,?,?,?,?,?,?,?,?,?)`).bind(storeId,licenseId,activation,String(x.plan||'STANDARD'),expiry,Number(x.originalPrice||0),Number(x.finalPrice||0),String(x.discountCode||''),JSON.stringify(x.features||DEFAULT_FEATURES),JSON.stringify(x.businessTypes||['*']),Math.max(1,Number(x.maxUsers||5)),username,password,String(x.recoveryCode||'')),
  ]);
  return json({ success:true, storeId, storeCode:code, userId, username, password, licenseId, activationCode:activation, expiresAt:Date.parse(expiry) });
}
async function licenseCreateByDevice(req, env) {
  await requireAdmin(req, env);
  const x = await readBody(req);
  const deviceId = String(x.deviceId || '').trim();
  if (!deviceId) return err(400, 'DeviceId الزامی است.');
  if (Number(x.maxUsers || 0) <= 0) return err(400, 'حداکثر کاربران باید بیشتر از صفر باشد.');

  const now = Date.now();
  let plan = String(x.plan || 'STANDARD').toUpperCase();
  let expiryMs = Number(x.expiresAt || 0);
  let originalPrice = Number(x.originalPrice || 0);
  let finalPrice = Number(x.finalPrice || 0);
  let discountCode = String(x.discountCode || '').trim().toUpperCase();
  let features = Array.isArray(x.features) ? x.features.map(v => String(v).toLowerCase()) : [];
  let businessTypes = Array.isArray(x.businessTypes) ? x.businessTypes.map(v => String(v).toUpperCase()) : ['*'];

  if (plan === 'TRIAL') {
    const policy = await env.DB.prepare('SELECT * FROM trial_policy WHERE id=1').first();
    const allowedFeatures = parseJson(policy?.features_json, DEFAULT_FEATURES);
    const allowedBusinesses = parseJson(policy?.business_types_json, DEFAULT_BUSINESSES);
    const business = String(x.storeType || businessTypes[0] || 'GENERAL').trim().toUpperCase();
    if (!business) return err(400, 'نوع کسب‌وکار برای Trial الزامی است.');
    if (!allowedBusinesses.includes('*') && !allowedBusinesses.includes(business)) return err(403, 'سیاست مرکزی مدیر اجازه Trial برای این نوع کسب‌وکار را نمی‌دهد.');
    features = features.length ? allowedFeatures.filter(v => features.includes(v)) : allowedFeatures;
    if (!features.length) return err(403, 'قابلیت‌های انتخابی با سیاست مرکزی Trial هم‌پوشانی ندارند.');
    businessTypes = [business]; expiryMs = now + Number(env.TRIAL_DAYS || 15) * 86400000; originalPrice = 0; finalPrice = 0; discountCode = '';
  }
  if (!Number.isFinite(expiryMs) || expiryMs <= now) return err(400, 'تاریخ انقضای لایسنس معتبر نیست.');
  const expiry = new Date(expiryMs).toISOString();
  const licId = String(x.licenseId || '').trim().toUpperCase();
  let device = await env.DB.prepare('SELECT * FROM user_devices WHERE device_id=? AND active=1 ORDER BY id LIMIT 1').bind(deviceId).first();
  let store; let user;

  if (!device) {
    if (!licId) return err(400, 'LicenseId برای ساخت فروشگاه الزامی است.');
    const existingStoreCode = await env.DB.prepare('SELECT id FROM stores WHERE code=?').bind(licId).first();
    if (existingStoreCode) return err(409, 'کد فروشگاه/لایسنس تکراری است.');
    const sr = await env.DB.prepare('INSERT INTO stores(code,name,type,business_title,currency) VALUES(?,?,?,?,?)')
      .bind(licId,String(x.storeName||'فروشگاه').trim(),String(x.storeType||businessTypes[0]||'GENERAL'),String(x.businessTitle||'فروشگاه'),String(x.currency||'تومان')).run();
    const storeId = Number(sr.meta.last_row_id);
    const username = String(x.username||'admin').trim()||'admin';
    const password = String(x.password||randomReadable(10));
    const ur = await env.DB.prepare('INSERT INTO users(username,name,phone,pin_hash) VALUES(?,?,?,?)')
      .bind(username,String(x.customerName||'مدیر فروشگاه'),String(x.phone||''),await bcrypt.hash(password,10)).run();
    const userId = Number(ur.meta.last_row_id);
    const ownerPermissions = ['dashboard.view','sales.create','sales.edit','sales.delete','sales.refund','customers.view','customers.manage','products.view','products.manage','inventory.view','inventory.manage','reports.view','reports.advanced','accounting.expenses','accounting.manage','attendance.manage','attendance.shifts','users.manage','roles.manage','store.manage','warehouses.manage','audit.view','settings.manage','business.modules'];
    await env.DB.batch([
      env.DB.prepare('INSERT INTO store_users(store_id,user_id,role,permissions_json) VALUES(?,?,?,?)').bind(storeId,userId,'OWNER',JSON.stringify(ownerPermissions)),
      env.DB.prepare('INSERT INTO user_devices(store_id,user_id,device_id,platform,name,active) VALUES(?,?,?,?,?,1)').bind(storeId,userId,deviceId,String(x.platform||''),String(x.deviceName||''))
    ]);
    store = await env.DB.prepare('SELECT * FROM stores WHERE id=?').bind(storeId).first();
    user = await env.DB.prepare('SELECT * FROM users WHERE id=?').bind(userId).first();
    x.password = password;
  } else {
    store = await env.DB.prepare('SELECT * FROM stores WHERE id=?').bind(device.store_id).first();
    user = await env.DB.prepare('SELECT * FROM users WHERE id=?').bind(device.user_id).first();
    if (!store || !user) return err(404, 'فروشگاه دستگاه پیدا نشد.');
    if (licId && store.code !== licId) {
      const clash=await env.DB.prepare('SELECT id FROM stores WHERE code=? AND id<>?').bind(licId,store.id).first();
      if(clash)return err(409,'کد فروشگاه جدید قبلاً استفاده شده است.');
      await env.DB.prepare('UPDATE stores SET code=? WHERE id=?').bind(licId,store.id).run(); store.code=licId;
    }
    const statements=[];
    if(String(x.username||'').trim()) statements.push(env.DB.prepare('UPDATE users SET username=? WHERE id=?').bind(String(x.username).trim(),user.id));
    if(String(x.password||'').trim()) statements.push(env.DB.prepare('UPDATE users SET pin_hash=? WHERE id=?').bind(await bcrypt.hash(String(x.password),10),user.id));
    if(String(x.customerName||'').trim()) statements.push(env.DB.prepare('UPDATE users SET name=? WHERE id=?').bind(String(x.customerName).trim(),user.id));
    if(String(x.phone||'').trim()) statements.push(env.DB.prepare('UPDATE users SET phone=? WHERE id=?').bind(String(x.phone).trim(),user.id));
    statements.push(env.DB.prepare('UPDATE user_devices SET active=1,platform=?,name=?,last_seen_at=? WHERE id=?').bind(String(x.platform||device.platform||''),String(x.deviceName||device.name||''),nowIso(),device.id));
    if(statements.length) await env.DB.batch(statements);
    user=await env.DB.prepare('SELECT * FROM users WHERE id=?').bind(user.id).first();
  }

  const actualLicenseId = licId || `LIC-${randomReadable(16)}`;
  const existingLicense = await env.DB.prepare('SELECT * FROM licenses WHERE license_id=?').bind(actualLicenseId).first();
  if (existingLicense) {
    if (existingLicense.plan === 'TRIAL' && plan !== 'TRIAL') {
      const activation=String(x.activationCode||existingLicense.activation_code||randomReadable(18)).trim().toUpperCase();
      const hashedPassword=String(x.password||'').trim()?await bcrypt.hash(String(x.password),10):null;
      const stmts=[env.DB.prepare(`UPDATE licenses SET status='ACTIVE',plan=?,issued_at=?,expires_at=?,original_price=?,final_price=?,discount_code=?,features_json=?,business_types_json=?,max_users=?,activation_code=?,activation_code_used=0,initial_password=? WHERE id=?`)
        .bind(plan,nowIso(),expiry,originalPrice,finalPrice,discountCode,JSON.stringify(features),JSON.stringify(businessTypes),Math.max(1,Number(x.maxUsers)),activation,String(x.password||existingLicense.initial_password||''),existingLicense.id)];
      if(hashedPassword)stmts.push(env.DB.prepare('UPDATE users SET pin_hash=? WHERE id=?').bind(hashedPassword,user.id));
      await env.DB.batch(stmts);
    } else if(String(x.password||'').trim()) {
      await env.DB.batch([env.DB.prepare('UPDATE users SET pin_hash=? WHERE id=?').bind(await bcrypt.hash(String(x.password),10),user.id),env.DB.prepare('UPDATE licenses SET initial_password=? WHERE id=?').bind(String(x.password),existingLicense.id)]);
    }
    const updated=await env.DB.prepare('SELECT * FROM licenses WHERE license_id=?').bind(actualLicenseId).first();
    return json({licenseId:updated.license_id,storeId:updated.store_id,userId:user.id,storeCode:store.code,activationCode:updated.activation_code,username:user.username,expiresAt:millis(updated.expires_at),originalPrice:updated.original_price,finalPrice:updated.final_price,discountCode:updated.discount_code});
  }
  if(discountCode){
    const d=await env.DB.prepare('SELECT * FROM discounts WHERE code=? AND active=1').bind(discountCode).first();
    if(!d)return err(400,'کد تخفیف معتبر نیست'); if(d.expires_at&&Date.parse(d.expires_at)<=now)return err(400,'کد تخفیف منقضی شده است'); if(d.max_uses>0&&d.used_count>=d.max_uses)return err(400,'سقف استفاده از کد تخفیف تکمیل شده است');
    finalPrice=Math.max(0,originalPrice-(originalPrice*d.percent/100)-d.fixed_amount); await env.DB.prepare('UPDATE discounts SET used_count=used_count+1 WHERE id=?').bind(d.id).run();
  }
  const activationCode=String(x.activationCode||randomReadable(18)).trim().toUpperCase();
  await env.DB.prepare(`INSERT INTO licenses(store_id,license_id,activation_code,plan,status,issued_at,expires_at,original_price,final_price,discount_code,features_json,business_types_json,max_users,username,initial_password,recovery_code)
    VALUES(?,?,?,?,'ACTIVE',?,?,?,?,?,?,?,?,?,?,?)`).bind(store.id,actualLicenseId,activationCode,plan,nowIso(),expiry,originalPrice,finalPrice,discountCode,JSON.stringify(features),JSON.stringify(businessTypes),Math.max(1,Number(x.maxUsers)),user.username,String(x.password||''),String(x.recoveryCode||'')).run();
  // The existing API's contract is one license ID per store code.
  if(store.code!==actualLicenseId) await env.DB.prepare('UPDATE stores SET code=? WHERE id=?').bind(actualLicenseId,store.id).run();
  return json({licenseId:actualLicenseId,storeId:store.id,userId:user.id,storeCode:actualLicenseId,activationCode,username:user.username,expiresAt:expiryMs,originalPrice,finalPrice,discountCode});
}

async function handle(req, env) {
  const url = new URL(req.url); const method=req.method.toUpperCase();
  if (method==='OPTIONS') return new Response(null,{status:204,headers:headersCors(req)});
  if (url.pathname==='/health' || url.pathname==='/health/ready' || url.pathname==='/') return json({status:'ok',service:env.APP_NAME||'StoreMaster API',database:!!env.DB,storage:!!env.FILES,serverTime:Date.now()});
  if (!url.pathname.startsWith('/api/v1/')) return err(404,'مسیر پیدا نشد.');
  const route=url.pathname.slice('/api/v1/'.length).split('/').filter(Boolean).map(decodeURIComponent);
  const r=route.join('/');
  if (r==='public/time' && method==='GET') return json({serverTime:Date.now(),utc:nowIso()});
  if ((r==='public/pricing'||r==='licenses/pricing'||r==='admin/pricing') && method==='GET') {
    if(r==='admin/pricing') await requireAdmin(req,env);
    const rows=await env.DB.prepare('SELECT plan_days,price,currency,updated_at FROM pricing_entries ORDER BY plan_days').all();
    const prices=Object.fromEntries(rows.results.map(x=>[String(x.plan_days),x.price]));
    return json({version:rows.results.length?Math.max(...rows.results.map(x=>millis(x.updated_at))):Date.now(),currency:rows.results[0]?.currency||'تومان',prices:Object.keys(prices).length?prices:DEFAULT_PRICES});
  }
  if(r==='public/pricing'&&method==='GET') return json({version:Date.now(),currency:'تومان',prices:DEFAULT_PRICES});
  if(r==='stores/bootstrap'&&method==='POST') return bootstrap(req,env);
  if(r==='auth/login'&&method==='POST') return login(req,env);
  if(r==='auth/me'&&method==='GET') {
    const c=await requireAuth(req,env); const sidv=sid(c), uidv=uid(c);
    const row=await env.DB.prepare(`SELECT u.username,u.name,s.id AS store_id,s.code,s.name AS store_name,s.type,s.business_title,s.currency,su.role,su.permissions_json,
      l.license_id,l.status,l.expires_at,l.plan,l.features_json,l.business_types_json FROM users u JOIN store_users su ON su.user_id=u.id JOIN stores s ON s.id=su.store_id
      LEFT JOIN licenses l ON l.store_id=s.id WHERE u.id=? AND s.id=? AND su.active=1 ORDER BY l.expires_at DESC LIMIT 1`).bind(uidv,sidv).first();
    if(!row)return err(401,'نشست کاربری معتبر نیست.');
    return json({userId:uidv,storeId:sidv,storeCode:row.code,storeName:row.store_name,storeType:row.type,businessTitle:row.business_title,currency:row.currency,username:row.username,role:row.role,
      permissions:parseJson(row.permissions_json,[]),license:row.license_id?{licenseId:row.license_id,status:row.status,expiresAt:millis(row.expires_at),plan:row.plan,features:parseJson(row.features_json,[]),businessTypes:parseJson(row.business_types_json,['*'])}:null});
  }
  if(r==='auth/logout-device'&&method==='POST') {
    const c=await requireAuth(req,env), x=await readBody(req); await env.DB.prepare('UPDATE user_devices SET active=0 WHERE store_id=? AND user_id=? AND device_id=?').bind(sid(c),uid(c),String(x.deviceId||'')).run(); return json({success:true});
  }
  if(r==='licenses/activate'&&method==='POST') {
    const x=await readBody(req), lic=await env.DB.prepare('SELECT * FROM licenses WHERE license_id=?').bind(String(x.licenseId||'')).first();
    if(!lic)return err(404,'لایسنس پیدا نشد'); const dev=await env.DB.prepare('SELECT id FROM user_devices WHERE store_id=? AND device_id=? AND active=1').bind(lic.store_id,String(x.deviceId||'')).first();
    if(!dev)return err(401,'دستگاه با لایسنس ثبت نشده است'); const active=lic.status==='ACTIVE'&&Date.parse(lic.expires_at)>Date.now();
    return json({valid:active,status:active?'ACTIVE':lic.status!=='ACTIVE'?lic.status:'EXPIRED',activationMode:'ONLINE',storeCode:lic.license_id,username:lic.username,recoveryCode:lic.recovery_code,licenseId:lic.license_id,licensePlan:lic.plan,licenseExpiresAt:millis(lic.expires_at),serverTime:Date.now(),features:parseJson(lic.features_json,[]),businessTypes:parseJson(lic.business_types_json,['*'])});
  }
  if(r==='licenses/activate-code'&&method==='POST') {
    const x=await readBody(req), code=String(x.code||'').trim().toUpperCase();
    const lic=await env.DB.prepare('SELECT * FROM licenses WHERE activation_code=? OR license_id=?').bind(code,code).first();
    if(!lic)return err(404,'کد فعال‌سازی پیدا نشد.'); if(lic.status!=='ACTIVE')return err(403,`وضعیت لایسنس ${lic.status} است.`); if(Date.parse(lic.expires_at)<=Date.now())return err(403,'اعتبار لایسنس به پایان رسیده است.');
    const device=await env.DB.prepare('SELECT * FROM user_devices WHERE store_id=? AND device_id=? AND active=1').bind(lic.store_id,String(x.deviceId||'')).first();
    if(!device)return err(401,'این Device ID برای این لایسنس ثبت نشده است.'); if(lic.activation_code_used)return err(409,'این کد فعال‌سازی قبلاً استفاده شده است.');
    const user=await env.DB.prepare('SELECT * FROM users WHERE id=?').bind(device.user_id).first(), store=await env.DB.prepare('SELECT * FROM stores WHERE id=?').bind(lic.store_id).first();
    if(!user||!store)return err(404,'اطلاعات فروشگاه کامل نیست.'); const password=lic.initial_password||randomReadable(10), username=lic.username||'admin';
    await env.DB.batch([env.DB.prepare('UPDATE users SET username=?,pin_hash=?,active=1 WHERE id=?').bind(username,await bcrypt.hash(password,10),user.id),env.DB.prepare('UPDATE licenses SET activation_code_used=1 WHERE id=?').bind(lic.id)]);
    const su=await env.DB.prepare('SELECT * FROM store_users WHERE store_id=? AND user_id=? AND active=1').bind(store.id,user.id).first();
    return json({valid:true,activationMode:'ONLINE',storeCode:lic.license_id,username,password,recoveryCode:lic.recovery_code,userId:user.id,storeId:store.id,storeName:store.name,storeType:store.type,businessTitle:store.business_title,currency:store.currency,licenseId:lic.license_id,licensePlan:lic.plan,licenseStatus:lic.status,licenseExpiresAt:millis(lic.expires_at),features:parseJson(lic.features_json,[]),businessTypes:parseJson(lic.business_types_json,[]),permissions:parseJson(su?.permissions_json,'[]')});
  }
  if(r==='licenses/me'&&method==='GET') {
    const c=await requireAuth(req,env), lic=await env.DB.prepare('SELECT * FROM licenses WHERE store_id=? ORDER BY expires_at DESC LIMIT 1').bind(sid(c)).first();
    if(!lic)return err(404,'لایسنس پیدا نشد'); const active=lic.status==='ACTIVE'&&Date.parse(lic.expires_at)>Date.now();
    return json({valid:active,status:active?'ACTIVE':lic.status!=='ACTIVE'?lic.status:'EXPIRED',activationMode:'ONLINE',storeCode:lic.license_id,username:lic.username,recoveryCode:lic.recovery_code,licenseId:lic.license_id,licensePlan:lic.plan,licenseExpiresAt:millis(lic.expires_at),serverTime:Date.now(),features:parseJson(lic.features_json,[]),businessTypes:parseJson(lic.business_types_json,['*'])});
  }
  if((r==='sync/push'||r==='cloud-sync/push')&&method==='POST') {
    const c=await requireAuth(req,env), x=await readBody(req), isCloud=r.startsWith('cloud-sync');
    const items=isCloud?(x.items||[]):(x.changes||[]); if(!Array.isArray(items)||items.length>(isCloud?5000:2000))return err(400,'بسته همگام‌سازی نامعتبر است.');
    const stmts=[]; const storeId=sid(c), userId=uid(c);
    for(const it of items){const entity=String(it.entity||'').slice(0,120), entityId=String(it.entityId||'').slice(0,240),operation=String(it.operation||'UPSERT').toUpperCase(),payload=typeof it.payloadJson==='string'?it.payloadJson:JSON.stringify(it.payload??{}),version=Number(it.sourceVersion||0);
      if(!entity||!entityId||payload.length>500000)return err(400,'یکی از رکوردهای همگام‌سازی نامعتبر یا بیش‌ازحد بزرگ است.');
      if(isCloud){stmts.push(env.DB.prepare(`INSERT INTO cloud_records(store_id,user_id,entity,entity_id,operation,payload_json,source_version,updated_at) VALUES(?,?,?,?,?,?,?,?)
        ON CONFLICT(store_id,entity,entity_id) DO UPDATE SET user_id=excluded.user_id,operation=excluded.operation,payload_json=excluded.payload_json,source_version=excluded.source_version,updated_at=excluded.updated_at
        WHERE excluded.source_version>cloud_records.source_version`).bind(storeId,userId,entity,entityId,operation,payload,version,nowIso()));}
      else {stmts.push(env.DB.prepare('INSERT INTO sync_changes(store_id,user_id,entity,operation,entity_id,payload_json) VALUES(?,?,?,?,?,?)').bind(storeId,userId,entity,operation,entityId,payload));}
    }
    if(stmts.length) await env.DB.batch(stmts);
    for(const it of items){const entity=String(it.entity||'').toLowerCase(),entityId=String(it.entityId||''),op=String(it.operation||'UPSERT').toUpperCase(),payload=parseJson(typeof it.payloadJson==='string'?it.payloadJson:JSON.stringify(it.payload??{}),{});
      if(op==='DELETE')continue;
      const isSale=['transactions','store_transactions','sales','invoices','sale'].includes(entity) && String(payload.type||'').toUpperCase()==='SALE';
      const isEvent=entity==='notification_events';
      if(isSale) await putNotification(env,{storeId:sid(c),eventType:'sale_created',title:'فروش جدید همگام‌سازی شد',message:`فروش ${entityId} از یک دستگاه فروشگاه همگام‌سازی شد.`,metadata:{entity,entityId},dedupeKey:`sale:${sid(c)}:${entity}:${entityId}`});
      else if(isEvent&&['sale_created','receipt_printed','invoice_printed','sync_completed','support_opened'].includes(payload.eventType)) await putNotification(env,{storeId:sid(c),eventType:payload.eventType,title:String(payload.title||payload.eventType),message:String(payload.message||payload.title||payload.eventType),metadata:payload,dedupeKey:`client-event:${sid(c)}:${entityId}`});
    }
    if(isCloud)return json({success:true,accepted:items.length,serverTime:Date.now()});
    const last=await env.DB.prepare('SELECT COALESCE(MAX(id),0) AS cursor FROM sync_changes WHERE store_id=?').bind(storeId).first(); return json({success:true,accepted:items.length,lastCursor:last.cursor});
  }
  if(r==='cloud-sync/snapshot'&&method==='GET') {
    const c=await requireAuth(req,env),rows=await env.DB.prepare('SELECT * FROM cloud_records WHERE store_id=? ORDER BY id').bind(sid(c)).all();
    return json({items:rows.results.map(x=>({id:x.id,entity:x.entity,entityId:x.entity_id,operation:x.operation,payload:parseJson(x.payload_json,{}),version:x.source_version,updatedAt:millis(x.updated_at)})),serverTime:Date.now()});
  }
  if(r==='sync/pull'&&method==='GET') {
    const c=await requireAuth(req,env),cursor=Math.max(0,Number(url.searchParams.get('cursor')||0)),rows=await env.DB.prepare('SELECT * FROM sync_changes WHERE store_id=? AND id>? ORDER BY id LIMIT 500').bind(sid(c),cursor).all();
    const items=rows.results.map(x=>({id:x.id,entity:x.entity,operation:x.operation,entityId:x.entity_id,payload:x.payload_json})); return json({items,lastCursor:items.length?items[items.length-1].id:cursor});
  }
  if(r==='users'&&method==='GET') {
    const c=await requireAuth(req,env), perms=await permissionsFor(env,sid(c),uid(c)); if(!perms.permissions.includes('users.manage'))return err(403,'دسترسی کافی نیست.');
    const rows=await env.DB.prepare('SELECT u.id,u.name,u.phone,u.username,su.role,su.permissions_json,su.active FROM store_users su JOIN users u ON u.id=su.user_id WHERE su.store_id=? ORDER BY u.id').bind(sid(c)).all();
    return json({items:rows.results.map(x=>({id:x.id,name:x.name,phone:x.phone,username:x.username,role:x.role,permissions:parseJson(x.permissions_json,[]),active:!!x.active}))});
  }
  if(r==='users'&&method==='POST') {
    const c=await requireAuth(req,env), x=await readBody(req), perms=await permissionsFor(env,sid(c),uid(c)); if(!perms.permissions.includes('users.manage'))return err(403,'دسترسی کافی نیست.');
    if(String(x.pin||'').length<4)return err(400,'PIN حداقل ۴ نویسه است.');
    const lic=await env.DB.prepare("SELECT max_users FROM licenses WHERE store_id=? AND status='ACTIVE' AND expires_at>? ORDER BY expires_at DESC LIMIT 1").bind(sid(c),nowIso()).first();
    if(lic){const n=await env.DB.prepare('SELECT COUNT(*) AS n FROM store_users WHERE store_id=? AND active=1').bind(sid(c)).first();if(n.n>=lic.max_users)return err(400,'سقف کاربران این لایسنس تکمیل شده است');}
    const username=String(x.username||`user-${randomReadable(8)}`),ur=await env.DB.prepare('INSERT INTO users(username,name,phone,pin_hash) VALUES(?,?,?,?)').bind(username,String(x.name||''),String(x.phone||''),await bcrypt.hash(String(x.pin),10)).run();
    await env.DB.prepare('INSERT INTO store_users(store_id,user_id,role,permissions_json,active) VALUES(?,?,?,?,?)').bind(sid(c),ur.meta.last_row_id,String(x.role||'SELLER'),JSON.stringify(x.permissions||[]),x.active===false?0:1).run(); return json({id:ur.meta.last_row_id,success:true});
  }
  if(route[0]==='users'&&route.length===2&&(method==='PUT'||method==='DELETE')) {
    const c=await requireAuth(req,env), id=Number(route[1]), perms=await permissionsFor(env,sid(c),uid(c)); if(!perms.permissions.includes('users.manage'))return err(403,'دسترسی کافی نیست.');
    if(method==='DELETE'){if(id===uid(c))return err(400,'حساب جاری قابل حذف نیست');await env.DB.prepare('UPDATE store_users SET active=0 WHERE store_id=? AND user_id=?').bind(sid(c),id).run();return json({success:true});}
    const x=await readBody(req); const user=await env.DB.prepare('SELECT id FROM users WHERE id=?').bind(id).first(); const su=await env.DB.prepare('SELECT id FROM store_users WHERE store_id=? AND user_id=?').bind(sid(c),id).first(); if(!user||!su)return err(404,'کاربر پیدا نشد.');
    const statements=[env.DB.prepare('UPDATE users SET name=?,phone=? WHERE id=?').bind(String(x.name||''),String(x.phone||''),id),env.DB.prepare('UPDATE store_users SET role=?,permissions_json=?,active=? WHERE store_id=? AND user_id=?').bind(String(x.role||'SELLER'),JSON.stringify(x.permissions||[]),x.active===false?0:1,sid(c),id)];
    if(String(x.pin||'').trim())statements.push(env.DB.prepare('UPDATE users SET pin_hash=? WHERE id=?').bind(await bcrypt.hash(String(x.pin),10),id)); await env.DB.batch(statements); return json({success:true});
  }
  if(r==='support/tickets'&&method==='POST') {
    const x=await readBody(req),message=String(x.message||'').trim(); if(!message||message.length>5000)return err(400,'متن درخواست الزامی است و باید حداکثر ۵۰۰۰ نویسه باشد.');
    const ticketCode=`SMT-${randomReadable(12)}`, token=randomToken(32), type=String(x.type||'SUPPORT').toUpperCase().slice(0,40), created=nowIso();
    const t=await env.DB.prepare(`INSERT INTO support_tickets(ticket_code,type,store_code,license_id,username,device_id,contact,message,status,access_token_hash,created_at)
      VALUES(?,?,?,?,?,?,?,?,?,?,?)`).bind(ticketCode,type,String(x.storeCode||'').slice(0,100),String(x.licenseId||'').slice(0,100),String(x.username||'کاربر').slice(0,100),String(x.deviceId||'').slice(0,150),String(x.contact||'').slice(0,150),message,'OPEN',await sha256(token),created).run();
    await env.DB.prepare('INSERT INTO support_messages(ticket_id,sender_role,sender_name,message,created_at) VALUES(?,?,?,?,?)').bind(t.meta.last_row_id,'CUSTOMER',String(x.username||'کاربر'),message,created).run();
    return json({success:true,ticketCode,accessKey:token,ticket: {ticketCode,type,status:'OPEN',createdAt:Date.parse(created)}});
  }
  if(route[0]==='support'&&route[1]==='tickets'&&route[2]&&route[3]==='messages'&&method==='GET') {
    const t=await ticketForAccess(env,route[2],req), after=Number(url.searchParams.get('afterId')||0), rows=await env.DB.prepare('SELECT * FROM support_messages WHERE ticket_id=? AND id>? ORDER BY id LIMIT 500').bind(t.id,after).all();
    const items=rows.results.map(x=>({id:x.id,senderRole:x.sender_role,senderName:x.sender_name,message:x.message,createdAt:millis(x.created_at)}));
    return json({ticketCode:t.ticket_code,status:t.status,ticket:ticketRow(t),items,lastId:items.length?items[items.length-1].id:after});
  }
  if(route[0]==='support'&&route[1]==='tickets'&&route[2]&&route[3]==='messages'&&method==='POST') {
    const t=await ticketForAccess(env,route[2],req),x=await readBody(req),message=String(x.message||'').trim(); if(!message||message.length>5000)return err(400,'متن پیام نامعتبر است.');
    if(String(t.status).toUpperCase()==='CLOSED')return err(409,'این تیکت بسته شده است.');
    const result=await env.DB.prepare('INSERT INTO support_messages(ticket_id,sender_role,sender_name,message) VALUES(?,?,?,?)').bind(t.id,'CUSTOMER',t.username,message).run();
    await env.DB.prepare("UPDATE support_tickets SET status='WAITING_ADMIN' WHERE id=?").bind(t.id).run(); return json({success:true,id:result.meta.last_row_id});
  }
  if(r==='support/tickets'&&method==='GET') {
    const c=await requireAuth(req,env); const store=await env.DB.prepare('SELECT code FROM stores WHERE id=?').bind(sid(c)).first(); const rows=await env.DB.prepare('SELECT * FROM support_tickets WHERE store_code=? ORDER BY id DESC LIMIT 100').bind(store?.code||'').all(); return json({items:rows.results.map(ticketRow)});
  }
  if(r==='invoices/share'&&method==='POST') {
    const c=await requireAuth(req,env),x=await readBody(req),store=await env.DB.prepare('SELECT * FROM stores WHERE id=?').bind(sid(c)).first(); const token=randomToken(24),expiry=new Date(Date.now()+7*86400000).toISOString();
    await env.DB.prepare(`INSERT INTO invoice_shares(token,store_id,store_name,store_phone,invoice_number,date_text,customer_name,currency,items_json,total_amount,discount,final_amount,paid_amount,debt_amount,expires_at)
      VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`).bind(token,sid(c),store?.name||'',String(x.storePhone||''),String(x.invoiceNumber||''),String(x.dateText||''),String(x.customerName||''),String(x.currency||'تومان'),JSON.stringify(x.items||[]),Number(x.totalAmount||0),Number(x.discount||0),Number(x.finalAmount||0),Number(x.paidAmount||0),Number(x.debtAmount||0),expiry).run();
    return json({success:true,token,url:`${url.origin}/api/v1/invoices/public/${token}`,expiresAt:Date.parse(expiry)});
  }
  if(route[0]==='invoices'&&route[1]==='public'&&route[2]&&method==='GET') {
    const inv=await env.DB.prepare('SELECT * FROM invoice_shares WHERE token=? AND expires_at>?').bind(route[2],nowIso()).first(); if(!inv)return err(404,'فاکتور پیدا نشد یا لینک آن منقضی شده است.');
    return json({storeName:inv.store_name,storePhone:inv.store_phone,invoiceNumber:inv.invoice_number,dateText:inv.date_text,customerName:inv.customer_name,currency:inv.currency,items:parseJson(inv.items_json,[]),totalAmount:inv.total_amount,discount:inv.discount,finalAmount:inv.final_amount,paidAmount:inv.paid_amount,debtAmount:inv.debt_amount,expiresAt:millis(inv.expires_at)});
  }
  if(r==='notifications'&&method==='GET') {
    const c=await requireAuth(req,env),after=Math.max(0,Number(url.searchParams.get('afterId')||0)),take=Math.max(1,Math.min(100,Number(url.searchParams.get('take')||50)));
    const desc=after<=0; const rows=await env.DB.prepare(`SELECT n.*,CASE WHEN nr.notification_id IS NULL THEN 0 ELSE 1 END AS is_read FROM notifications n LEFT JOIN notification_receipts nr ON nr.notification_id=n.id AND nr.user_id=? WHERE (n.store_id IS NULL OR n.store_id=?) AND (?=0 OR n.id>?) ORDER BY n.id ${desc?'DESC':'ASC'} LIMIT ?`).bind(uid(c),sid(c),after,after,take).all();
    const results=desc?rows.results.reverse():rows.results;return json({items:results.map(n=>({id:n.id,eventType:n.event_type,title:n.title,message:n.message,metadata:parseJson(n.metadata_json,{}),createdAt:millis(n.created_at),isRead:!!n.is_read})),lastId:results.reduce((m,n)=>Math.max(m,n.id),after)});
  }
  if(r==='notifications/unread-count'&&method==='GET') {const c=await requireAuth(req,env),row=await env.DB.prepare('SELECT COUNT(*) AS count FROM notifications n LEFT JOIN notification_receipts nr ON nr.notification_id=n.id AND nr.user_id=? WHERE (n.store_id IS NULL OR n.store_id=?) AND nr.notification_id IS NULL').bind(uid(c),sid(c)).first();return json({count:row.count});}
  if(route[0]==='notifications'&&route[1]&&route[2]==='read'&&method==='POST') {const c=await requireAuth(req,env);await env.DB.prepare('INSERT OR IGNORE INTO notification_receipts(notification_id,user_id) SELECT id,? FROM notifications WHERE id=? AND (store_id IS NULL OR store_id=?)').bind(uid(c),Number(route[1]),sid(c)).run();return json({success:true});}
  if(r==='notifications/events'&&method==='POST') {const c=await requireAuth(req,env),x=await readBody(req),type=String(x.eventType||'').toLowerCase();if(!['sale_created','receipt_printed','invoice_printed','sync_completed','support_opened'].includes(type))return err(400,'نوع رویداد مجاز نیست.');await putNotification(env,{storeId:sid(c),eventType:type,title:String(x.title||type),message:String(x.message||x.title||type),metadata:{entityId:x.entityId,platform:x.platform},dedupeKey:x.eventId?`client-event:${sid(c)}:${x.eventId}`:null});return json({success:true});}
  if(r==='notifications/admin/publish'&&method==='POST') {await requireAdmin(req,env);const x=await readBody(req);if(!x.title||!x.message)return err(400,'عنوان و متن اعلان الزامی است.');await putNotification(env,{storeId:Number(x.storeId)||null,eventType:String(x.eventType||'admin_message'),title:String(x.title),message:String(x.message),metadata:parseJson(x.metadataJson||'{}',{})});return json({success:true});}
  // Admin area: protected by an account-level Cloudflare Worker secret, not a user JWT.
  if(r==='admin/trial-policy'&&method==='GET') {await requireAdmin(req,env);const p=await env.DB.prepare('SELECT * FROM trial_policy WHERE id=1').first();return json({durationDays:Number(env.TRIAL_DAYS||15),features:parseJson(p?.features_json,DEFAULT_FEATURES),businessTypes:parseJson(p?.business_types_json,DEFAULT_BUSINESSES),updatedAt:p?.updated_at||nowIso()});}
  if(r==='admin/trial-policy'&&method==='PUT') {await requireAdmin(req,env);const x=await readBody(req);if(!Array.isArray(x.features)||!x.features.length||!Array.isArray(x.businessTypes)||!x.businessTypes.length)return err(400,'حداقل یک قابلیت و یک نوع کسب‌وکار انتخاب کنید.');const known=new Set(['sales','products','inventory','customers','accounting','reports','business_modules','attendance','multi_warehouse','sms','advanced_reports']);const features=[...new Set(x.features.map(v=>String(v).trim().toLowerCase()))];const businesses=[...new Set(x.businessTypes.map(v=>String(v).trim().toUpperCase()))];if(features.some(v=>!known.has(v)))return err(400,'کد قابلیت نامعتبر است.');await env.DB.prepare('INSERT INTO trial_policy(id,features_json,business_types_json,updated_at) VALUES(1,?,?,?) ON CONFLICT(id) DO UPDATE SET features_json=excluded.features_json,business_types_json=excluded.business_types_json,updated_at=excluded.updated_at').bind(JSON.stringify(features),JSON.stringify(businesses),nowIso()).run();return json({success:true,durationDays:Number(env.TRIAL_DAYS||15),features,businessTypes:businesses,updatedAt:nowIso()});}
  if(r==='admin/stores'&&method==='GET') {await requireAdmin(req,env);const rows=await env.DB.prepare('SELECT s.*,l.license_id,l.status AS license_status,l.plan,l.expires_at FROM stores s LEFT JOIN licenses l ON l.store_id=s.id ORDER BY s.id DESC').all();return json({items:rows.results});}
  if(r==='admin/stores/provision'&&method==='POST') return adminProvision(req,env);
  if(r==='admin/roles'&&method==='GET') {await requireAdmin(req,env);return json({roles:['OWNER','ADMIN','MANAGER','SELLER','WAREHOUSE','ACCOUNTANT','CASHIER','CUSTOM'],permissions:['dashboard.view','sales.create','sales.edit','sales.delete','sales.refund','customers.view','customers.manage','products.view','products.manage','inventory.view','inventory.manage','reports.view','reports.advanced','accounting.expenses','accounting.manage','attendance.manage','attendance.shifts','users.manage','roles.manage','store.manage','warehouses.manage','audit.view','settings.manage','business.modules']});}
  if(r==='admin/licenses/by-device'&&method==='POST') return licenseCreateByDevice(req,env);
  if(r==='admin/licenses'&&method==='POST') {await requireAdmin(req,env);const x=await readBody(req);const store=await env.DB.prepare('SELECT * FROM stores WHERE code=?').bind(String(x.storeCode||'')).first();if(!store)return err(404,'فروشگاه پیدا نشد');const days=Number(x.durationDays||0);if(days<=0)return err(400,'مدت لایسنس نامعتبر است');const licenseId=String(x.licenseId||`LIC-${randomReadable(16)}`).toUpperCase(),activation=String(x.activationCode||randomReadable(18)).toUpperCase(),expiry=new Date(Date.now()+days*86400000).toISOString();await env.DB.prepare(`INSERT INTO licenses(store_id,license_id,activation_code,plan,status,expires_at,original_price,final_price,discount_code,features_json,business_types_json,max_users,username,initial_password,recovery_code) VALUES(?,?,?,?,'ACTIVE',?,?,?,?,?,?,?,?,?,?)`).bind(store.id,licenseId,activation,String(x.plan||'STANDARD'),expiry,Number(x.originalPrice||0),Number(x.finalPrice||0),String(x.discountCode||''),JSON.stringify(x.features||DEFAULT_FEATURES),JSON.stringify(x.businessTypes||['*']),Number(x.maxUsers||5),String(x.username||'admin'),String(x.initialPassword||''),String(x.recoveryCode||'')).run();return json({success:true,licenseId,activationCode:activation,expiresAt:Date.parse(expiry)});}
  if(route[0]==='admin'&&route[1]==='licenses'&&route[2]&&route[3]==='status'&&method==='PATCH') {await requireAdmin(req,env);const x=await readBody(req),status=String(x.status||'').toUpperCase();if(!['ACTIVE','SUSPENDED','CANCELLED','RENEWED','REVOKED','EXPIRED','DELETED'].includes(status))return err(400,'وضعیت لایسنس نامعتبر است.');const res=await env.DB.prepare('UPDATE licenses SET status=? WHERE license_id=?').bind(status,route[2]).run();return res.meta.changes?json({success:true,status}):err(404,'لایسنس پیدا نشد.');}
  if(r==='admin/discounts'&&method==='POST') {await requireAdmin(req,env);const x=await readBody(req);await env.DB.prepare('INSERT INTO discounts(code,percent,fixed_amount,max_uses,expires_at,active) VALUES(?,?,?,?,?,1) ON CONFLICT(code) DO UPDATE SET percent=excluded.percent,fixed_amount=excluded.fixed_amount,max_uses=excluded.max_uses,expires_at=excluded.expires_at,active=1').bind(String(x.code||'').toUpperCase(),Number(x.percent||0),Number(x.fixedAmount||0),Number(x.maxUses||0),x.expiresAt||null).run();return json({success:true});}
  if(r==='admin/discounts'&&method==='GET') {await requireAdmin(req,env);const rows=await env.DB.prepare('SELECT * FROM discounts ORDER BY id DESC').all();return json({items:rows.results});}
  if(r==='admin/discounts/quote'&&method==='POST') {await requireAdmin(req,env);const x=await readBody(req),code=String(x.code||'').toUpperCase(),d=await env.DB.prepare('SELECT * FROM discounts WHERE code=? AND active=1').bind(code).first();if(!d)return err(404,'کد تخفیف معتبر نیست.');if(d.expires_at&&Date.parse(d.expires_at)<Date.now())return err(400,'کد تخفیف منقضی شده است.');if(d.max_uses>0&&d.used_count>=d.max_uses)return err(400,'ظرفیت استفاده از کد تخفیف تمام شده است.');const original=Math.max(0,Number(x.originalPrice||0)),discount=Math.min(original,Math.max(original*d.percent/100,d.fixed_amount));return json({code,originalPrice:original,discount,finalPrice:Math.max(0,original-discount),percent:d.percent,fixedAmount:d.fixed_amount});}
  if(r==='admin/pricing'&&method==='PUT') {await requireAdmin(req,env);const x=await readBody(req),prices=x.prices||{};const stmts=Object.entries(prices).map(([days,price])=>env.DB.prepare('INSERT INTO pricing_entries(plan_days,price,currency,updated_at) VALUES(?,?,?,?) ON CONFLICT(plan_days) DO UPDATE SET price=excluded.price,currency=excluded.currency,updated_at=excluded.updated_at').bind(Number(days),Number(price),String(x.currency||'تومان'),nowIso()));if(stmts.length)await env.DB.batch(stmts);return json({success:true,prices,currency:String(x.currency||'تومان')});}
  if(r==='admin/support/tickets'&&method==='GET') {await requireAdmin(req,env);const rows=await env.DB.prepare('SELECT * FROM support_tickets ORDER BY id DESC LIMIT 500').all();return json({items:rows.results.map(ticketRow)});}
  if(route[0]==='admin'&&route[1]==='support'&&route[2]==='tickets'&&route[3]&&route[4]==='messages'&&method==='GET') {await requireAdmin(req,env);const t=await env.DB.prepare('SELECT * FROM support_tickets WHERE ticket_code=?').bind(route[3]).first();if(!t)return err(404,'تیکت پیدا نشد');const after=Number(url.searchParams.get('afterId')||0),rows=await env.DB.prepare('SELECT * FROM support_messages WHERE ticket_id=? AND id>? ORDER BY id LIMIT 500').bind(t.id,after).all();const items=rows.results.map(m=>({id:m.id,senderRole:m.sender_role,senderName:m.sender_name,message:m.message,createdAt:millis(m.created_at)}));return json({ticketCode:t.ticket_code,status:t.status,items,lastId:items.length?items[items.length-1].id:after});}
  if(route[0]==='admin'&&route[1]==='support'&&route[2]==='tickets'&&route[3]&&route[4]==='messages'&&method==='POST') {await requireAdmin(req,env);const t=await env.DB.prepare('SELECT * FROM support_tickets WHERE ticket_code=?').bind(route[3]).first(),x=await readBody(req);if(!t)return err(404,'تیکت پیدا نشد');if(String(t.status).toUpperCase()==='CLOSED')return err(409,'تیکت بسته شده است.');const msg=String(x.message||'').trim();if(!msg||msg.length>5000)return err(400,'متن پیام الزامی است.');const m=await env.DB.prepare('INSERT INTO support_messages(ticket_id,sender_role,sender_name,message) VALUES(?,?,?,?)').bind(t.id,'ADMIN','پشتیبانی StoreMaster',msg).run();await env.DB.prepare("UPDATE support_tickets SET status='WAITING_CUSTOMER' WHERE id=?").bind(t.id).run();const store=await env.DB.prepare('SELECT id FROM stores WHERE code=? LIMIT 1').bind(t.store_code).first();if(store)await putNotification(env,{storeId:store.id,eventType:'ticket_reply',title:'پاسخ جدید پشتیبانی',message:`برای تیکت ${t.ticket_code} پاسخ جدید ثبت شد.`,metadata:{ticketCode:t.ticket_code}});return json({success:true,id:m.meta.last_row_id});}
  if(route[0]==='admin'&&route[1]==='support'&&route[2]==='tickets'&&route[3]&&route[4]==='status'&&method==='PATCH') {await requireAdmin(req,env);const x=await readBody(req),status=String(x.status||'OPEN').toUpperCase();if(!['OPEN','WAITING_ADMIN','WAITING_CUSTOMER','CLOSED'].includes(status))return err(400,'وضعیت تیکت نامعتبر است.');const t=await env.DB.prepare('SELECT * FROM support_tickets WHERE ticket_code=?').bind(route[3]).first();if(!t)return err(404,'تیکت پیدا نشد.');await env.DB.prepare('UPDATE support_tickets SET status=? WHERE ticket_code=?').bind(status,route[3]).run();const store=await env.DB.prepare('SELECT id FROM stores WHERE code=? LIMIT 1').bind(t.store_code).first();if(store)await putNotification(env,{storeId:store.id,eventType:status==='CLOSED'?'ticket_closed':'ticket_status_changed',title:status==='CLOSED'?'تیکت بسته شد':'وضعیت تیکت تغییر کرد',message:`وضعیت تیکت ${t.ticket_code} به ${status} تغییر کرد.`,metadata:{ticketCode:t.ticket_code,status}});return json({success:true,status});}
  if(route[0]==='files' && route.length>=2 && ['GET','POST','PUT','DELETE'].includes(method)) {
    const c=await requireAuth(req,env);
    const key=route.slice(1).join('/').replaceAll('..','').replace(/^\/+/, '').slice(0,900);
    if(!key||!env.FILES)return err(503,'فضای ذخیره‌سازی فایل تنظیم نشده است.');
    const scopedKey=`stores/${sid(c)}/${key}`;
    if(method==='POST'||method==='PUT'){
      const type=req.headers.get('content-type')||'application/octet-stream';
      const obj=await env.FILES.put(scopedKey,req.body,{httpMetadata:{contentType:type},customMetadata:{storeId:String(sid(c)),userId:String(uid(c)),createdAt:nowIso()}});
      return json({success:true,key,etag:obj.etag,size:obj.size});
    }
    if(method==='GET'){
      const obj=await env.FILES.get(scopedKey);if(!obj)return err(404,'فایل پیدا نشد.');
      return new Response(obj.body,{status:200,headers:{'content-type':obj.httpMetadata?.contentType||'application/octet-stream','cache-control':'private, no-store','etag':obj.httpEtag}});
    }
    await env.FILES.delete(scopedKey);return json({success:true});
  }
  return err(404,`مسیر پشتیبانی نمی‌شود: ${method} /api/v1/${r}`);
}

export default {
  async fetch(req, env) {
    const cors=headersCors(req);
    try {
      const response=await handle(req,env);
      const headers=new Headers(response.headers); for(const [k,v] of Object.entries(cors))headers.set(k,v);
      return new Response(response.body,{status:response.status,statusText:response.statusText,headers});
    } catch (e) {
      const status=Number(e?.status)||500;
      if(status>=500) console.error('StoreMaster API error',e?.stack||String(e));
      const message=status>=500?'خطای داخلی سرور.':(e?.message||'درخواست نامعتبر است.');
      return json({message},status,cors);
    }
  }
};
