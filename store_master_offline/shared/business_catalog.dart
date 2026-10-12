import 'package:flutter/material.dart';


class BusinessProfile {
  final String code;
  final String label;
  final IconData icon;
  final List<String> categories;
  final List<String> services;
  final String group;

  const BusinessProfile({
    required this.code,
    required this.label,
    this.icon = Icons.store,
    this.categories = const [],
    this.services = const [],
    this.group = 'فروشگاهی',
  });
}

// GENERATED FROM StoreMaster USER APP canonical catalog. Keep codes identical on all platforms.
class BusinessCatalog {
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

  static bool containsCode(String code) => codes.contains(code);

  // ============ بسته کمکی (بازسازی‌شده برای نسخه آفلاین) ============

  static IconData iconFor(String? code) {
    switch (code) {
      case 'SUPERMARKET':
      case 'GROCERY':
        return Icons.storefront;
      case 'CLOTHING':
      case 'SHOES_BAGS':
        return Icons.checkroom;
      case 'RESTAURANT':
      case 'FAST_FOOD':
      case 'CATERING':
      case 'BAKERY':
      case 'CONFECTIONERY':
        return Icons.restaurant;
      case 'CAFE':
        return Icons.local_cafe;
      case 'MOBILE':
      case 'MOBILE_ACCESSORIES':
        return Icons.smartphone;
      case 'COMPUTER':
      case 'COMPUTER_REPAIR':
      case 'PRINT_SERVICES':
      case 'NET_CAFE':
        return Icons.laptop;
      case 'PHARMACY':
      case 'MEDICAL_SUPPLIES':
      case 'OPTICAL':
        return Icons.local_pharmacy;
      case 'JEWELRY_GOLD':
      case 'SILVER':
      case 'WATCH':
        return Icons.diamond;
      case 'COSMETICS':
        return Icons.face_retouching_natural;
      case 'STATIONERY':
        return Icons.menu_book;
      case 'FURNITURE':
        return Icons.chair;
      default:
        if (code != null && code.startsWith('AUTO')) return Icons.directions_car;
        return Icons.store;
    }
  }

  static String groupOf(String? code) {
    if (code == null) return 'فروشگاهی';
    if (code.startsWith('AUTO') || code == 'TIRE' || code == 'MECHANIC' ||
        code == 'CAR_WASH_DETAILING' || code == 'AUTO_BODY_PAINT' ||
        code == 'OIL_CHANGE') {
      return 'خودرو';
    }
    const food = {
      'RESTAURANT', 'FAST_FOOD', 'CAFE', 'CATERING', 'BAKERY', 'CONFECTIONERY'
    };
    if (food.contains(code)) return 'رستوران و کافه';
    return 'فروشگاهی';
  }

  /// گروه‌بندی کسب‌وکارها بر اساس نوع (برای صفحه راه‌اندازی)
  static Map<String, List<BusinessProfile>> grouped() {
    final map = <String, List<BusinessProfile>>{};
    for (final p in profiles) {
      final code = '${p['code'] ?? ''}';
      final label = '${p['label'] ?? code}';
      final g = groupOf(code);
      final prof = BusinessProfile(
        code: code,
        label: label,
        icon: iconFor(code),
        categories: categoriesFor(code),
        services: servicesFor(code),
        group: g,
      );
      map.putIfAbsent(g, () => []).add(prof);
    }
    return map;
  }

  /// دسته‌بندی‌های پیشنهادی کالا بر اساس نوع کسب‌وکار
  static List<String> categoriesFor(String? storeType) {
    const table = <String, List<String>>{
      'SUPERMARKET': ['مواد غذایی', 'نوشیدنی', 'لبنیات', 'شوینده', 'تنقلات', 'کنسرو'],
      'GROCERY': ['مواد غذایی', 'نوشیدنی', 'خشکبار', 'تنقلات'],
      'CLOTHING': ['مردانه', 'زنانه', 'بچه‌گانه', 'شال و روسری'],
      'SHOES_BAGS': ['کفش مردانه', 'کفش زنانه', 'کیف', 'کوله'],
      'MOBILE': ['گوشی', 'تبلت', 'قطعات', 'لوازم جانبی'],
      'COMPUTER': ['لپ‌تاپ', 'کیس', 'مانیتور', 'قطعات', 'لوازم جانبی'],
      'PHARMACY': ['دارو', 'مکمل', 'بهداشتی', 'ملزومات پزشکی'],
      'COSMETICS': ['آرایش', 'پوست', 'مو', 'عطر'],
      'STATIONERY': ['نوشت‌افزار', 'کتاب', 'لوازم تحریر'],
      'RESTAURANT': ['غذا', 'نوشیدنی', 'پیش‌غذا', 'دسر'],
      'CAFE': ['قهوه', 'نوشیدنی', 'کیک', 'صبحانه'],
      'BAKERY': ['نان', 'شیرینی', 'خشکبار'],
      'JEWELRY_GOLD': ['طلا', 'سکه', 'جواهرات'],
    };
    return table[storeType] ?? const <String>[];
  }

  /// خدمات پیشنهادی بر اساس نوع کسب‌وکار
  static List<String> servicesFor(String? storeType) {
    const table = <String, List<String>>{
      'RESTAURANT': ['پیک', 'سرویس سالن'],
      'CAFE': ['پیک', 'سرویس سالن'],
      'FAST_FOOD': ['پیک', 'سرویس سالن'],
      'CATERING': ['سفارش مهمانی', 'پیک'],
      'COMPUTER_REPAIR': ['عیب‌یابی', 'نصب ویندوز', 'تعمیر'],
      'MOBILE': ['شارژ حساب', 'خرید آنلاین'],
      'PRINT_SERVICES': ['چاپ', 'کپی', 'صحافی', 'لمینت'],
      'PHOTOGRAPHY': ['عکاسی', 'چاپ عکس'],
      'AUTO_SPARE_PARTS': ['نصب', 'پیک'],
      'OIL_CHANGE': ['تعویض روغن', 'تعویض فیلتر'],
      'MECHANIC': ['سرویس دوره‌ای', 'عیب‌یابی'],
      'CAR_WASH_DETAILING': ['کارواش', 'دیتیلینگ', 'وکس'],
    };
    return table[storeType] ?? const <String>[];
  }

  /// عنوان فارسی برای یک نوع کسب‌وکار
  static String titleFor(String? storeType) {
    for (final p in profiles) {
      if ('${p['code'] ?? ''}' == storeType) return '${p['label'] ?? 'فروشگاه'}';
    }
    return 'فروشگاه';
  }
}
