// store_config_fixed.dart
class StoreConfig {
  final int id;
  final String storeName;
  final String
      storeType; // SUPERMARKET, CLOTHING, ELECTRONICS, HARDWARE, CAFE, GENERAL
  final String businessTitle;
  final String logoBase64;
  final String colorTheme; // EMERALD, OCEAN, GOLDEN, PURPLE, RUBY
  final String currency; // تومان, ریال, $
  final double taxPercentage;
  final bool isConfigured;
  final bool autoBackupEnabled;
  final String layoutStyle; // GRID, LIST, TOUCH_TILES
  final int lastBackupTimestamp; // milliseconds since epoch
  final int morningStartHour;
  final int morningEndHour;
  final int eveningStartHour;
  final int eveningEndHour;
  final bool isDarkMode;
  final String storePhone;
  final double profitCoefficient;
  final String endShiftAlertTime;
  final String printPaperSize; // A4, A5, LETTER, LEGAL, B5, R58, R80, CUSTOM
  final String printOrientation; // PORTRAIT / LANDSCAPE
  final double printMarginMm;
  final double customPaperWidthMm;
  final double customPaperHeightMm;

  StoreConfig({
    this.id = 1,
    required this.storeName,
    required this.storeType,
    this.businessTitle = 'فروشگاه',
    this.logoBase64 = '',
    required this.colorTheme,
    required this.currency,
    this.taxPercentage = 0.0,
    this.isConfigured = false,
    this.autoBackupEnabled = true,
    this.layoutStyle = "GRID",
    int? lastBackupTimestamp,
    this.morningStartHour = 6,
    this.morningEndHour = 15,
    this.eveningStartHour = 15,
    this.eveningEndHour = 24,
    this.isDarkMode = false,
    this.storePhone = '',
    this.profitCoefficient = 0.22,
    this.endShiftAlertTime = '21:00',
    this.printPaperSize = 'A4',
    this.printOrientation = 'PORTRAIT',
    this.printMarginMm = 8.0,
    this.customPaperWidthMm = 210.0,
    this.customPaperHeightMm = 297.0,
  }) : lastBackupTimestamp =
            lastBackupTimestamp ?? DateTime.now().millisecondsSinceEpoch;

  /// Convenience getter for DateTime representation of last backup
  DateTime get lastBackupAt =>
      DateTime.fromMillisecondsSinceEpoch(lastBackupTimestamp);

  /// Convert to DB-friendly map (booleans as ints)
  Map<String, dynamic> toMap() => {
        'id': id,
        'storeName': storeName,
        'storeType': storeType,
        'businessTitle': businessTitle,
        'logoBase64': logoBase64,
        'colorTheme': colorTheme,
        'currency': currency,
        'taxPercentage': taxPercentage,
        'isConfigured': isConfigured ? 1 : 0,
        'autoBackupEnabled': autoBackupEnabled ? 1 : 0,
        'layoutStyle': layoutStyle,
        'lastBackupTimestamp': lastBackupTimestamp,
        'morningStartHour': morningStartHour,
        'morningEndHour': morningEndHour,
        'eveningStartHour': eveningStartHour,
        'eveningEndHour': eveningEndHour,
        'isDarkMode': isDarkMode ? 1 : 0,
        'storePhone': storePhone,
        'profitCoefficient': profitCoefficient,
        'endShiftAlertTime': endShiftAlertTime,
        'printPaperSize': printPaperSize,
        'printOrientation': printOrientation,
        'printMarginMm': printMarginMm,
        'customPaperWidthMm': customPaperWidthMm,
        'customPaperHeightMm': customPaperHeightMm,
      };

