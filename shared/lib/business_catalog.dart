// ============================================================================
// BusinessProfile + BusinessCatalog
// ============================================================================
// GENERATED / CANONICAL CATALOG
// Keep business codes identical on all platforms.
// ============================================================================

import 'package:flutter/material.dart';

/// پروفایل کامل یک نوع کسب‌وکار.
class BusinessProfile {
  final String code;
  final String label;
  final IconData icon;
  final List<String> categories;
  final List<String> services;

  const BusinessProfile({
    required this.code,
    required this.label,
    required this.icon,
    this.categories = const [],
    this.services = const [],
  });
}

/// کاتالوگ مرکزی و یکسان Store Master.
class BusinessCatalog {
  // --------------------------------------------------------------------------
  // Canonical codes
  // --------------------------------------------------------------------------

  static const profiles = <Map<String, String>>[
    {'code': 'SUPERMARKET', 'label': 'سوپرمارکت و خواربار'},
    {'code': 'GROCERY', 'label': 'خواربار و عمده‌فروشی'},
    {'code': 'CLOTHING', 'label': 'پوشاک و بوتیک'},
    {'code': 'SHOES_BAGS', 'label': 'کیف و کفش'},
    {'code': 'JEWELRY_GOLD', 'label': 'طلافروشی و جواهرفروشی'},
    {'code': 'SILVER', 'label': 'نقره و زیورآلات'},
    {'code': 'WATCH', 'label': 'ساعت و تعمیر ساعت'},
    {'code': 'COSMETICS', 'label': 'آرایشی و بهداشتی'},
    {'code': 'PHARMACY', 'label': 'داروخانه'},
    {'code': 'MEDICAL_SUPPLIES', 'label': 'تجهیزات پزشکی'},
    {'code': 'OPTICAL', 'label': 'عینک‌فروشی و اپتیک'},
    {'code': 'BAKERY', 'label': 'نانوایی'},
    {'code': 'CONFECTIONERY', 'label': 'قنادی و شیرینی‌فروشی'},
    {'code': 'RESTAURANT', 'label': 'رستوران'},
    {'code': 'FAST_FOOD', 'label': 'فست‌فود و ساندویچی'},
    {'code': 'CAFE', 'label': 'کافه و کافی‌شاپ'},
    {'code': 'CATERING', 'label': 'تهیه غذا و کترینگ'},
    {'code': 'MOBILE', 'label': 'موبایل و تبلت'},
    {'code': 'MOBILE_ACCESSORIES', 'label': 'لوازم جانبی موبایل'},
    {'code': 'COMPUTER', 'label': 'کامپیوتر و لپ‌تاپ'},
    {'code': 'COMPUTER_REPAIR', 'label': 'تعمیرات کامپیوتر و لپ‌تاپ'},
    {'code': 'PRINT_SERVICES', 'label': 'چاپ، کپی و تکثیر'},
    {'code': 'NET_CAFE', 'label': 'کافی‌نت و خدمات اینترنتی'},
    {'code': 'STATIONERY', 'label': 'نوشت‌افزار و کتاب'},
    {'code': 'PHOTOGRAPHY', 'label': 'عکاسی و آتلیه'},
    {'code': 'GAME_CLUB', 'label': 'گیم‌نت و کلوپ بازی'},
    {'code': 'VIDEO_CLUB', 'label': 'کلوپ فیلم و موسیقی'},
    {'code': 'AUTO_SPARE_PARTS', 'label': 'فروشگاه لوازم یدکی خودرو'},
    {'code': 'AUTO_ELECTRICAL', 'label': 'برق خودرو'},
    {'code': 'OIL_CHANGE', 'label': 'تعویض روغنی و فیلتر'},
    {'code': 'CAR_AUDIO', 'label': 'سیستم صوتی و مالتی‌مدیا خودرو'},
    {'code': 'CAR_TINT', 'label': 'شیشه دودی و آپشن خودرو'},
    {'code': 'MECHANIC', 'label': 'مکانیکی و تعمیرات خودرو'},
    {'code': 'TIRE', 'label': 'لاستیک و آپاراتی'},
    {'code': 'CAR_WASH_DETAILING', 'label': 'کارواش و دیتیلینگ'},
    {'code': 'AUTO_BODY_PAINT', 'label': 'صافکاری و نقاشی خودرو'},
    {'code': 'FURNITURE', 'label': 'مبلمان و دکوراسیون'},
    {'code': 'CURTAIN', 'label': 'پرده و دکوراسیون پنجره'},
    {'code': 'HOME_APPLIANCE', 'label': 'لوازم خانگی'},
    {'code': 'HARDWARE', 'label': 'ابزار و یراق‌آلات'},
    {'code': 'BUILDING_MATERIALS', 'label': 'مصالح ساختمانی'},
    {'code': 'ELECTRICAL_CONTRACTOR', 'label': 'برق‌کاری ساختمان'},
    {'code': 'PLUMBING', 'label': 'لوله‌کشی و تأسیسات'},
    {'code': 'HVAC', 'label': 'تهویه، کولر و گرمایش'},
    {'code': 'BEAUTY_SALON', 'label': 'سالن زیبایی'},
    {'code': 'BARBERSHOP', 'label': 'آرایشگاه مردانه'},
    {'code': 'TAILOR', 'label': 'خیاطی و دوخت'},
    {'code': 'LAUNDRY', 'label': 'خشکشویی و لباسشویی'},
    {'code': 'SHOE_REPAIR', 'label': 'تعمیر کفش و کیف'},
    {'code': 'PET_SHOP', 'label': 'پت‌شاپ'},
    {'code': 'VETERINARY', 'label': 'دامپزشکی و کلینیک حیوانات'},
    {'code': 'REAL_ESTATE', 'label': 'مشاور املاک'},
    {'code': 'INSURANCE', 'label': 'نمایندگی بیمه'},
    {'code': 'ACCOUNTING_OFFICE', 'label': 'دفتر حسابداری'},
    {'code': 'LEGAL_OFFICE', 'label': 'دفتر حقوقی و وکالت'},
    {'code': 'TRANSLATION', 'label': 'ترجمه و آموزش زبان'},
    {'code': 'TRAINING', 'label': 'آموزشگاه و کلاس خصوصی'},
    {'code': 'TRAVEL_AGENCY', 'label': 'آژانس مسافرتی'},
    {'code': 'DELIVERY', 'label': 'پیک و خدمات ارسال'},
    {'code': 'FITNESS', 'label': 'باشگاه ورزشی و بدنسازی'},
    {'code': 'GENERAL', 'label': 'فروشگاه عمومی / سایر'},
  ];

