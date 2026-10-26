import fs from 'node:fs/promises';
import path from 'node:path';

const account = process.env.CLOUDFLARE_ACCOUNT_ID;
const token = process.env.CLOUDFLARE_API_TOKEN;
const configPath = path.resolve('wrangler.toml');
if (!account || !token) throw new Error('CLOUDFLARE_ACCOUNT_ID و CLOUDFLARE_API_TOKEN باید به‌صورت Secret تنظیم شوند.');

async function api(method, endpoint, body) {
  const response = await fetch(`https://api.cloudflare.com/client/v4${endpoint}`, {
    method,
    headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
    ...(body ? { body: JSON.stringify(body) } : {})
  });
  const result = await response.json().catch(() => ({}));
  if (!response.ok || result.success === false) {
    const messages = (result.errors || []).map(x => x.message).join('; ');
    throw new Error(`Cloudflare API ${method} ${endpoint} failed (${response.status}): ${messages || response.statusText}`);
  }
  return result.result;
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
const bucketResponse = await api('GET', `/accounts/${account}/r2/buckets`);
const buckets = Array.isArray(bucketResponse) ? bucketResponse : (bucketResponse?.buckets || bucketResponse?.result || []);
if (!buckets.some(x => x.name === bucketName)) {
  await api('POST', `/accounts/${account}/r2/buckets`, { name: bucketName });
  console.log(`Created R2 bucket: ${bucketName}`);
} else console.log(`Using existing R2 bucket: ${bucketName}`);

let config = await fs.readFile(configPath, 'utf8');
config = config.replace(/database_id\s*=\s*"[^"]*"/, `database_id = "${database.uuid}"`);
await fs.writeFile(configPath, config, 'utf8');
console.log('Updated wrangler.toml with the production D1 ID.');
