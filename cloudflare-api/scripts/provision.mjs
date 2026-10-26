import fs from 'node:fs/promises';
import path from 'node:path';

const account = process.env.CLOUDFLARE_ACCOUNT_ID;
const token = process.env.CLOUDFLARE_API_TOKEN;
const configPath = path.resolve('wrangler.toml');
if (!account || !token) {
  throw new Error('CLOUDFLARE_ACCOUNT_ID و CLOUDFLARE_API_TOKEN باید به‌صورت Secret تنظیم شوند.');
}

async function api(method, endpoint, body) {
  const response = await fetch(`https://api.cloudflare.com/client/v4${endpoint}`, {
    method,
    headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
    ...(body ? { body: JSON.stringify(body) } : {})
  });
  const result = await response.json().catch(() => ({}));
  if (!response.ok || result.success === false) {
    const messages = (result.errors || []).map(x => x.message).join('; ');
    const codes = (result.errors || []).map(x => x.code).filter(Boolean).join(',');
    throw new Error(`Cloudflare API ${method} ${endpoint} failed (${response.status})${codes ? ` [${codes}]` : ''}: ${messages || response.statusText}`);
  }
  return result.result;
}

function isR2NotEnabled(error) {
  return /please enable R2 through the Cloudflare Dashboard/i.test(String(error?.message || error));
}

const dbName = 'storemaster-prod';
let databases = await api('GET', `/accounts/${account}/d1/database?name=${encodeURIComponent(dbName)}`);
if (!Array.isArray(databases)) databases = databases?.result || [];
let database = databases.find(x => x.name === dbName);
if (!database) {
  database = await api('POST', `/accounts/${account}/d1/database`, { name: dbName });
  console.log(`Created D1 database: ${database.name}`);
} else console.log(`Using existing D1 database: ${database.name}`);
if (!database.uuid) throw new Error('Cloudflare D1 did not return a database UUID.');

const bucketName = 'storemaster-files';
let r2Enabled = true;
try {
  const bucketResponse = await api('GET', `/accounts/${account}/r2/buckets`);
  const buckets = Array.isArray(bucketResponse) ? bucketResponse : (bucketResponse?.buckets || bucketResponse?.result || []);
  if (!buckets.some(x => x.name === bucketName)) {
    await api('POST', `/accounts/${account}/r2/buckets`, { name: bucketName });
    console.log(`Created R2 bucket: ${bucketName}`);
  } else console.log(`Using existing R2 bucket: ${bucketName}`);
} catch (error) {
  // R2 activation is an account-level step in the Cloudflare Dashboard. Do not
  // let that optional object-storage feature block the D1-backed API deployment.
  // Other errors (for example a missing permission) should still fail loudly.
  if (!isR2NotEnabled(error)) throw error;
  r2Enabled = false;
  console.warn('R2 is not enabled for this Cloudflare account; continuing without R2.');
  console.warn('The D1 database and API can still be deployed. File endpoints will return HTTP 503 until R2 is enabled.');
  console.warn('Enable R2 in Cloudflare Dashboard > R2 Object Storage, then rerun this workflow to enable file storage.');
}

let config = await fs.readFile(configPath, 'utf8');
config = config.replace(/database_id\s*=\s*"[^"]*"/, `database_id = "${database.uuid}"`);

const r2BindingBlock = /\n?\[\[r2_buckets\]\]\s*\nbinding\s*=\s*"FILES"\s*\nbucket_name\s*=\s*"storemaster-files"\s*\n?/m;
if (r2Enabled) {
  if (!r2BindingBlock.test(config)) {
    config = config.trimEnd() + '\n\n[[r2_buckets]]\nbinding = "FILES"\nbucket_name = "storemaster-files"\n';
  }
  console.log('R2 is enabled; keeping the FILES binding in wrangler.toml.');
} else {
  config = config.replace(r2BindingBlock, '\n');
  console.log('Removed the optional FILES binding for this deploy because R2 is not enabled.');
}
await fs.writeFile(configPath, config, 'utf8');
console.log('Updated wrangler.toml with the production D1 ID.');