  static const Set<String> codes = {
    'SUPERMARKET',
    'GROCERY',
    'CLOTHING',
    'SHOES_BAGS',
    'JEWELRY_GOLD',
    'SILVER',
    'WATCH',
    'COSMETICS',
    'PHARMACY',
    'MEDICAL_SUPPLIES',
    'OPTICAL',
    'BAKERY',
    'CONFECTIONERY',
    'RESTAURANT',
    'FAST_FOOD',
    'CAFE',
    'CATERING',
    'MOBILE',
    'MOBILE_ACCESSORIES',
    'COMPUTER',
    'COMPUTER_REPAIR',
    'PRINT_SERVICES',
    'NET_CAFE',
    'STATIONERY',
    'PHOTOGRAPHY',
    'GAME_CLUB',
    'VIDEO_CLUB',
    'AUTO_SPARE_PARTS',
    'AUTO_ELECTRICAL',
    'OIL_CHANGE',
    'CAR_AUDIO',
    'CAR_TINT',
    'MECHANIC',
    'TIRE',
    'CAR_WASH_DETAILING',
    'AUTO_BODY_PAINT',
    'FURNITURE',
    'CURTAIN',
    'HOME_APPLIANCE',
    'HARDWARE',
    'BUILDING_MATERIALS',
    'ELECTRICAL_CONTRACTOR',
    'PLUMBING',
    'HVAC',
    'BEAUTY_SALON',
    'BARBERSHOP',
    'TAILOR',
    'LAUNDRY',
    'SHOE_REPAIR',
    'PET_SHOP',
    'VETERINARY',
    'REAL_ESTATE',
    'INSURANCE',
    'ACCOUNTING_OFFICE',
    'LEGAL_OFFICE',
    'TRANSLATION',
    'TRAINING',
    'TRAVEL_AGENCY',
    'DELIVERY',
    'FITNESS',
    'GENERAL',
  };

  static bool containsCode(String code) {
    return codes.contains(code.trim().toUpperCase());
  }

  // --------------------------------------------------------------------------
  // Build BusinessProfile objects
  // --------------------------------------------------------------------------

  static List<BusinessProfile> all() {
    return profiles.map(_createProfile).toList(growable: false);
  }

  static BusinessProfile _createProfile(Map<String, String> item) {
    final code = item['code'] ?? 'GENERAL';
    final label = item['label'] ?? 'سایر';

    return BusinessProfile(
      code: code,
      label: label,
      icon: iconFor(code),
      categories: _categoriesForCode(code),
      services: _servicesForCode(code),
    );
  }

  // --------------------------------------------------------------------------
  // Find
  // --------------------------------------------------------------------------

  static BusinessProfile? find(String? code) {
    if (code == null || code.trim().isEmpty) {
      return null;
    }

    final normalized = code.trim().toUpperCase();

    for (final item in profiles) {
      if (item['code'] == normalized) {
        return _createProfile(item);
      }
    }

    return null;
  }

