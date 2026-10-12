# قبل از خرید VPS — StoreMaster Multi-Tenant Gate

این پروژه برای یک VPS مشترک با چندین فروشگاه طراحی شده است. خرید VPS را بعد از پاس شدن موارد زیر انجام بده.

## 1. Multi-tenant
- دو یا بیشتر فروشگاه بساز.
- هر فروشگاه login جداگانه داشته باشد.
- فروشگاه A نباید cloud/sync/users/support داده فروشگاه B را ببیند.
- قطع/فعال‌سازی لایسنس A نباید روی B اثر بگذارد.

## 2. Production topology
`Internet -> Caddy/HTTPS -> API -> PgBouncer -> PostgreSQL/PostGIS`

PostgreSQL و PgBouncer نباید روی Internet publish شوند.

## 3. Credentials
- `JWT_KEY` حداقل 64 کاراکتر تصادفی.
- `ADMIN_KEY` فقط در License Manager/پنل مرکزی.
- هیچ secret سرور داخل Flutter APK/EXE قرار نگیرد.

## 4. Database
- PostgreSQL 18 + PostGIS 3.6.
- backup روزانه و تست restore.
- تغییر schema با migration/versioned SQL، نه `EnsureCreated` در production.

## 5. VPS sizing
برای شروع فروشگاه‌های کم تا متوسط می‌توان با VPS مناسب آغاز کرد؛ تعداد دقیق فروشگاه‌ها به تعداد کاربران همزمان، حجم sync، گزارش‌ها، فایل‌ها و ترافیک بستگی دارد و باید با load test تعیین شود.

## 6. Required local tests
```powershell
cd ops
.\scripts\reset-test.ps1
.\scripts\start-test.ps1
.\scripts\full-smoke-test.ps1
.\scripts\multi-tenant-test.ps1
```

تا قبل از پاس شدن تست چندفروشگاهی و backup/restore، VPS production را مرجع نهایی برنامه قرار نده.
