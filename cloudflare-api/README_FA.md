# Store Master Pro — API اصلی روی Cloudflare

این سرویس یک API مستقل Cloudflare Workers است؛ API درخواست‌ها را اجرا می‌کند، Cloudflare D1 داده‌های ساختاریافته را نگه می‌دارد و R2 فضای خصوصی فایل‌ها/پشتیبان‌هاست. این مسیر **برای کارکرد جاری خود به Railway یا VPS متصل نیست**. پروژهٔ `server/` و مستندات Railway/VPS حفظ شده‌اند و فقط برای حالت اختیاری/قدیمی باقی می‌مانند.

> توجه مهم: این Worker جایگزین قابل‌اجرا برای مسیرهای اصلی برنامه است (ورود، شروع فروشگاه/تریال، اعتبارسنجی لایسنس، همگام‌سازی، کاربران، پشتیبانی، اشتراک فاکتور، اعلان‌ها و بخش‌های اصلی مدیریت). قبل از سوئیچ کردن همه کاربران، تست پذیرش با یک نسخه آزمایشی انجام بده. اگر مسیر دیگری از سرور قدیمی در یک صفحه یا نسخه قدیمی کلاینت استفاده شده باشد، Worker پاسخ 404 صریح می‌دهد؛ این پاسخ را پنهانی به پاسخ ساختگی تبدیل نمی‌کند.

## استقرار خودکار در GitHub Actions

### ۱) Secrets در GitHub

به مخزن برو: **Settings → Secrets and variables → Actions → New repository secret** و این موارد را اضافه کن:

- `CLOUDFLARE_API_TOKEN`: توکن محدود Cloudflare با دسترسی‌های Account: **Workers Scripts Edit**, **D1 Edit**, **R2 Edit**. از Global API Key استفاده نکن.
- `CLOUDFLARE_ACCOUNT_ID`: شناسهٔ Account مربوط به Cloudflare.
- `JWT_KEY`: رشتهٔ تصادفی محرمانه حداقل ۳۲ نویسه (پیشنهاد: ۶۴ نویسه یا بیشتر).
- `ADMIN_KEY`: رشتهٔ تصادفی جداگانه حداقل ۳۲ نویسه برای API مدیریت.

برای ساخت دو کلید در PowerShell ویندوز:

```powershell
-join (1..4 | ForEach-Object { [guid]::NewGuid().ToString('N') })
```

هر دو بار فرمان را جداگانه اجرا کن؛ یک مقدار را برای هر دو Secret استفاده نکن. کلیدها را در کد، issue یا پیام عمومی قرار نده.

### ۲) اولین deploy

پوشه‌ها و فایل‌های patch را در مسیر اصلی مخزن نگه دار و commit/push کن. Workflow زیر اجرا می‌شود:

`.github/workflows/deploy-cloudflare-api.yml`

Workflow به‌شکل idempotent این کارها را انجام می‌دهد:

1. بررسی نحوی JavaScript و اجرای تست‌ها؛
2. ساخت `storemaster-prod` در D1 و `storemaster-files` در R2 فقط در صورت نبودن؛
3. درج/به‌روزرسانی schema از `migrations/`؛
4. deploy کردن Worker با نام `storemaster-api`؛
5. تنظیم Secretهای runtime روی Worker.

توکن Cloudflare در مخزن ذخیره نمی‌شود؛ GitHub Actions آن را از Secrets می‌خواند.

پس از سبز شدن Workflow، در **Cloudflare Dashboard → Workers & Pages → storemaster-api → Settings/Domains & Routes** آدرس Worker را ببین. اگر `workers.dev` حساب فعال باشد، URL معمولاً به این شکل است:

`https://storemaster-api.<account-subdomain>.workers.dev`

`<account-subdomain>` را از داشبورد خودت کپی کن، حدس نزن. برای تست health باز کن:

`https://storemaster-api.<account-subdomain>.workers.dev/health`

### ۳) دامنهٔ اختصاصی

برای شروع نیازی به خرید دامنه نیست؛ می‌توان از `workers.dev` استفاده کرد. اگر دامنه‌ای از قبل داری و zone آن در Cloudflare فعال است، در صفحهٔ Worker از **Settings → Domains & Routes → Add → Custom Domain** یک زیردامنه مثل `api.your-domain.com` تنظیم کن. Cloudflare DNS و گواهی TLS لازم را ایجاد می‌کند. دامنهٔ فرضی `your-domain.com` را در اپ وارد نکن؛ باید نام دامنهٔ واقعی خودت باشد.