  // --------------------------------------------------------------------------
  // Groups
  // --------------------------------------------------------------------------

  static Map<String, List<BusinessProfile>> grouped() {
    final result = <String, List<BusinessProfile>>{};

    for (final profile in all()) {
      final group = groupFor(profile.code);

      result.putIfAbsent(group, () => <BusinessProfile>[]);
      result[group]!.add(profile);
    }

    return result;
  }

  static String groupFor(String code) {
    switch (code) {
      // ----------------------------------------------------------------------
      // فروشگاهی
      // ----------------------------------------------------------------------
      case 'SUPERMARKET':
      case 'GROCERY':
      case 'CLOTHING':
      case 'SHOES_BAGS':
      case 'JEWELRY_GOLD':
      case 'SILVER':
      case 'WATCH':
      case 'COSMETICS':
      case 'PHARMACY':
      case 'MEDICAL_SUPPLIES':
      case 'OPTICAL':
      case 'BAKERY':
      case 'CONFECTIONERY':
      case 'MOBILE':
      case 'MOBILE_ACCESSORIES':
      case 'COMPUTER':
      case 'STATIONERY':
      case 'FURNITURE':
      case 'CURTAIN':
      case 'HOME_APPLIANCE':
      case 'HARDWARE':
      case 'BUILDING_MATERIALS':
      case 'PET_SHOP':
        return 'فروشگاهی';

      // ----------------------------------------------------------------------
      // غذایی
      // ----------------------------------------------------------------------
      case 'RESTAURANT':
      case 'FAST_FOOD':
      case 'CAFE':
      case 'CATERING':
        return 'غذایی';

      // ----------------------------------------------------------------------
      // فناوری و خدمات دیجیتال
      // ----------------------------------------------------------------------
      case 'COMPUTER_REPAIR':
      case 'PRINT_SERVICES':
      case 'NET_CAFE':
      case 'PHOTOGRAPHY':
      case 'GAME_CLUB':
      case 'VIDEO_CLUB':
        return 'فناوری و خدمات';

      // ----------------------------------------------------------------------
      // خودرو
      // ----------------------------------------------------------------------
      case 'AUTO_SPARE_PARTS':
      case 'AUTO_ELECTRICAL':
      case 'OIL_CHANGE':
      case 'CAR_AUDIO':
      case 'CAR_TINT':
      case 'MECHANIC':
      case 'TIRE':
      case 'CAR_WASH_DETAILING':
      case 'AUTO_BODY_PAINT':
        return 'خودرو';

      // ----------------------------------------------------------------------
      // ساختمان و تاسیسات
      // ----------------------------------------------------------------------
      case 'ELECTRICAL_CONTRACTOR':
      case 'PLUMBING':
      case 'HVAC':
        return 'ساختمان و تأسیسات';

      // ----------------------------------------------------------------------
      // خدمات شخصی
      // ----------------------------------------------------------------------
      case 'BEAUTY_SALON':
      case 'BARBERSHOP':
      case 'TAILOR':
      case 'LAUNDRY':
      case 'SHOE_REPAIR':
      case 'FITNESS':
        return 'خدمات شخصی';

      // ----------------------------------------------------------------------
      // حیوانات
      // ----------------------------------------------------------------------
      case 'VETERINARY':
        return 'حیوانات';

      // ----------------------------------------------------------------------
      // کسب‌وکار اداری
      // ----------------------------------------------------------------------
      case 'REAL_ESTATE':
      case 'INSURANCE':
      case 'ACCOUNTING_OFFICE':
      case 'LEGAL_OFFICE':
      case 'TRANSLATION':
      case 'TRAINING':
      case 'TRAVEL_AGENCY':
      case 'DELIVERY':
        return 'اداری و خدمات تخصصی';

      case 'GENERAL':
      default:
        return 'سایر';
    }
  }

  // --------------------------------------------------------------------------
  // Title
  // --------------------------------------------------------------------------

  static String titleFor(String? storeType) {
    if (storeType == null || storeType.trim().isEmpty) {
      return 'فروشگاه عمومی / سایر';
    }

    final selectedCodes = storeType
        .split(',')
        .map((e) => e.trim().toUpperCase())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();

    if (selectedCodes.isEmpty) {
      return 'فروشگاه عمومی / سایر';
    }

    final labels = <String>[];

    for (final code in selectedCodes) {
      final profile = find(code);

      if (profile != null && !labels.contains(profile.label)) {
        labels.add(profile.label);
      }
    }

    if (labels.isEmpty) {
      return 'فروشگاه عمومی / سایر';
    }

    if (labels.length == 1) {
      return labels.first;
    }

    return labels.join(' + ');
  }

  // --------------------------------------------------------------------------
  // Categories
  // --------------------------------------------------------------------------

