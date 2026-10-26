import fs from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import { execFileSync } from 'node:child_process';

const input = process.argv[2] || 'storemaster-postgres-export.json';
// Refresh the local Wrangler config with the production D1 ID; no DB URL is needed after one-time export.
execFileSync(process.execPath, [path.resolve('scripts/provision.mjs')], { stdio: 'inherit' });
const doc = JSON.parse(await fs.readFile(input, 'utf8'));
if (doc.format !== 'storemaster-postgres-export-v1' || !doc.tables) throw new Error('فایل خروجی PostgreSQL قالب شناخته‌شدهٔ Store Master را ندارد.');
const maps = [
  ['Stores','stores',[['id','Id'],['code','Code'],['name','Name'],['type','Type'],['business_title','BusinessTitle'],['currency','Currency'],['active','Active'],['created_at','CreatedAt']]],
  ['Users','users',[['id','Id'],['username','Username'],['name','Name'],['phone','Phone'],['pin_hash','PinHash'],['active','Active'],['created_at','CreatedAt']]],
  ['StoreUsers','store_users',[['id','Id'],['store_id','StoreId'],['user_id','UserId'],['role','Role'],['permissions_json','PermissionsJson'],['active','Active']]],
  ['UserDevices','user_devices',[['id','Id'],['store_id','StoreId'],['user_id','UserId'],['device_id','DeviceId'],['platform','Platform'],['name','Name'],['first_seen_at','FirstSeenAt'],['last_seen_at','LastSeenAt'],['active','Active']]],
  ['Licenses','licenses',[['id','Id'],['store_id','StoreId'],['license_id','LicenseId'],['activation_code','ActivationCode'],['activation_code_used','ActivationCodeUsed'],['plan','Plan'],['status','Status'],['issued_at','IssuedAt'],['expires_at','ExpiresAt'],['original_price','OriginalPrice'],['final_price','FinalPrice'],['discount_code','DiscountCode'],['features_json','FeaturesJson'],['business_types_json','BusinessTypesJson'],['max_users','MaxUsers'],['username','Username'],['initial_password','InitialPassword'],['recovery_code','RecoveryCode']]],
  ['DiscountCodes','discounts',[['id','Id'],['code','Code'],['percent','Percent'],['fixed_amount','FixedAmount'],['max_uses','MaxUses'],['used_count','UsedCount'],['expires_at','ExpiresAt'],['active','Active']]],
  ['SyncChanges','sync_changes',[['id','Id'],['store_id','StoreId'],['user_id','UserId'],['entity','Entity'],['operation','Operation'],['entity_id','EntityId'],['payload_json','PayloadJson'],['created_at','CreatedAt']]],
  ['CloudRecords','cloud_records',[['id','Id'],['store_id','StoreId'],['user_id','UserId'],['entity','Entity'],['entity_id','EntityId'],['operation','Operation'],['payload_json','PayloadJson'],['source_version','SourceVersion'],['updated_at','UpdatedAt']]],
  ['PricingEntries','pricing_entries',[['id','Id'],['plan_days','PlanDays'],['price','Price'],['currency','Currency'],['updated_at','UpdatedAt']]],
  ['TrialPolicies','trial_policy',[['id','Id'],['features_json','FeaturesJson'],['business_types_json','BusinessTypesJson'],['updated_at','UpdatedAt']]],
  ['SupportTickets','support_tickets',[['id','Id'],['ticket_code','TicketCode'],['type','Type'],['store_code','StoreCode'],['license_id','LicenseId'],['username','Username'],['device_id','DeviceId'],['contact','Contact'],['message','Message'],['status','Status'],['access_token_hash','AccessTokenHash'],['created_at','CreatedAt']]],
  ['SupportMessages','support_messages',[['id','Id'],['ticket_id','TicketId'],['sender_role','SenderRole'],['sender_name','SenderName'],['message','Message'],['created_at','CreatedAt']]],
  ['InvoiceShares','invoice_shares',[['id','Id'],['token','Token'],['store_id','StoreId'],['store_name','StoreName'],['store_phone','StorePhone'],['invoice_number','InvoiceNumber'],['date_text','DateText'],['customer_name','CustomerName'],['currency','Currency'],['items_json','ItemsJson'],['total_amount','TotalAmount'],['discount','Discount'],['final_amount','FinalAmount'],['paid_amount','PaidAmount'],['debt_amount','DebtAmount'],['created_at','CreatedAt'],['expires_at','ExpiresAt']]],
  ['AppNotifications','notifications',[['id','Id'],['store_id','StoreId'],['event_type','EventType'],['title','Title'],['message','Message'],['metadata_json','MetadataJson'],['dedupe_key','DeduplicationKey'],['created_at','CreatedAt']]],
  ['AppNotificationReceipts','notification_receipts',[['notification_id','NotificationId'],['user_id','UserId'],['read_at','ReadAt']]],
];
function get(row,key){ if(Object.hasOwn(row,key))return row[key];const lower=key.toLowerCase();const found=Object.keys(row).find(k=>k.toLowerCase()===lower);return found===undefined?null:row[found]; }
function literal(value){
  if(value===null||value===undefined)return 'NULL';
  if(typeof value==='boolean')return value?'1':'0';
  if(typeof value==='number')return Number.isFinite(value)?String(value):'NULL';
  if(value instanceof Date)value=value.toISOString();
  if(typeof value==='object')value=JSON.stringify(value);
  return `'${String(value).replaceAll("'","''")}'`;
}
const temp = await fs.mkdtemp(path.join(os.tmpdir(),'storemaster-d1-import-'));
const chunkSize=100; let files=0, rowsTotal=0;
try {
  for(const [source,dest,columns] of maps){
    const rows=doc.tables[source]||[]; if(!rows.length)continue;
    for(let offset=0;offset<rows.length;offset+=chunkSize){
      const chunk=rows.slice(offset,offset+chunkSize); const statements=chunk.map(row=>{
        const cols=columns.map(c=>c[0]); const values=columns.map(c=>literal(get(row,c[1])));
        return `INSERT OR REPLACE INTO "${dest}" (${cols.map(c=>`"${c}"`).join(',')}) VALUES (${values.join(',')});`;
      });
      const filename=path.join(temp,`${String(files).padStart(4,'0')}-${dest}.sql`); await fs.writeFile(filename,statements.join('\n'),'utf8');
      console.log(`Importing ${source}: ${Math.min(offset+chunkSize,rows.length)}/${rows.length}`);
      execFileSync(process.platform==='win32'?'npx.cmd':'npx',['wrangler','d1','execute','storemaster-prod','--remote','--file',filename,'--config','wrangler.toml'],{stdio:'inherit'});
      files++;rowsTotal+=chunk.length;
    }
  }
  console.log(`Imported ${rowsTotal} rows. Keep a private copy of the export until you verify the data.`);
} finally {
  await fs.rm(temp,{recursive:true,force:true});
}
