# اصلاح خطاهای `flutter analyze` — Store Master Pro

## ۱) برنامهٔ کاربر (`store_master_offline`)

- در `lib/services/online_api_service.dart`، ایمپورت `dart:async` اضافه شد تا `TimeoutException` تعریف‌شده باشد.
- cast غیرضروری `lastError as Exception` حذف شد؛ شرط نوعی `lastError is Exception` برای ارتقای نوع و پرتاب همان خطا کافی است.

## ۲) برنامهٔ ادمین (`store_master_admin`)

- ایمپورت غیرضروری `dart:typed_data` از `lib/screens/license_manager_screen.dart` حذف شد؛ ابزارهای استفاده‌شده از قبل توسط `package:flutter/services.dart` در دسترس بودند.

## اعتبارسنجی

- آزمون‌های Worker کلودفلر: ۸ از ۸ موفق.
- در این محیط `flutter` و `dart` نصب نیستند؛ بنابراین `flutter analyze` روی دو پروژه اینجا دوباره اجرا نشده است. لطفاً در پوشهٔ هر دو پروژه دستور `flutter analyze` را اجرا کن تا نتیجهٔ واقعی toolchain محلی تأیید شود.
- این تغییرها صرفاً دو مشکل گزارش‌شده را اصلاح می‌کنند و عمداً نسخه‌های وابستگی‌ها را ارتقا نمی‌دهند.