  static List<String> categoriesFor(String? storeType) {
    if (storeType == null || storeType.trim().isEmpty) {
      return const [];
    }

    final result = <String>{};

    for (final rawCode in storeType.split(',')) {
      final code = rawCode.trim().toUpperCase();
      if (code.isEmpty) continue;
      if (!containsCode(code)) continue;
      result.addAll(_categoriesForCode(code));
    }

    return result.toList(growable: false);
  }

  // --------------------------------------------------------------------------
  // Services
  // --------------------------------------------------------------------------

  static List<String> servicesFor(String? storeType) {
    if (storeType == null || storeType.trim().isEmpty) {
      return const [];
    }

    final result = <String>{};

    for (final rawCode in storeType.split(',')) {
      final code = rawCode.trim().toUpperCase();
      if (code.isEmpty) continue;
      if (!containsCode(code)) continue;
      result.addAll(_servicesForCode(code));
    }

    return result.toList(growable: false);
  }

  // --------------------------------------------------------------------------
  // Category catalog per business
  // --------------------------------------------------------------------------

  static List<String> _categoriesForCode(String code) {
    switch (code) {
      case 'SUPERMARKET':
        return const [
          'نوشیدنی',
          'لبنیات',
          'تنقلات',
          'کنسرو و غذای آماده',
          'مواد شوینده',
          'بهداشت شخصی',
          'حبوبات',
          'برنج',
          'روغن',
          'قند و شکر',
          'مواد پروتئینی',
          'منجمد',
          'صبحانه',
        ];

      case 'GROCERY':
        return const [
          'حبوبات',
          'برنج',
          'روغن',
          'قند و شکر',
          'چای و قهوه',
          'ادویه',
          'خشکبار',
          'مواد غذایی عمده',
          'مواد شوینده',
        ];

      case 'CLOTHING':
        return const [
          'لباس مردانه',
          'لباس زنانه',
          'لباس کودک',
          'شلوار',
          'پیراهن',
          'مانتو',
          'کت و شلوار',
          'لباس ورزشی',
          'لباس مجلسی',
        ];

      case 'SHOES_BAGS':
        return const [
          'کفش مردانه',
          'کفش زنانه',
          'کفش کودک',
          'کیف',
          'کوله‌پشتی',
          'کمربند',
          'محصولات چرمی',
        ];

      case 'JEWELRY_GOLD':
        return const [
          'انگشتر',
          'گردنبند',
          'دستبند',
          'گوشواره',
          'النگو',
          'سرویس طلا',
          'سکه',
          'شمش',
        ];

      case 'SILVER':
        return const [
          'انگشتر نقره',
          'گردنبند نقره',
          'دستبند نقره',
          'گوشواره نقره',
          'زیورآلات',
          'شمش نقره',
        ];

      case 'WATCH':
        return const [
          'ساعت مردانه',
          'ساعت زنانه',
          'ساعت کودک',
          'ساعت هوشمند',
          'بند ساعت',
          'باتری ساعت',
        ];

      case 'COSMETICS':
        return const [
          'مراقبت پوست',
          'مراقبت مو',
          'لوازم آرایش',
          'عطر و ادکلن',
          'بهداشت',
          'ضدآفتاب',
        ];

      case 'PHARMACY':
        return const [
          'دارو',
          'مکمل',
          'ویتامین',
          'بهداشت',
          'آرایشی',
          'محصولات کودک',
          'تجهیزات پزشکی',
        ];

      case 'MEDICAL_SUPPLIES':
        return const [
          'تجهیزات مصرفی',
          'تجهیزات پزشکی',
          'ارتوپدی',
          'توانبخشی',
          'لوازم بیمار',
        ];

      case 'OPTICAL':
        return const ['عینک طبی', 'عینک آفتابی', 'فریم', 'لنز', 'لوازم جانبی'];

      case 'BAKERY':
        return const [
          'نان سنتی',
          'نان حجیم',
          'نان فانتزی',
          'شیرینی خشک',
          'محصولات جانبی',
        ];

      case 'CONFECTIONERY':
        return const [
          'کیک',
          'شیرینی تر',
          'شیرینی خشک',
          'دسر',
          'شکلات',
          'محصولات مناسبتی',
        ];

      case 'RESTAURANT':
        return const [
          'غذاهای اصلی',
          'پیش‌غذا',
          'سالاد',
          'نوشیدنی',
          'دسر',
          'غذای ایرانی',
          'غذای فرنگی',
        ];

      case 'FAST_FOOD':
        return const [
          'پیتزا',
          'برگر',
          'ساندویچ',
          'سوخاری',
          'سیب‌زمینی',
          'نوشیدنی',
          'سس و افزودنی',
        ];

      case 'CAFE':
        return const [
          'قهوه',
          'چای',
          'نوشیدنی گرم',
          'نوشیدنی سرد',
          'کیک',
          'دسر',
          'صبحانه',
        ];

      case 'CATERING':
        return const [
          'غذای روز',
          'پرسنلی',
          'مجلسی',
          'پذیرایی',
          'دسر',
          'نوشیدنی',
        ];

      case 'MOBILE':
        return const [
          'گوشی موبایل',
          'تبلت',
          'ساعت هوشمند',
          'سیم‌کارت',
          'محصولات کارکرده',
        ];

      case 'MOBILE_ACCESSORIES':
        return const [
          'قاب',
          'محافظ صفحه',
          'شارژر',
          'کابل',
          'هندزفری',
          'پاوربانک',
          'باتری',
          'تجهیزات جانبی',
        ];

      case 'COMPUTER':
        return const [
          'لپ‌تاپ',
          'کامپیوتر',
          'مانیتور',
          'پرینتر',
          'قطعات',
          'لوازم جانبی',
          'شبکه',
        ];

      case 'COMPUTER_REPAIR':
        return const [
          'لپ‌تاپ',
          'کامپیوتر',
          'پرینتر',
          'نرم‌افزار',
          'شبکه',
          'قطعات',
        ];

      case 'PRINT_SERVICES':
        return const [
          'پرینت',
          'کپی',
          'اسکن',
          'صحافی',
          'لمینت',
          'چاپ عکس',
          'طراحی',
        ];

      case 'NET_CAFE':
        return const [
          'ساعت اینترنت',
          'پرینت',
          'اسکن',
          'کپی',
          'ثبت‌نام',
          'خدمات دولت',
          'خدمات اینترنتی',
        ];

      case 'STATIONERY':
        return const [
          'نوشت‌افزار',
          'دفتر',
          'کتاب',
          'مداد',
          'خودکار',
          'لوازم هنری',
          'کاغذ',
        ];

      case 'PHOTOGRAPHY':
        return const [
          'عکاسی پرسنلی',
          'عکاسی مراسم',
          'چاپ عکس',
          'آلبوم',
          'فریم',
          'تجهیزات',
        ];

      case 'GAME_CLUB':
        return const ['کنسول', 'بازی', 'لوازم جانبی', 'ساعت بازی', 'خوراکی'];

      case 'VIDEO_CLUB':
        return const ['فیلم', 'سریال', 'موسیقی', 'بازی', 'عضویت'];

      case 'AUTO_SPARE_PARTS':
        return const [
          'موتور',
          'بدنه',
          'برق',
          'جلوبندی',
          'ترمز',
          'فیلتر',
          'روغن',
        ];

      case 'AUTO_ELECTRICAL':
        return const [
          'باتری',
          'دینام',
          'استارت',
          'چراغ',
          'فیوز',
          'سنسور',
          'سیم‌کشی',
        ];

      case 'OIL_CHANGE':
        return const [
          'روغن موتور',
          'فیلتر روغن',
          'فیلتر هوا',
          'فیلتر کابین',
          'فیلتر بنزین',
          'ضدیخ',
        ];

      case 'CAR_AUDIO':
        return const [
          'پخش',
          'بلندگو',
          'آمپلی‌فایر',
          'ساب‌ووفر',
          'مانیتور',
          'دوربین',
        ];

      case 'CAR_TINT':
        return const ['شیشه دودی', 'کاور', 'آپشن', 'نورپردازی', 'محافظت بدنه'];

      case 'MECHANIC':
        return const [
          'موتور',
          'گیربکس',
          'تعلیق',
          'ترمز',
          'برق',
          'سرویس دوره‌ای',
        ];

      case 'TIRE':
        return const [
          'لاستیک سواری',
          'لاستیک سنگین',
          'رینگ',
          'والو',
          'لوازم جانبی',
        ];

      case 'CAR_WASH_DETAILING':
        return const [
          'کارواش',
          'صفرشویی',
          'دیتیلینگ',
          'پولیش',
          'سرامیک',
          'واکس',
        ];

      case 'AUTO_BODY_PAINT':
        return const ['صافکاری', 'نقاشی', 'رنگ‌کاری', 'لیسه‌گیری', 'پولیش'];

      case 'FURNITURE':
        return const ['مبل', 'سرویس خواب', 'میز', 'صندلی', 'دکور'];

      case 'CURTAIN':
        return const ['پرده', 'پارچه', 'ریل', 'کرکره', 'دکوراسیون'];

      case 'HOME_APPLIANCE':
        return const [
          'یخچال',
          'لباسشویی',
          'ظرفشویی',
          'اجاق',
          'تلویزیون',
          'جاروبرقی',
        ];

      case 'HARDWARE':
        return const ['ابزار دستی', 'ابزار برقی', 'پیچ و مهره', 'یراق', 'رنگ'];

      case 'BUILDING_MATERIALS':
        return const ['سیمان', 'گچ', 'آجر', 'بلوک', 'کاشی', 'سرامیک', 'لوله'];

      case 'ELECTRICAL_CONTRACTOR':
        return const ['کابل', 'کلید و پریز', 'چراغ', 'فیوز', 'تابلو برق'];

      case 'PLUMBING':
        return const ['لوله', 'اتصالات', 'شیرآلات', 'پمپ', 'تجهیزات بهداشتی'];

      case 'HVAC':
        return const ['کولر', 'اسپیلت', 'بخاری', 'پکیج', 'فن', 'قطعات'];

      case 'BEAUTY_SALON':
        return const ['مو', 'پوست', 'ناخن', 'میکاپ', 'ابرو', 'عروس'];

      case 'BARBERSHOP':
        return const ['کوتاهی', 'اصلاح', 'رنگ', 'داماد', 'مراقبت مو'];

      case 'TAILOR':
        return const [
          'دوخت لباس',
          'تعمیرات لباس',
          'لباس مردانه',
          'لباس زنانه',
          'لباس مجلسی',
        ];

      case 'LAUNDRY':
        return const ['شستشو', 'اتو', 'خشکشویی', 'پتو', 'پرده', 'لباس مجلسی'];

      case 'SHOE_REPAIR':
        return const [
          'تعمیر کفش',
          'تعمیر کیف',
          'تعویض کفی',
          'رنگ‌کاری',
          'دوخت',
        ];

      case 'PET_SHOP':
        return const [
          'غذا',
          'لوازم نگهداری',
          'اسباب‌بازی',
          'بهداشت',
          'تجهیزات',
        ];

      case 'VETERINARY':
        return const ['دارو', 'معاینه', 'واکسن', 'جراحی', 'آزمایش'];

      case 'REAL_ESTATE':
        return const ['فروش ملک', 'خرید ملک', 'رهن', 'اجاره', 'زمین', 'تجاری'];

      case 'INSURANCE':
        return const [
          'شخص ثالث',
          'بدنه',
          'درمان',
          'عمر',
          'مسئولیت',
          'آتش‌سوزی',
        ];

      case 'ACCOUNTING_OFFICE':
        return const ['حسابداری', 'مالیات', 'حقوق', 'گزارش مالی', 'اظهارنامه'];

      case 'LEGAL_OFFICE':
        return const ['قرارداد', 'مشاوره', 'پرونده', 'دادخواست', 'وکالت'];

      case 'TRANSLATION':
        return const ['ترجمه رسمی', 'ترجمه عمومی', 'ترجمه تخصصی', 'آموزش زبان'];

      case 'TRAINING':
        return const ['کلاس خصوصی', 'کلاس گروهی', 'آموزش آنلاین', 'دوره تخصصی'];

      case 'TRAVEL_AGENCY':
        return const ['تور', 'پرواز', 'هتل', 'بیمه مسافرتی', 'ویزا'];

      case 'DELIVERY':
        return const ['پیک', 'ارسال شهری', 'ارسال بین‌شهری', 'مرسوله'];

      case 'FITNESS':
        return const [
          'عضویت',
          'کارت ماهانه',
          'کارت سالانه',
          'تمرین خصوصی',
          'فروش مکمل',
        ];

      case 'GENERAL':
      default:
        return const ['عمومی', 'سایر'];
    }
  }

