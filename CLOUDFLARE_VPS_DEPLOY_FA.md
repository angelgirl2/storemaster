# استقرار Store Master Pro — Railway اصلی و VPS پشتیبان

## وضعیت دامنه

هنوز دامنه نداری؛ برای شروع امکان استفاده از زیردامنهٔ `workers.dev` وجود دارد. پس از deploy، Cloudflare یک URL برای Worker می‌دهد، معمولاً به‌شکل `https://storemaster-api-failover.<YOUR_ACCOUNT_SUBDOMAIN>.workers.dev`. مقدار `<YOUR_ACCOUNT_SUBDOMAIN>` را باید از Cloudflare Dashboard کپی کنی.

## اجزای زیرساخت

- **Railway:** API اصلی تا زمانی که سالم است.
- **VPS:** اجرای API پشتیبان و PostgreSQL پایدار با Docker Compose.
- **Cloudflare Worker:** بررسی `GET /health/ready` و انتخاب مبدا.
- **Cloudflare Durable Object:** نگهداری وضعیت failover به شکل پایدار؛ بازگشت خودکار به Railway انجام نمی‌شود.
- **Cloudflare R2:** نگهداری فایل‌های backup که از PostgreSQL روی VPS گرفته می‌شوند.

## پیش از انتشار اپ جدید

1. در حساب Cloudflare API Token با مجوز حداقلی Workers deploy و دسترسی لازم R2 بساز.
2. `cloudflare/bootstrap.sh` را با `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID`, `PRIMARY_API_ORIGIN`, `FALLBACK_API_ORIGIN`, و `FAILOVER_CONTROL_KEY` اجرا کن.
3. آدرس Worker را از داشبورد کپی و به‌عنوان `STORE_MASTER_API_URL` در build تعریف کن. این URL باید به Worker اشاره کند، نه مستقیم به Railway.
4. برای نسخهٔ ادمین `STORE_MASTER_ADMIN_ONLINE_ENABLED=true` را نیز تنظیم کن.
5. `ops/docker-compose.prod.yml` روی VPS به `ops/.env` با مقادیر معتبر برای PostgreSQL, JWT, ADMIN و دامنه/گواهی نیاز دارد. فایل `.env` را commit یا ارسال نکن.

## هشدار مهم

Worker به‌تنهایی داده‌های دیتابیس Railway را به PostgreSQL VPS منتقل یا replicate نمی‌کند. مسیر جایگزین شبکه آماده است، ولی برای تضمین دسترسی به آخرین فروش‌ها و لایسنس‌ها، قبل از تولید باید Railway و VPS را به دیتابیس مرجع مشترک متصل کنی یا replication واقعی دیتابیس را راه‌اندازی و آزمایش کنی. این تنظیم به اطلاعات اتصال فعلی و دسترسی واقعی سرورها نیاز دارد و در این بسته به حساب‌های میزبانی اعمال نشده است.

پس از فعال‌شدن failover، Worker تا زمان reset دستی روی VPS می‌ماند. reset فقط پس از بررسی سلامت Railway و تأیید هماهنگی داده‌ها انجام شود. برای مشاهدهٔ وضعیت از `GET /__ops/failover/status` با هدر `x-failover-control-key` استفاده کن.