### ۴) ساخت برنامه با API آنلاین Cloudflare

در این نسخه قابلیت آنلاین فقط وقتی روشن می‌شود که build define فعال باشد؛ حالت آفلاین محلی عمداً حفظ شده است. بعد از گرفتن URL واقعی Worker:

```powershell
# از پوشه store_master_offline
flutter build apk --release `
  --dart-define=STORE_MASTER_ONLINE_ENABLED=true `
  --dart-define=STORE_MASTER_API_URL=https://storemaster-api.YOUR_ACCOUNT_SUBDOMAIN.workers.dev
```

برای برنامهٔ مدیریت ویندوز:

```powershell
# از پوشه store_master_admin
flutter build windows --release `
  --dart-define=STORE_MASTER_ADMIN_ONLINE_ENABLED=true `
  --dart-define=STORE_MASTER_API_URL=https://storemaster-api.YOUR_ACCOUNT_SUBDOMAIN.workers.dev `
  --dart-define=STORE_MASTER_ADMIN_KEY=YOUR_ADMIN_KEY
```

URL و کلید نمونه را با مقدار واقعی خودت جایگزین کن. چون کلید `STORE_MASTER_ADMIN_KEY` داخل فایل اجرایی مدیر قرار می‌گیرد، فردی که به فایل اجرایی دسترسی دارد ممکن است بتواند آن را استخراج کند. برنامهٔ مدیر را فقط به اپراتور قابل‌اعتماد بده و در صورت افشا `ADMIN_KEY` را عوض و نسخهٔ مدیر را دوباره بساز. برای ارائهٔ عمومیِ برنامهٔ مدیریت، بهتر است بعداً مدل احراز هویت ادمین با حساب کاربری/Cloudflare Access جایگزین شود؛ این نسخه برای حفظ قرارداد فعلی برنامه از `X-Admin-Key` استفاده می‌کند.

## مهاجرت یک‌باره از PostgreSQL قدیمی

دیتابیس D1 تازه به‌صورت خودکار با داده‌های PostgreSQL/Railway پر نمی‌شود. اگر کدهای فروشگاه، کاربران، لایسنس‌ها، اعلان‌ها و سوابق قبلی باید حفظ شوند، قبل از سوئیچ نهایی یک انتقال یک‌باره انجام بده. پس از انتقال و بررسی صحت داده‌ها، اجرای روزمره دیگر به Railway نیاز ندارد.

در یک محیط امن با Node.js، ابتدا از دیتابیس قدیمی خروجی بگیر. رشتهٔ اتصال فقط در Environment Variable باشد؛ در فایل کد یا Git قرارش نده:

```powershell
cd cloudflare-api
npm install
$env:SOURCE_DATABASE_URL = 'رشته اتصال PostgreSQL فعلی'
node scripts/export-postgres.mjs
```

این مرحله فایل محرمانهٔ `storemaster-postgres-export.json` می‌سازد؛ حاوی شناسه‌ها، هش رمزها، و اطلاعات لایسنس است. آن را در GitHub commit نکن و پس از اتمام مهاجرت طبق سیاست نگهداری امن حذف کن.

پس از deploy موفق Worker و ایجاد Secretهای Cloudflare، در همان پوشه این فرمان را اجرا کن تا رکوردهای خروجی به D1 وارد شوند:

```powershell
$env:CLOUDFLARE_API_TOKEN = 'توکن محدود Cloudflare'
$env:CLOUDFLARE_ACCOUNT_ID = 'شناسه Account'
node scripts/import-d1-json.mjs .\storemaster-postgres-export.json
```

اسکریپت از Wrangler و D1 Remote استفاده می‌کند و شناسه‌های اصلی را نگه می‌دارد. انتقال ابتدا روی نسخهٔ آزمایشی انجام شود؛ قبل از وارد کردن به D1 تولید، از D1 خروجی/backup بگیر. اجرای دوبارهٔ import می‌تواند رکوردهای هم‌شناسه را جایگزین کند؛ هم‌زمان با واردکردن داده، فروش زنده روی API جدید را شروع نکن. بعد از import، در `/health`، ورود با یک حساب تست، لیست لایسنس‌ها، همگام‌سازی دو دستگاه و گفت‌وگوی تیکت را بررسی کن.

اگر به دیتابیس PostgreSQL فعلی دسترسی نداری یا نمی‌خواهی هیچ اتصال Railway حتی یک‌بار هم استفاده شود، سرویس Cloudflare مستقل deploy می‌شود، اما دیتابیس D1 تازه و خالی خواهد بود؛ باید فروشگاه/لایسنس‌ها را در API جدید دوباره provision کنی. هیچ انتقال داده‌ای بدون دسترسی به منبع امکان‌پذیر نیست.

## Endpointهای تحت پوشش

- `GET /health`, `GET /api/v1/public/time`, `GET /api/v1/public/pricing`
- `POST /api/v1/stores/bootstrap`
- `POST /api/v1/auth/login`, `GET /api/v1/auth/me`, `POST /api/v1/auth/logout-device`
- `POST /api/v1/licenses/activate`, `POST /api/v1/licenses/activate-code`, `GET /api/v1/licenses/me`, `GET /api/v1/licenses/pricing`
- `POST /api/v1/sync/push`, `GET /api/v1/sync/pull`, `POST /api/v1/cloud-sync/push`, `GET /api/v1/cloud-sync/snapshot`
- `GET/POST/PUT/DELETE /api/v1/users...`
- `POST/GET /api/v1/support/tickets...` و مسیرهای پیام تیکت با `X-Ticket-Access`
- `POST /api/v1/invoices/share`, `GET /api/v1/invoices/public/{token}`
- `/api/v1/notifications...`
- مسیرهای اصلی `/api/v1/admin/...` برای سیاست تریال، ساخت فروشگاه/لایسنس، وضعیت لایسنس، تخفیف، قیمت‌گذاری و پشتیبانی
- `GET/POST/PUT/DELETE /api/v1/files/{key}` برای ذخیره‌سازی خصوصی scoped به فروشگاه در R2

## داده و محدودیت‌ها

- D1 پایگاه دادهٔ SQL سازگار با SQLite است، نه PostgreSQL. Worker این API را مستقل اجرا می‌کند؛ ASP.NET Core را مستقیم روی Workers اجرا نمی‌کند.
- طبق مستندات Cloudflare، Worker در پلن رایگان سقف ۱۰ میلی‌ثانیه CPU برای هر درخواست HTTP و ۱۰۰٬۰۰۰ درخواست در روز دارد. احراز هویت این پروژه از `bcryptjs` برای بررسی/ساخت هش رمز استفاده می‌کند و ممکن است در سقف ۱۰ms به خطای CPU برسد؛ قبل از راه‌اندازی واقعی، ورود و ساخت حساب را در محیط آزمایشی بسنج. اگر با خطای CPU/1102 مواجه شدی، برای احراز هویت پایدار باید پلن Workers Standard/Paid را فعال کنی یا روش رمزنگاری/احراز هویت را بازطراحی و تست کنی؛ این کار همچنان نیازی به VPS یا Railway ندارد. مرجع: https://developers.cloudflare.com/workers/platform/limits/
- سهمیه‌های D1/Workers را در Cloudflare Dashboard زیر نظر بگیر. پلن رایگان D1 نیز محدودیت حجم و تعداد عملیات دارد؛ قبل از ورود داده‌های واقعی، اندازهٔ دیتابیس PostgreSQL فعلی را با حد D1 مقایسه کن. مرجع: https://developers.cloudflare.com/d1/platform/limits/
- R2 در این بسته به‌عنوان فضای خصوصی برای فایل‌های بزرگ/بکاپ آماده شده است؛ پشتیبان‌گیری خودکار و بازیابی آزمایش‌شده جایگزین مستقلی دارد و باید پیش از اتکای تولیدی اضافه/آزمایش شود. D1 و R2 به‌تنهایی تضمین backup point-in-time نیستند.
- باقی ماندن پوشه‌های `server/`, `ops/`, `RAILWAY_DEPLOY_FA.md` و `cloudflare/` عمدی است. `cloudflare/` قبلی Worker failover قدیمی است که Railway/VPS می‌خواهد؛ سرویس اصلی جدید در `cloudflare-api/` است و به آن دو نیاز ندارد.