  // --------------------------------------------------------------------------
  // Service catalog per business
  // --------------------------------------------------------------------------

  static List<String> _servicesForCode(String code) {
    switch (code) {
      case 'WATCH':
        return const ['تعویض باتری', 'تعمیر ساعت', 'تنظیم بند', 'تعویض شیشه'];

      case 'OPTICAL':
        return const ['تعیین نمره', 'تراش عدسی', 'تعویض عدسی', 'تنظیم فریم'];

      case 'COMPUTER_REPAIR':
        return const [
          'نصب ویندوز',
          'نصب نرم‌افزار',
          'تعمیر سخت‌افزار',
          'بازیابی اطلاعات',
          'سرویس لپ‌تاپ',
        ];

      case 'PRINT_SERVICES':
        return const [
          'پرینت رنگی',
          'پرینت سیاه‌وسفید',
          'کپی',
          'اسکن',
          'صحافی',
          'لمینت',
        ];

      case 'NET_CAFE':
        return const [
          'ثبت‌نام اینترنتی',
          'خدمات سامانه‌ها',
          'پرینت',
          'کپی',
          'اسکن',
          'تایپ',
        ];

      case 'PHOTOGRAPHY':
        return const [
          'عکس پرسنلی',
          'عکاسی کودک',
          'عکاسی مراسم',
          'رتوش عکس',
          'چاپ عکس',
        ];

      case 'GAME_CLUB':
        return const [
          'اجاره ساعتی کنسول',
          'عضویت',
          'بازی گروهی',
          'رزرو دستگاه',
        ];

      case 'VIDEO_CLUB':
        return const ['عضویت', 'اجاره فیلم', 'اجاره بازی', 'اشتراک'];

      case 'AUTO_ELECTRICAL':
        return const ['دیاگ', 'رفع عیب برق', 'نصب تجهیزات', 'تعویض باتری'];

      case 'OIL_CHANGE':
        return const [
          'تعویض روغن',
          'تعویض فیلتر',
          'سرویس دوره‌ای',
          'بازدید خودرو',
        ];

      case 'CAR_AUDIO':
        return const [
          'نصب سیستم صوتی',
          'نصب مانیتور',
          'نصب دوربین',
          'نصب آمپلی‌فایر',
        ];

      case 'CAR_TINT':
        return const ['نصب شیشه دودی', 'نصب کاور', 'نصب آپشن', 'پولیش'];

      case 'MECHANIC':
        return const [
          'دیاگ',
          'سرویس دوره‌ای',
          'تعمیر موتور',
          'تعمیر گیربکس',
          'تعمیر ترمز',
        ];

      case 'TIRE':
        return const [
          'تعویض لاستیک',
          'پنچرگیری',
          'آپارات',
          'بالانس',
          'تنظیم فرمان',
        ];

      case 'CAR_WASH_DETAILING':
        return const [
          'کارواش',
          'صفرشویی',
          'دیتیلینگ',
          'پولیش',
          'سرامیک',
          'واکس',
        ];

      case 'AUTO_BODY_PAINT':
        return const ['صافکاری', 'نقاشی', 'رنگ‌کاری', 'لیسه‌گیری', 'پولیش'];

      case 'ELECTRICAL_CONTRACTOR':
        return const [
          'نصب برق',
          'رفع عیب',
          'سیم‌کشی',
          'نصب تابلو',
          'نصب روشنایی',
        ];

      case 'PLUMBING':
        return const ['رفع نشتی', 'نصب شیرآلات', 'لوله‌کشی', 'نصب پمپ'];

      case 'HVAC':
        return const [
          'نصب کولر',
          'سرویس کولر',
          'شارژ گاز',
          'تعمیر پکیج',
          'سرویس بخاری',
        ];

      case 'BEAUTY_SALON':
        return const [
          'کوتاهی مو',
          'رنگ مو',
          'میکاپ',
          'شینیون',
          'ناخن',
          'فیشال',
          'خدمات عروس',
        ];

      case 'BARBERSHOP':
        return const ['کوتاهی', 'اصلاح', 'رنگ', 'داماد', 'پاکسازی پوست'];

      case 'TAILOR':
        return const ['دوخت', 'تعمیر لباس', 'تنگ و گشاد کردن', 'تعویض زیپ'];

      case 'LAUNDRY':
        return const ['خشکشویی', 'شستشو', 'اتو', 'شستشوی پرده', 'شستشوی پتو'];

      case 'SHOE_REPAIR':
        return const [
          'تعمیر کفش',
          'تعمیر کیف',
          'تعویض کفی',
          'رنگ‌کاری',
          'دوخت',
        ];

      case 'VETERINARY':
        return const ['معاینه', 'واکسن', 'جراحی', 'آزمایش', 'پانسیون'];

      case 'REAL_ESTATE':
        return const [
          'مشاوره خرید',
          'مشاوره فروش',
          'مشاوره اجاره',
          'کارشناسی ملک',
        ];

      case 'INSURANCE':
        return const ['صدور بیمه', 'تمدید بیمه', 'مشاوره بیمه', 'پیگیری خسارت'];

      case 'ACCOUNTING_OFFICE':
        return const [
          'تنظیم اظهارنامه',
          'خدمات حسابداری',
          'خدمات مالیاتی',
          'محاسبه حقوق',
        ];

      case 'LEGAL_OFFICE':
        return const [
          'مشاوره حقوقی',
          'تنظیم قرارداد',
          'تنظیم دادخواست',
          'وکلای پرونده',
        ];

      case 'TRANSLATION':
        return const ['ترجمه رسمی', 'ترجمه تخصصی', 'ترجمه عمومی', 'آموزش زبان'];

      case 'TRAINING':
        return const ['کلاس خصوصی', 'کلاس گروهی', 'مشاوره آموزشی', 'آزمون'];

      case 'TRAVEL_AGENCY':
        return const [
          'رزرو بلیت',
          'رزرو هتل',
          'تور',
          'خدمات ویزا',
          'بیمه مسافرتی',
        ];

      case 'DELIVERY':
        return const [
          'ارسال شهری',
          'ارسال فوری',
          'ارسال بین‌شهری',
          'رهگیری مرسوله',
        ];

      case 'FITNESS':
        return const [
          'عضویت ماهانه',
          'عضویت سالانه',
          'مربی خصوصی',
          'برنامه تمرینی',
        ];

      // فروشگاه‌هایی که عمدتاً محصول می‌فروشند
      case 'SUPERMARKET':
      case 'GROCERY':
      case 'CLOTHING':
      case 'SHOES_BAGS':
      case 'JEWELRY_GOLD':
      case 'SILVER':
      case 'COSMETICS':
      case 'PHARMACY':
      case 'MEDICAL_SUPPLIES':
      case 'BAKERY':
      case 'CONFECTIONERY':
      case 'MOBILE':
      case 'MOBILE_ACCESSORIES':
      case 'COMPUTER':
      case 'STATIONERY':
      case 'FURNITURE':
      case 'CURTAIN':
      case 'HOME_APPLIANCE':
      case 'HARDWARE':
      case 'BUILDING_MATERIALS':
      case 'PET_SHOP':
      case 'GENERAL':
      default:
        return const [];
    }
  }

