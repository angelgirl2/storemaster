# اصلاح خطای فعال نبودن R2 در استقرار Store Master

این اصلاح باعث می‌شود خطای زیر به‌تنهایی مانع انتشار API نشود:

`403: Please enable R2 through the Cloudflare Dashboard.`

## نصب اصلاحیه

1. فایل `cloudflare-api/scripts/provision.mjs` را در پروژهٔ مخزن `angelgirl2/storemaster` با فایل هم‌مسیر داخل این بسته جایگزین کن.
2. از ریشهٔ مخزن اجرا کن:

```powershell
git add cloudflare-api/scripts/provision.mjs
git commit -m "Allow Cloudflare deployment without optional R2"
git push origin main
```

3. در GitHub به **Actions** برو و workflow مربوط به `Deploy Store Master API to Cloudflare (D1 + R2)` را دوباره اجرا کن.

## رفتار این اصلاحیه

- D1 به شکل معمول ساخته/استفاده می‌شود.
- اگر API مربوط به R2 مشخصاً پاسخ دهد که باید R2 در Dashboard فعال شود، اسکریپت binding مربوط به R2 را از `wrangler.toml` همان اجرای CI حذف می‌کند و به deploy ادامه می‌دهد.
- اگر خطا علت دیگری داشته باشد، مثل توکن بدون مجوز، اجرا همچنان متوقف می‌شود تا خطای دسترسی پنهان نماند.
- APIهای داده و لاگین می‌توانند بدون R2 مستقر شوند. مسیرهای `/api/v1/files/...` تا فعال‌شدن R2 پاسخ `503` می‌دهند؛ ذخیره‌سازی فایل در این حالت در دسترس نیست.
- تغییر `wrangler.toml` فقط در محیط همان GitHub Actions است و به فایل داخل مخزن commit نمی‌شود. هر اجرای بعدی از نسخهٔ تمیز مخزن شروع می‌شود و وضعیت R2 را دوباره تشخیص می‌دهد.

## اگر ذخیره‌سازی فایل لازم است

در [Cloudflare Dashboard](https://dash.cloudflare.com/) حساب درست را باز کن، وارد **R2 Object Storage** شو و مراحل **Get started / Enable R2** را تکمیل کن. Cloudflare ممکن است برای فعال‌سازی اولیه روش پرداخت بخواهد؛ قبل از ادامه، شرایط صورتحساب و سهمیه‌های حساب را بررسی کن. سپس همان workflow را مجدداً اجرا کن؛ اسکریپت bucket `storemaster-files` را می‌سازد و `FILES` binding را نگه می‌دارد.

**نکته:** این اصلاحیه R2 را دور نمی‌زند و قابلیت فایل را شبیه‌سازی نمی‌کند؛ تنها اجازه می‌دهد سرویس API مبتنی بر D1 بدون قابلیت فایل هم منتشر شود.
