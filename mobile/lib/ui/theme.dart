import 'package:flutter/material.dart';

/// Dark, minimal palette. Colors are defined once here so a light theme can be added later.
class AppColors {
  static const background = Color(0xFF000000);
  static const surface = Color(0xFF151517);
  static const surfaceHigh = Color(0xFF222226);
  static const border = Color(0xFF2C2C30);
  static const textPrimary = Color(0xFFF5F5F7);
  static const textSecondary = Color(0xFF9A9AA0);
  static const accent = Color(0xFFB8F35A); // restrained lime
  static const accentInk = Color(0xFF0B0B0C);
  static const blue = Color(0xFF64B5F6);
  static const orange = Color(0xFFFFB454);
  static const red = Color(0xFFFF6B6B);
}

/// Liquid Glass tokens of the Fitness Formula brand (client home screen and tab bar).
class Brand {
  static const background = Color(0xFF050507);
  static const accent = Color(0xFF1FACD8);
  static const accentDark = Color(0xFF1386B8);
  static const buttonGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF2BBBE8), Color(0xFF1386B8)],
  );

  static const textPrimary = Colors.white;
  static final textSecondary = Colors.white.withValues(alpha: 0.6);
  static final textTertiary = Colors.white.withValues(alpha: 0.4);

  // Glass: white 11% -> 4% fill, 1px white 14% stroke, background blur ~28 (sigma = blur / 2).
  static final glassGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Colors.white.withValues(alpha: 0.11), Colors.white.withValues(alpha: 0.04)],
  );
  static final glassStroke = Colors.white.withValues(alpha: 0.14);
  static const glassBlurSigma = 14.0;

  static const radiusHero = 28.0;
  static const radiusCard = 22.0;
  static const sidePadding = 20.0;
  static const sectionGap = 22.0;

  static const red = Color(0xFFFF5A5F);
  static const redText = Color(0xFFFF8A8D);
  static const blue = Color(0xFF4F8BFF);
  static const blueIcon = Color(0xFF6FA0FF);
  static const flame = Color(0xFFFF8A4C);
  static const trophy = Color(0xFFFFC93C);
  static const clock = Color(0xFF5AD2F4);
  static const glowBlue = Color(0xFF2340E0);
  static const glowCyan = Color(0xFF19C6E6);
  static const glowRoyal = Color(0xFF2B6BFF);
  static const purple = Color(0xFFB48CFF);
  static const success = Color(0xFF34D399);
  static const successText = Color(0xFF4ADE80);

  /// Floating tab bar geometry; screens under it reserve [tabBarReserve] plus the bottom safe area.
  static const tabBarHeight = 66.0;
  static const tabBarBottom = 14.0;
  static const tabBarReserve = tabBarHeight + tabBarBottom + 12;
}

ThemeData buildDarkTheme() {
  const scheme = ColorScheme.dark(
    primary: AppColors.accent,
    onPrimary: AppColors.accentInk,
    secondary: AppColors.blue,
    surface: AppColors.surface,
    onSurface: AppColors.textPrimary,
    error: AppColors.red,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: Brightness.dark);
  final text = base.textTheme.apply(bodyColor: AppColors.textPrimary, displayColor: AppColors.textPrimary);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.background,
    textTheme: text.copyWith(
      displaySmall: text.displaySmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.8),
      headlineMedium: text.headlineMedium?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.6),
      titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.3),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      bodyMedium: text.bodyMedium?.copyWith(color: AppColors.textPrimary),
      bodySmall: text.bodySmall?.copyWith(color: AppColors.textSecondary),
      labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
        color: AppColors.textPrimary,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.accent.withValues(alpha: 0.16),
      surfaceTintColor: Colors.transparent,
      height: 68,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: s.contains(WidgetState.selected) ? AppColors.accent : AppColors.textSecondary,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(color: s.contains(WidgetState.selected) ? AppColors.accent : AppColors.textSecondary),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceHigh,
      // Underline-style borders keep the floating label inside the filled box.
      border: UnderlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      enabledBorder: UnderlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      focusedBorder: UnderlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.accent, width: 2),
      ),
      errorBorder: UnderlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.red, width: 2),
      ),
      focusedErrorBorder: UnderlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.red, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: const TextStyle(color: AppColors.textSecondary),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        foregroundColor: AppColors.textPrimary,
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.surfaceHigh,
      contentTextStyle: const TextStyle(color: AppColors.textPrimary),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.accent : AppColors.surfaceHigh,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.accentInk : AppColors.textPrimary,
        ),
        side: const WidgetStatePropertyAll(BorderSide(color: AppColors.border)),
      ),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.border, space: 1),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    ),
  );
}
