# StoreMaster — Production-like test / VPS deployment

این پوشه عمداً با محیط Production هم‌ساختار است تا قبل از خرید VPS همان مسیر را روی سیستم محلی تست کنیم.

## Test روی Windows

پیش‌نیاز: Docker Desktop روشن باشد.

```powershell
cd ops
.\scripts\start-test.ps1
.\scripts\test-api.ps1
```

سرویس‌ها:

- API: http://127.0.0.1:8080
- Swagger: http://127.0.0.1:8080/swagger
- pgAdmin: http://127.0.0.1:5050
- PostgreSQL از بیرون expose نشده و فقط داخل Docker network است.
- PgBouncer از بیرون expose نشده است.

برای پاک کردن کامل دیتای تست:

```powershell
.\scripts\reset-test.ps1
```

## Production روی VPS Linux

Ubuntu + Docker را نصب کن، DNS رکورد `DOMAIN` را به IP سرور ببر و `.env.prod.example` را به `.env` تبدیل کن. سپس:

```bash
cd ops
docker compose -f docker-compose.prod.yml up -d --build
```

Caddy روی 80/443 قرار دارد و HTTPS را برای domain مدیریت می‌کند. PostgreSQL و PgBouncer روی اینترنت publish نشده‌اند.

## Flutter API URL

کد Flutter فعلی `STORE_MASTER_API_URL` را به عنوان **ریشه API** می‌گیرد و خودش `/api/v1` را اضافه می‌کند. بنابراین درست:

```text
https://api.example.com
```

و غلط:

```text
https://api.example.com/api/v1
```

Build آنلاین تست:

```bash
flutter run --dart-define=STORE_MASTER_ONLINE_ENABLED=true --dart-define=STORE_MASTER_ONLINE_REQUIRED=true --dart-define=STORE_MASTER_API_URL=http://127.0.0.1:8080
```

برای Android روی PC، به جای `127.0.0.1` از IP کامپیوتر در LAN استفاده کن. برای VPS از HTTPS domain استفاده کن.

## Production safety

- `.env` واقعی را commit یا داخل APK نگذار.
- PostgreSQL را مستقیماً روی Internet باز نکن.
- 80/443 را روی firewall باز کن.
- قبل از هر deploy از PostgreSQL backup بگیر.
- image ها را در production با نسخه pin شده نگه دار؛ `latest` استفاده نکن.
- database init فقط برای ساخت اولیه است؛ تغییر schemaهای بعدی باید با migration کنترل‌شده انجام شود.