  /// Robust factory that tolerates different DB value types and missing keys
  factory StoreConfig.fromMap(Map<String, dynamic> m) {
    int _int(dynamic v, [int fallback = 0]) {
      if (v == null) return fallback;
      if (v is int) return v;
      if (v is double) return v.toInt();
      if (v is String) return int.tryParse(v) ?? fallback;
      return fallback;
    }

    double _dbl(dynamic v, [double fallback = 0.0]) {
      if (v == null) return fallback;
      if (v is double) return v;
      if (v is int) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? fallback;
      return fallback;
    }

    bool _boolFromIntOrBool(dynamic v, [bool fallback = false]) {
      if (v == null) return fallback;
      if (v is bool) return v;
      if (v is int) return v == 1;
      if (v is String) {
        final s = v.trim().toLowerCase();
        if (s == '1' || s == 'true') return true;
        if (s == '0' || s == 'false') return false;
      }
      return fallback;
    }

    return StoreConfig(
      id: _int(m['id'], 1),
      storeName: (m['storeName'] as String?)?.trim() ?? 'فروشگاه من',
      storeType: (m['storeType'] as String?)?.trim() ?? 'GENERAL',
      businessTitle: (m['businessTitle'] as String?)?.trim() ?? 'فروشگاه',
      logoBase64: (m['logoBase64'] as String?) ?? '',
      colorTheme: (m['colorTheme'] as String?)?.trim() ?? 'EMERALD',
      currency: (m['currency'] as String?)?.trim() ?? 'تومان',
      taxPercentage: _dbl(m['taxPercentage'], 0.0),
      isConfigured: _boolFromIntOrBool(m['isConfigured'], false),
      autoBackupEnabled: _boolFromIntOrBool(m['autoBackupEnabled'], true),
      layoutStyle: (m['layoutStyle'] as String?)?.trim() ?? 'GRID',
      lastBackupTimestamp:
          _int(m['lastBackupTimestamp'], DateTime.now().millisecondsSinceEpoch),
      morningStartHour: _int(m['morningStartHour'], 6),
      morningEndHour: _int(m['morningEndHour'], 15),
      eveningStartHour: _int(m['eveningStartHour'], 15),
      eveningEndHour: _int(m['eveningEndHour'], 24),
      isDarkMode: _boolFromIntOrBool(m['isDarkMode'], false),
      storePhone: (m['storePhone'] as String?)?.trim() ?? '',
      profitCoefficient: _dbl(m['profitCoefficient'], 0.22),
      endShiftAlertTime: (m['endShiftAlertTime'] as String?)?.trim() ?? '21:00',
      printPaperSize: (m['printPaperSize'] as String?)?.trim() ?? 'A4',
      printOrientation: (m['printOrientation'] as String?)?.trim() ?? 'PORTRAIT',
      printMarginMm: _dbl(m['printMarginMm'], 8.0),
      customPaperWidthMm: _dbl(m['customPaperWidthMm'], 210.0),
      customPaperHeightMm: _dbl(m['customPaperHeightMm'], 297.0),
    );
  }

  /// JSON helpers (useful for backups / network)
  Map<String, dynamic> toJson() => {
        'id': id,
        'storeName': storeName,
        'storeType': storeType,
        'businessTitle': businessTitle,
        'logoBase64': logoBase64,
        'colorTheme': colorTheme,
        'currency': currency,
        'taxPercentage': taxPercentage,
        'isConfigured': isConfigured,
        'autoBackupEnabled': autoBackupEnabled,
        'layoutStyle': layoutStyle,
        'lastBackupTimestamp': lastBackupTimestamp,
        'morningStartHour': morningStartHour,
        'morningEndHour': morningEndHour,
        'eveningStartHour': eveningStartHour,
        'eveningEndHour': eveningEndHour,
        'isDarkMode': isDarkMode,
        'storePhone': storePhone,
        'profitCoefficient': profitCoefficient,
        'endShiftAlertTime': endShiftAlertTime,
        'printPaperSize': printPaperSize,
        'printOrientation': printOrientation,
        'printMarginMm': printMarginMm,
        'customPaperWidthMm': customPaperWidthMm,
        'customPaperHeightMm': customPaperHeightMm,
      };

  factory StoreConfig.fromJson(Map<String, dynamic> j) {
    return StoreConfig.fromMap(j.map((k, v) => MapEntry(k, v)));
  }