  // --------------------------------------------------------------------------
  // Icon mapping
  // --------------------------------------------------------------------------

  static IconData iconFor(String code) {
    switch (code) {
      case 'SUPERMARKET':
      case 'GROCERY':
        return Icons.shopping_cart_outlined;

      case 'CLOTHING':
      case 'SHOES_BAGS':
      case 'TAILOR':
        return Icons.checkroom_outlined;

      case 'JEWELRY_GOLD':
      case 'SILVER':
      case 'WATCH':
        return Icons.watch_outlined;

      case 'COSMETICS':
      case 'BEAUTY_SALON':
      case 'BARBERSHOP':
        return Icons.face_retouching_natural_outlined;

      case 'PHARMACY':
        return Icons.local_pharmacy_outlined;

      case 'MEDICAL_SUPPLIES':
      case 'VETERINARY':
        return Icons.medical_services_outlined;

      case 'OPTICAL':
        return Icons.remove_red_eye_outlined;

      case 'BAKERY':
      case 'CONFECTIONERY':
        return Icons.bakery_dining_outlined;

      case 'RESTAURANT':
      case 'FAST_FOOD':
      case 'CAFE':
      case 'CATERING':
        return Icons.restaurant_outlined;

      case 'MOBILE':
      case 'MOBILE_ACCESSORIES':
        return Icons.phone_android_outlined;

      case 'COMPUTER':
      case 'COMPUTER_REPAIR':
        return Icons.computer_outlined;

      case 'PRINT_SERVICES':
      case 'NET_CAFE':
      case 'STATIONERY':
        return Icons.print_outlined;

      case 'PHOTOGRAPHY':
        return Icons.photo_camera_outlined;

      case 'GAME_CLUB':
      case 'VIDEO_CLUB':
        return Icons.sports_esports_outlined;

      case 'AUTO_SPARE_PARTS':
      case 'AUTO_ELECTRICAL':
      case 'OIL_CHANGE':
      case 'CAR_AUDIO':
      case 'CAR_TINT':
      case 'MECHANIC':
      case 'TIRE':
      case 'CAR_WASH_DETAILING':
      case 'AUTO_BODY_PAINT':
        return Icons.directions_car_outlined;

      case 'FURNITURE':
      case 'CURTAIN':
        return Icons.weekend_outlined;

      case 'HOME_APPLIANCE':
        return Icons.kitchen_outlined;

      case 'HARDWARE':
        return Icons.handyman_outlined;

      case 'BUILDING_MATERIALS':
      case 'ELECTRICAL_CONTRACTOR':
      case 'PLUMBING':
      case 'HVAC':
        return Icons.construction_outlined;

      case 'LAUNDRY':
        return Icons.local_laundry_service_outlined;

      case 'SHOE_REPAIR':
        return Icons.build_outlined;

      case 'PET_SHOP':
        return Icons.pets_outlined;

      case 'REAL_ESTATE':
        return Icons.home_work_outlined;

      case 'INSURANCE':
        return Icons.health_and_safety_outlined;

      case 'ACCOUNTING_OFFICE':
        return Icons.account_balance_outlined;

      case 'LEGAL_OFFICE':
        return Icons.gavel_outlined;

      case 'TRANSLATION':
      case 'TRAINING':
        return Icons.school_outlined;

      case 'TRAVEL_AGENCY':
        return Icons.flight_takeoff_outlined;

      case 'DELIVERY':
        return Icons.local_shipping_outlined;

      case 'FITNESS':
        return Icons.fitness_center_outlined;

      case 'GENERAL':
      default:
        return Icons.storefront_outlined;
    }
  }
}
