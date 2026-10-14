# StoreMaster User - اصلاحات
- حالت آنلاین پیش‌فرض فعال شد.
- آدرس پیش‌فرض Android Emulator به http://10.0.2.2:8080 تغییر کرد؛ برای دستگاه واقعی از STORE_MASTER_API_URL استفاده کنید.
- راه‌اندازی همگام‌سازی شبکه محلی دیگر نباید مانع startup شود.
- VideoPlayerMediaKit فقط روی Windows initialize می‌شود.
- اعتبارسنجی عمومی لایسنس اکنون storeCode را هم می‌تواند ارسال کند.
- قرارداد ورود آنلاین همان `/api/v1/auth/login` است و بعد از bootstrap واقعی فروشگاه قابل استفاده است.
