# اصلاح نهایی Android + Dashboard

## 1) خطای Android
خطای `SocketException: Failed to create datagram socket (OS Error: Operation not permitted, errno = 1), address = 0.0.0.0, port = 0` از `RawDatagramSocket.bind` سرویس `local_network_sync_service.dart` می‌آمد.

در Android، سوکت کشف شبکه اکنون روی پورت موقت با:
- `reuseAddress: false`
- `reusePort: false`

ساخته می‌شود و خطای سرویس LAN دیگر مانع بالا آمدن کل برنامه نمی‌شود.

همچنین Windows پاسخ UDP را به **پورت مبدأ بسته کشف** (`dg.port`) برمی‌گرداند؛ بنابراین کشف Android با پورت موقت درست کار می‌کند.

## 2) مجوز Android
در پروژه کامل Flutter، فایل زیر را بررسی کنید:
`android/app/src/main/AndroidManifest.xml`

داخل `<manifest ...>` این مجوز باید وجود داشته باشد:
```xml
<uses-permission android:name="android.permission.INTERNET" />
```

برای این طراحی UDP/LAN، مجوز privileged جدیدی لازم نیست.

## 3) تکراری بودن گزینه‌های داشبورد
در داشبورد دو بخش دسترسی سریع وجود داشت:
- بخش جدید و permission-aware
- بخش قدیمی با کارت‌های ثابت

به همین دلیل POS، کالاها، انبار، مشتریان، هزینه‌ها و گزارش‌ها دوبار و با عنوان‌های متفاوت نمایش داده می‌شدند.

بخش قدیمی حذف شد و `_buildPrimaryActions` تنها منبع کارت‌های دسترسی سریع است. علاوه بر آن، خود سازنده کارت‌ها با route از تکرار احتمالی جلوگیری می‌کند.

دکمه «مدیریت انبار» داخل هشدار کمبود موجودی هم حذف شد تا مقصد `products` دوباره در همان داشبورد تکرار نشود.

## فایل‌های تغییرکرده
- `services/local_network_sync_service.dart`
- `screens/dashboard_screen.dart`

فایل `user.zip` داخل این بسته نیز با همین اصلاحات به‌روزرسانی شده است.
