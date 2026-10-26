# راهنمای استقرار مسیر جایگزین Store Master Pro

## وضعیت این نسخه

این پوشه شامل Worker مسیریاب، Durable Object برای نگهداری وضعیت failover، اسکریپت استقرار، و workflow گیت‌هاب است. Worker می‌تواند روی آدرس `workers.dev` فعال شود؛ بنابراین برای آزمایش اولیه لازم نیست همین حالا دامنه بخری. مستقرکردن در حساب واقعی Cloudflare به API Token و Account ID همان حساب نیاز دارد. توجه کن که **مبدا VPS نیز باید یک نشانی پایدار HTTPS داشته باشد**؛ `workers.dev` فقط آدرس جلویی Worker است و به‌تنهایی برای VPS گواهی TLS یا نام میزبان ایجاد نمی‌کند.

## پیش‌نیازها در حساب Cloudflare

1. در Cloudflare Dashboard، بخش Workers & Pages را باز کن و مطمئن شو زیردامنهٔ `workers.dev` حساب فعال است.
2. از My Profile → API Tokens یک توکن محدود برای استقرار Workers بساز. Token را داخل سورس یا چت ننویس.
3. آدرس مستقیم Railway و آدرس مستقیم API سرور VPS باید مشخص باشند. هر دو باید مسیر `/health/ready` را ارائه کنند و هر دو از یک دیتابیس معتبر و همگام‌شده استفاده کنند.
4. یک `FAILOVER_CONTROL_KEY` تصادفی با حداقل ۳۲ نویسه بساز؛ این کلید فقط برای endpoint مدیریتی reset وضعیت failover است. هر دو نشانی مبدا باید با `https://` شروع شوند و مستقیم به API وصل شوند.

## استقرار از ترمینال

در محیط امنی که Node.js/npm و دسترسی حساب Cloudflare دارد، متغیرهای زیر را تنظیم کن و سپس اسکریپت را اجرا کن:

- `CLOUDFLARE_API_TOKEN`
- `CLOUDFLARE_ACCOUNT_ID`
- `PRIMARY_API_ORIGIN` (مثلاً URL مستقیم Railway، بدون `/api/v1`)
- `FALLBACK_API_ORIGIN` (URL مستقیم API روی VPS، هرگز نشانی Worker نباشد)
- `FAILOVER_CONTROL_KEY` (حداقل ۳۲ نویسه)

از پوشه `cloudflare/` اجرا کن:

```bash
bash bootstrap.sh
```

اسکریپت bucket بکاپ R2 را در صورت نبودن می‌سازد، Worker را deploy می‌کند و کلید کنترلی را به‌عنوان Secret ثبت می‌کند. پس از استقرار، URL شبیه `https://storemaster-api-failover.<YOUR_ACCOUNT_SUBDOMAIN>.workers.dev` در داشبورد نمایش داده می‌شود. زیردامنهٔ واقعی حساب را از خود داشبورد کپی کن؛ آن را حدس نزن.

## رفتار failover

- تا زمانی که Railway سالم است، درخواست‌ها به Railway می‌روند.
- اگر health check Railway شکست بخورد و VPS سالم باشد، Worker حالت fallback را در Durable Object پایدار ثبت کرده و درخواست‌های بعدی را به VPS می‌فرستد.
- پس از فعال شدن fallback، برگشت خودکار به Railway **غیرفعال** است تا دو سرور با دیتابیس‌های متفاوت به شکل split-brain هم‌زمان فروش یا لایسنس ثبت نکنند.
- پس از بررسی و reconcile دیتابیس، مدیر می‌تواند با `GET /__ops/failover/status` وضعیت را بررسی کند و با `POST /__ops/failover/reset-primary` و هدر `x-failover-control-key` وضعیت را برگرداند. بدنهٔ درخواست باید `{"databaseReconciled":true}` باشد. این تأیید فقط زمانی داده شود که واقعاً داده‌های دو سمت هماهنگ شده باشند.
- اگر یک درخواست write واقعاً به Railway ارسال شده و سپس خطای اتصال یا 502/503/504 رخ دهد، Worker همان درخواست را دوباره اجرا نمی‌کند؛ نتیجهٔ آن درخواست مبهم است و باید قبل از تکرار بررسی شود. اگر health check قبل از ارسال درخواست شکست خورده باشد، درخواست می‌تواند مستقیماً به VPS برود.

## هشدار پایگاه داده — قبل از استفادهٔ تجاری ضروری است

Worker فقط مسیریابی را انجام می‌دهد؛ دیتابیس Railway را کپی یا replicate نمی‌کند. فایل `ops/docker-compose.prod.yml` یک PostgreSQL پایدار روی VPS می‌سازد و `ops/scripts/backup-db-to-r2.sh` می‌تواند بکاپ همان PostgreSQL را در R2 قرار دهد، اما این به‌خودی‌خود دیتابیس Railway را همگام نمی‌کند.

برای failover بدون از دست رفتن فروش/تغییرات لایسنس، Railway API و VPS API باید از **یک PostgreSQL مرجع مشترک و پایدار** استفاده کنند یا یک replication/promote/reconcile واقعی، با تست failover و بازگشت، راه‌اندازی شود. در غیر این صورت، این Worker یک مسیر جایگزین شبکه‌ای است، نه تضمین تداوم داده. پشتیبان روزانه R2 به‌تنهایی replication لحظه‌ای نیست.

## پیکربندی اپ Flutter

برای ساخت APK و Windows، `STORE_MASTER_API_URL` را به URL Worker بده، نه Railway. مثال (URL را با مقدار واقعی پس از deploy عوض کن):

```powershell
flutter build apk --release --dart-define=STORE_MASTER_ONLINE_ENABLED=true --dart-define=STORE_MASTER_API_URL=https://storemaster-api-failover.YOUR_ACCOUNT_SUBDOMAIN.workers.dev
```

ساخت نسخهٔ ادمین آنلاین نیز باید با `STORE_MASTER_ADMIN_ONLINE_ENABLED=true` و همان URL انجام شود. تنظیمات URL به‌صورت build-time هستند؛ تغییر قیمت، وضعیت لایسنس و اعلان‌ها در API بدون ساخت نسخهٔ جدید قابل اعمال است، ولی تغییر URL اصلی بعد از انتشار، بدون قابلیت Remote Config، نیاز به تنظیم کاربر یا نسخهٔ تازه دارد.

## بکاپ PostgreSQL به R2

روی VPS با Docker و متغیرهای درست `ops/.env`، این مقادیر را در محیط امن بکاپ تنظیم کن: `R2_ACCOUNT_ID`, `R2_BUCKET`, `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`. سپس `bash ops/scripts/backup-db-to-r2.sh` را اجرا کن. قبل از اتکا به بکاپ، بازیابی آزمایشی را روی دیتابیس جدا انجام بده. اسکریپت زمان‌بندی نمونهٔ cron در `ops/scripts/install-r2-backup-cron.sh` قرار دارد.

## GitHub Actions

برای deploy خودکار، در Settings → Secrets and variables → Actions این Secrets را تعریف کن:

- `CLOUDFLARE_API_TOKEN`
- `CLOUDFLARE_ACCOUNT_ID`
- `FAILOVER_CONTROL_KEY` (حداقل ۳۲ نویسه)

و این Variables را تعریف کن:

- `PRIMARY_API_ORIGIN`
- `FALLBACK_API_ORIGIN`

Workflow تست‌های Node را اجرا می‌کند و سپس Worker را deploy می‌کند. اگر Secretها تنظیم نشده باشند، workflow عمداً fail می‌شود؛ هیچ credential داخل repository ذخیره نشده است.
