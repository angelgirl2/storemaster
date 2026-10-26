# مسیر استقرار پیشنهادی Store Master Pro: Cloudflare به‌عنوان API اصلی

نسخهٔ Cloudflare-first در پوشهٔ `cloudflare-api/` قرار دارد. راهنمای کامل استقرار، مهاجرت یک‌بارهٔ داده، build آنلاین Flutter، Secretها و دامنه در [cloudflare-api/README_FA.md](cloudflare-api/README_FA.md) است.

- API: Cloudflare Workers (`storemaster-api`)
- دیتابیس: Cloudflare D1 (`storemaster-prod`)
- فایل‌ها: Cloudflare R2 (`storemaster-files`)
- استقرار خودکار: `.github/workflows/deploy-cloudflare-api.yml`
- Railway و VPS برای مسیر Cloudflare-first لازم نیستند؛ سورس و راهنمای استقرار قدیمی‌شان حذف نشده‌اند.

توجه: دیتابیس D1 جدید به خودی خود داده‌های موجود PostgreSQL را به ارث نمی‌برد؛ برای نگه‌داشتن فروشگاه‌ها و لایسنس‌های قبلی، دستور مهاجرت یک‌باره داخل راهنما را اجرا و نتیجه را بررسی کن.
