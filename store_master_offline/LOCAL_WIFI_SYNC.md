# StoreMaster Local Wi-Fi Sync

StoreMaster Windows به‌عنوان Hub محلی و Android به‌عنوان Client محلی کار می‌کند. هر دو دستگاه می‌توانند با یک **لایسنس مشترک (Shared)** در یک Wi-Fi قرار بگیرند و اطلاعات فروشگاه را بدون VPS/اینترنت همگام کنند.

## رفتار نهایی

1. License Manager یک لایسنس با `platform=ALL` و `deviceBinding=STORE_SHARED` صادر می‌کند.
2. Windows همان لایسنس را فعال می‌کند و Hub محلی روی `0.0.0.0:38645` و discovery روی UDP `38644` اجرا می‌شود.
3. Android حتی اگر هنوز فایل لایسنس را وارد نکرده باشد، فروشگاه‌های Shared موجود در همان Wi-Fi را کشف می‌کند و در صفحه فعال‌سازی نشان می‌دهد.
4. کاربر فروشگاه موردنظر را انتخاب می‌کند؛ Windows لایسنس Shared امضاشده را ارسال می‌کند. Android امضا را بررسی و همان لایسنس را ذخیره می‌کند.
5. سپس Snapshot کامل داده‌های فروشگاه، از جمله `store_config` و تنظیمات مجاز `app_settings`، دریافت می‌شود.
6. بعد از اتصال، درج/ویرایش/حذف داده‌ها از طریق `local_sync_log` به Windows و سایر Androidهای همان فروشگاه پخش می‌شود.
7. کاربر Android پس از دریافت کاربران فروشگاه، از صفحه Login با یکی از کاربران همگام‌شده وارد می‌شود.

## چه چیزهایی همگام می‌شود

تمام جدول‌های SQLite دارای کلید اصلی، به‌جز زیرساخت Sync، همگام می‌شوند. `app_settings` نیز همگام می‌شود، به‌جز کلیدهای خصوصی دستگاه و لایسنس (`license_*`, `local_trial_*`, `local_sync_device_id` و قفل انقضا).

## شبکه Windows

- TCP `38645` برای WebSocket
- UDP `38644` برای Discovery
- Windows Firewall باید این دو پورت را روی Private Network اجازه دهد.
- Client isolation / AP isolation در مودم یا Access Point باید خاموش باشد.

فایل `ops/allow_storemaster_lan.ps1` برای ساخت Ruleهای Firewall اضافه شده است. آن را با PowerShell **Run as Administrator** اجرا کنید.

## Android

`INTERNET`, `ACCESS_NETWORK_STATE` و `ACCESS_WIFI_STATE` فعال هستند و برای WebSocket محلی، Cleartext LAN در Manifest مجاز شده است؛ بنابراین `ws://192.168.x.x:38645` در شبکه داخلی قابل استفاده است.