  /// copyWith allows updating any field; pass null to keep existing value.
  StoreConfig copyWith({
    String? storeName,
    String? storeType,
    String? businessTitle,
    String? logoBase64,
    String? colorTheme,
    String? currency,
    double? taxPercentage,
    bool? isConfigured,
    bool? autoBackupEnabled,
    String? layoutStyle,
    int? lastBackupTimestamp,
    int? morningStartHour,
    int? morningEndHour,
    int? eveningStartHour,
    int? eveningEndHour,
    bool? isDarkMode,
    String? storePhone,
    double? profitCoefficient,
    String? endShiftAlertTime,
    String? printPaperSize,
    String? printOrientation,
    double? printMarginMm,
    double? customPaperWidthMm,
    double? customPaperHeightMm,
  }) =>
      StoreConfig(
        id: id,
        storeName: storeName ?? this.storeName,
        storeType: storeType ?? this.storeType,
        businessTitle: businessTitle ?? this.businessTitle,
        logoBase64: logoBase64 ?? this.logoBase64,
        colorTheme: colorTheme ?? this.colorTheme,
        currency: currency ?? this.currency,
        taxPercentage: taxPercentage ?? this.taxPercentage,
        isConfigured: isConfigured ?? this.isConfigured,
        autoBackupEnabled: autoBackupEnabled ?? this.autoBackupEnabled,
        layoutStyle: layoutStyle ?? this.layoutStyle,
        lastBackupTimestamp: lastBackupTimestamp ?? this.lastBackupTimestamp,
        morningStartHour: morningStartHour ?? this.morningStartHour,
        morningEndHour: morningEndHour ?? this.morningEndHour,
        eveningStartHour: eveningStartHour ?? this.eveningStartHour,
        eveningEndHour: eveningEndHour ?? this.eveningEndHour,
        isDarkMode: isDarkMode ?? this.isDarkMode,
        storePhone: storePhone ?? this.storePhone,
        profitCoefficient: profitCoefficient ?? this.profitCoefficient,
        endShiftAlertTime: endShiftAlertTime ?? this.endShiftAlertTime,
        printPaperSize: printPaperSize ?? this.printPaperSize,
        printOrientation: printOrientation ?? this.printOrientation,
        printMarginMm: printMarginMm ?? this.printMarginMm,
        customPaperWidthMm: customPaperWidthMm ?? this.customPaperWidthMm,
        customPaperHeightMm: customPaperHeightMm ?? this.customPaperHeightMm,
      );

  /// Basic validation helper for shift hours
  bool validateShiftHours() {
    bool validHour(int h) => h >= 0 && h <= 24;
    return validHour(morningStartHour) &&
        validHour(morningEndHour) &&
        validHour(eveningStartHour) &&
        validHour(eveningEndHour) &&
        (morningStartHour < morningEndHour) &&
        (eveningStartHour < eveningEndHour);
  }

  @override
  String toString() {
    return 'StoreConfig(id: $id, storeName: $storeName, storeType: $storeType, businessTitle: $businessTitle, colorTheme: $colorTheme, currency: $currency, taxPercentage: $taxPercentage, isConfigured: $isConfigured, autoBackupEnabled: $autoBackupEnabled, layoutStyle: $layoutStyle, lastBackupTimestamp: $lastBackupTimestamp, morningStartHour: $morningStartHour, morningEndHour: $morningEndHour, eveningStartHour: $eveningStartHour, eveningEndHour: $eveningEndHour, isDarkMode: $isDarkMode)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoreConfig &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          storeName == other.storeName &&
          storeType == other.storeType &&
          businessTitle == other.businessTitle &&
          logoBase64 == other.logoBase64 &&
          colorTheme == other.colorTheme &&
          currency == other.currency &&
          taxPercentage == other.taxPercentage &&
          isConfigured == other.isConfigured &&
          autoBackupEnabled == other.autoBackupEnabled &&
          layoutStyle == other.layoutStyle &&
          lastBackupTimestamp == other.lastBackupTimestamp &&
          morningStartHour == other.morningStartHour &&
          morningEndHour == other.morningEndHour &&
          eveningStartHour == other.eveningStartHour &&
          eveningEndHour == other.eveningEndHour &&
          isDarkMode == other.isDarkMode &&
          storePhone == other.storePhone &&
          profitCoefficient == other.profitCoefficient &&
          endShiftAlertTime == other.endShiftAlertTime &&
          printPaperSize == other.printPaperSize &&
          printOrientation == other.printOrientation &&
          printMarginMm == other.printMarginMm &&
          customPaperWidthMm == other.customPaperWidthMm &&
          customPaperHeightMm == other.customPaperHeightMm;

  @override
  int get hashCode =>
      id.hashCode ^
      storeName.hashCode ^
      storeType.hashCode ^
      businessTitle.hashCode ^
      logoBase64.hashCode ^
      colorTheme.hashCode ^
      currency.hashCode ^
      taxPercentage.hashCode ^
      isConfigured.hashCode ^
      autoBackupEnabled.hashCode ^
      layoutStyle.hashCode ^
      lastBackupTimestamp.hashCode ^
      morningStartHour.hashCode ^
      morningEndHour.hashCode ^
      eveningStartHour.hashCode ^
      eveningEndHour.hashCode ^
      isDarkMode.hashCode ^
      storePhone.hashCode ^
      profitCoefficient.hashCode ^
      endShiftAlertTime.hashCode ^
      printPaperSize.hashCode ^
      printOrientation.hashCode ^
      printMarginMm.hashCode ^
      customPaperWidthMm.hashCode ^
      customPaperHeightMm.hashCode;
}
