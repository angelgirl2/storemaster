import pg from 'pg';
import fs from 'node:fs/promises';

const { Pool } = pg;
const connectionString = process.env.SOURCE_DATABASE_URL || process.env.DATABASE_URL;
if (!connectionString) throw new Error('برای انتقال یک‌باره، SOURCE_DATABASE_URL را با رشتهٔ اتصال دیتابیس PostgreSQL فعلی تنظیم کن. این متغیر برای کار روزمرهٔ Cloudflare لازم نیست.');
const pool = new Pool({ connectionString, ssl: process.env.PGSSLMODE === 'disable' ? false : { rejectUnauthorized: false }, connectionTimeoutMillis: 15000 });
const tables = [
  ['Stores','Stores'], ['Users','Users'], ['StoreUsers','StoreUsers'], ['UserDevices','UserDevices'], ['Licenses','Licenses'],
  ['DiscountCodes','DiscountCodes'], ['SyncChanges','SyncChanges'], ['CloudRecords','CloudRecords'], ['PricingEntries','PricingEntries'],
  ['TrialPolicies','TrialPolicies'], ['SupportTickets','SupportTickets'], ['SupportMessages','SupportMessages'], ['InvoiceShares','InvoiceShares'],
  ['AppNotifications','AppNotifications'], ['AppNotificationReceipts','AppNotificationReceipts']
];
const exported = { format: 'storemaster-postgres-export-v1', exportedAt: new Date().toISOString(), tables: {} };
try {
  for (const [key, table] of tables) {
    try {
      const result = await pool.query(`SELECT * FROM "${table}" ORDER BY 1`);
      exported.tables[key] = result.rows;
      console.log(`${table}: ${result.rowCount} rows`);
    } catch (error) {
      if (['42P01','42703'].includes(error.code)) {
        console.warn(`${table}: not present in source database; skipped`);
        exported.tables[key] = [];
      } else throw error;
    }
  }
  await fs.writeFile('storemaster-postgres-export.json', JSON.stringify(exported), 'utf8');
  console.log('Created storemaster-postgres-export.json. Keep it private; it contains account/license information.');
} finally {
  await pool.end();
}
