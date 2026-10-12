// ============================================================================
// StoreTheme - Modern Material 3 theme for StoreMaster Pro
// Supports light/dark mode and existing color palettes.
// ============================================================================
import 'package:flutter/material.dart';

class AppColors {
  static const professionalPrimary = Color(0xFF6750A4);
  static const professionalSecondary = Color(0xFF625B71);
  static const professionalTertiary = Color(0xFF7D5260);

  static const emeraldPrimary = Color(0xFF00897B);
  static const emeraldSecondary = Color(0xFF00695C);
  static const emeraldTertiary = Color(0xFFFFB300);

  static const oceanPrimary = Color(0xFF0288D1);
  static const oceanSecondary = Color(0xFF01579B);
  static const oceanTertiary = Color(0xFF00BCD4);

  static const goldenPrimary = Color(0xFFD81B60);
  static const goldenSecondary = Color(0xFF880E4F);
  static const goldenTertiary = Color(0xFFFFB300);

  static const rubyPrimary = Color(0xFFD32F2F);
  static const rubySecondary = Color(0xFF880E4F);
  static const rubyTertiary = Color(0xFFFF9800);
}

class StoreTheme {
  static ThemeData buildTheme({
    required String themeName,
    required bool darkTheme,
  }) {
    final upper = themeName.trim().toUpperCase();

    Color primary;
    Color secondary;
    Color tertiary;

    switch (upper) {
      case 'EMERALD':
        primary = AppColors.emeraldPrimary;
        secondary = AppColors.emeraldSecondary;
        tertiary = AppColors.emeraldTertiary;
        break;
      case 'OCEAN':
        primary = AppColors.oceanPrimary;
        secondary = AppColors.oceanSecondary;
        tertiary = AppColors.oceanTertiary;
        break;
      case 'GOLDEN':
        primary = AppColors.goldenPrimary;
        secondary = AppColors.goldenSecondary;
        tertiary = AppColors.goldenTertiary;
        break;
      case 'RUBY':
        primary = AppColors.rubyPrimary;
        secondary = AppColors.rubySecondary;
        tertiary = AppColors.rubyTertiary;
        break;
      default:
        primary = AppColors.professionalPrimary;
        secondary = AppColors.professionalSecondary;
        tertiary = AppColors.professionalTertiary;
    }

    final ColorScheme scheme = darkTheme
        ? ColorScheme.dark(
            primary: primary,
            onPrimary: Colors.white,
            primaryContainer: primary.withValues(alpha: 0.28),
            onPrimaryContainer: Colors.white,
            secondary: secondary,
            onSecondary: Colors.white,
            secondaryContainer: secondary.withValues(alpha: 0.28),
            onSecondaryContainer: Colors.white,
            tertiary: tertiary,
            onTertiary: Colors.white,
            tertiaryContainer: tertiary.withValues(alpha: 0.22),
            onTertiaryContainer: Colors.white,
            surface: const Color(0xFF111318),
            surfaceContainerLowest: const Color(0xFF0B0D10),
            surfaceContainerLow: const Color(0xFF15181D),
            surfaceContainer: const Color(0xFF1A1D23),
            surfaceContainerHigh: const Color(0xFF22262D),
            surfaceContainerHighest: const Color(0xFF2A2F37),
            onSurface: const Color(0xFFF1F3F7),
            onSurfaceVariant: const Color(0xFFBEC4CF),
            outline: const Color(0xFF6E7480),
            outlineVariant: const Color(0xFF3C424B),
            error: const Color(0xFFFFB4AB),
            onError: const Color(0xFF690005),
            errorContainer: const Color(0xFF410002),
            onErrorContainer: const Color(0xFFFFDAD6),
          )
        : ColorScheme.light(
            primary: primary,
            onPrimary: Colors.white,
            primaryContainer: primary.withValues(alpha: 0.13),
            onPrimaryContainer: primary,
            secondary: secondary,
            onSecondary: Colors.white,
            secondaryContainer: secondary.withValues(alpha: 0.10),
            onSecondaryContainer: secondary,
            tertiary: tertiary,
            onTertiary: Colors.white,
            tertiaryContainer: tertiary.withValues(alpha: 0.10),
            onTertiaryContainer: tertiary,
            surface: const Color(0xFFF7F8FA),
            surfaceContainerLowest: Colors.white,
            surfaceContainerLow: const Color(0xFFFAFAFB),
            surfaceContainer: const Color(0xFFF2F3F6),
            surfaceContainerHigh: const Color(0xFFEBEDF1),
            surfaceContainerHighest: const Color(0xFFE3E6EB),
            onSurface: const Color(0xFF1B1D21),
            onSurfaceVariant: const Color(0xFF606570),
            outline: const Color(0xFF7B8089),
            outlineVariant: const Color(0xFFD4D7DD),
            error: const Color(0xFFBA1A1A),
            onError: Colors.white,
            errorContainer: const Color(0xFFFFDAD6),
            onErrorContainer: const Color(0xFF410002),
          );

    const radius = 14.0;

    final baseText = darkTheme
        ? const TextTheme(
            displayLarge: TextStyle(fontWeight: FontWeight.w800),
            displayMedium: TextStyle(fontWeight: FontWeight.w800),
            displaySmall: TextStyle(fontWeight: FontWeight.w800),
            headlineLarge: TextStyle(fontWeight: FontWeight.w800),
            headlineMedium: TextStyle(fontWeight: FontWeight.w800),
            headlineSmall: TextStyle(fontWeight: FontWeight.w800),
            titleLarge: TextStyle(fontWeight: FontWeight.w800),
            titleMedium: TextStyle(fontWeight: FontWeight.w700),
            titleSmall: TextStyle(fontWeight: FontWeight.w700),
            bodyLarge: TextStyle(fontWeight: FontWeight.w500),
            bodyMedium: TextStyle(fontWeight: FontWeight.w500),
            bodySmall: TextStyle(fontWeight: FontWeight.w500),
            labelLarge: TextStyle(fontWeight: FontWeight.w700),
            labelMedium: TextStyle(fontWeight: FontWeight.w700),
            labelSmall: TextStyle(fontWeight: FontWeight.w700),
          )
        : const TextTheme(
            displayLarge: TextStyle(fontWeight: FontWeight.w800),
            displayMedium: TextStyle(fontWeight: FontWeight.w800),
            displaySmall: TextStyle(fontWeight: FontWeight.w800),
            headlineLarge: TextStyle(fontWeight: FontWeight.w800),
            headlineMedium: TextStyle(fontWeight: FontWeight.w800),
            headlineSmall: TextStyle(fontWeight: FontWeight.w800),
            titleLarge: TextStyle(fontWeight: FontWeight.w800),
            titleMedium: TextStyle(fontWeight: FontWeight.w700),
            titleSmall: TextStyle(fontWeight: FontWeight.w700),
            bodyLarge: TextStyle(fontWeight: FontWeight.w500),
            bodyMedium: TextStyle(fontWeight: FontWeight.w500),
            bodySmall: TextStyle(fontWeight: FontWeight.w500),
            labelLarge: TextStyle(fontWeight: FontWeight.w700),
            labelMedium: TextStyle(fontWeight: FontWeight.w700),
            labelSmall: TextStyle(fontWeight: FontWeight.w700),
          );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: darkTheme ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: scheme.surface,
      fontFamily: 'Tahoma',
      textTheme: baseText,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      splashFactory: InkSparkle.splashFactory,
      cardTheme: CardThemeData(
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 5),
        color: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withValues(alpha: darkTheme ? 0.18 : 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: darkTheme ? 0.55 : 0.75),
          ),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontFamily: 'Tahoma',
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainer,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: scheme.error, width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(0, 46),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          side: BorderSide(color: scheme.outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 42),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        side: BorderSide(color: scheme.outlineVariant),
        backgroundColor: scheme.surfaceContainer,
        selectedColor: scheme.primaryContainer,
        labelStyle: TextStyle(color: scheme.onSurface),
        secondaryLabelStyle: TextStyle(color: scheme.onSurfaceVariant),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        elevation: 12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        modalBackgroundColor: scheme.surfaceContainerLow,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(left: Radius.circular(20)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            color: scheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surfaceContainerLow,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: darkTheme ? const Color(0xFFE6E1E9) : const Color(0xFF2C2F34),
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: TextStyle(
          color: darkTheme ? Colors.black : Colors.white,
          fontFamily: 'Tahoma',
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHighest,
        circularTrackColor: scheme.surfaceContainerHighest,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll(scheme.surfaceContainer),
        dataRowColor: WidgetStatePropertyAll(scheme.surfaceContainerLow),
        dividerThickness: 0.6,
        headingTextStyle: TextStyle(
          color: scheme.onSurface,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
