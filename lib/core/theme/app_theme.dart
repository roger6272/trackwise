import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_colors.dart';

const _kThemeModeKey = '__theme_mode__';

/// App theme configuration matching the existing FlutterFlow theme.
///
/// Provides light and dark themes with the same colors and typography
/// as the original FlutterFlow theme for seamless migration.
class AppTheme {
  AppTheme._();

  static SharedPreferences? _prefs;

  /// Initialize theme (load saved theme mode)
  static Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Get the current theme mode from preferences
  static ThemeMode get themeMode {
    final darkMode = _prefs?.getBool(_kThemeModeKey);
    return darkMode == null
        ? ThemeMode.system
        : darkMode
            ? ThemeMode.dark
            : ThemeMode.light;
  }

  /// Save theme mode to preferences
  static void saveThemeMode(ThemeMode mode) {
    if (mode == ThemeMode.system) {
      _prefs?.remove(_kThemeModeKey);
    } else {
      _prefs?.setBool(_kThemeModeKey, mode == ThemeMode.dark);
    }
  }

  // ==================== Light Theme ====================

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: AppColors.lightPrimaryBackground,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        tertiary: AppColors.tertiary,
        error: AppColors.error,
        surface: AppColors.lightSecondaryBackground,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.lightPrimaryText,
        onError: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.interTight(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 20.0,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: GoogleFonts.interTight(
            fontWeight: FontWeight.w600,
            fontSize: 16.0,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightSecondaryBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.lightAlternate),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.lightAlternate),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      cardTheme: CardThemeData(
        color: AppColors.lightSecondaryBackground,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.lightAlternate,
        thickness: 1,
      ),
      iconTheme: const IconThemeData(
        color: AppColors.lightPrimaryText,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.lightSecondaryText,
      ),
      textTheme: _buildTextTheme(Brightness.light),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.lightPrimaryText,
        contentTextStyle: GoogleFonts.inter(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.lightSecondaryBackground,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.lightSecondaryText,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.lightSecondaryText,
        indicatorColor: AppColors.primary,
        labelStyle: GoogleFonts.interTight(fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.inter(),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.lightSecondaryBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.lightSecondaryBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),
    );
  }

  // ==================== Dark Theme ====================

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: AppColors.darkPrimaryBackground,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        tertiary: AppColors.tertiary,
        error: AppColors.error,
        surface: AppColors.darkSecondaryBackground,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.darkPrimaryText,
        onError: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.darkSecondaryBackground,
        foregroundColor: AppColors.darkPrimaryText,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.interTight(
          color: AppColors.darkPrimaryText,
          fontWeight: FontWeight.w600,
          fontSize: 20.0,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: GoogleFonts.interTight(
            fontWeight: FontWeight.w600,
            fontSize: 16.0,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSecondaryBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.darkAlternate),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.darkAlternate),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkSecondaryBackground,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.darkAlternate,
        thickness: 1,
      ),
      iconTheme: const IconThemeData(
        color: AppColors.darkPrimaryText,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.darkSecondaryText,
      ),
      textTheme: _buildTextTheme(Brightness.dark),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.darkSecondaryBackground,
        contentTextStyle: GoogleFonts.inter(color: AppColors.darkPrimaryText),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.darkSecondaryBackground,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.darkSecondaryText,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.darkSecondaryText,
        indicatorColor: AppColors.primary,
        labelStyle: GoogleFonts.interTight(fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.inter(),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.darkSecondaryBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.darkSecondaryBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),
    );
  }

  // ==================== Text Theme ====================

  static TextTheme _buildTextTheme(Brightness brightness) {
    final primaryTextColor = brightness == Brightness.dark
        ? AppColors.darkPrimaryText
        : AppColors.lightPrimaryText;
    final secondaryTextColor = brightness == Brightness.dark
        ? AppColors.darkSecondaryText
        : AppColors.lightSecondaryText;

    return TextTheme(
      displayLarge: GoogleFonts.interTight(
        color: primaryTextColor,
        fontWeight: FontWeight.w600,
        fontSize: 64.0,
      ),
      displayMedium: GoogleFonts.interTight(
        color: primaryTextColor,
        fontWeight: FontWeight.w600,
        fontSize: 44.0,
      ),
      displaySmall: GoogleFonts.interTight(
        color: primaryTextColor,
        fontWeight: FontWeight.w600,
        fontSize: 36.0,
      ),
      headlineLarge: GoogleFonts.interTight(
        color: primaryTextColor,
        fontWeight: FontWeight.w600,
        fontSize: 32.0,
      ),
      headlineMedium: GoogleFonts.interTight(
        color: primaryTextColor,
        fontWeight: FontWeight.w600,
        fontSize: 28.0,
      ),
      headlineSmall: GoogleFonts.interTight(
        color: primaryTextColor,
        fontWeight: FontWeight.w600,
        fontSize: 24.0,
      ),
      titleLarge: GoogleFonts.interTight(
        color: primaryTextColor,
        fontWeight: FontWeight.w600,
        fontSize: 20.0,
      ),
      titleMedium: GoogleFonts.interTight(
        color: primaryTextColor,
        fontWeight: FontWeight.w600,
        fontSize: 18.0,
      ),
      titleSmall: GoogleFonts.interTight(
        color: primaryTextColor,
        fontWeight: FontWeight.w600,
        fontSize: 16.0,
      ),
      labelLarge: GoogleFonts.inter(
        color: secondaryTextColor,
        fontWeight: FontWeight.normal,
        fontSize: 16.0,
      ),
      labelMedium: GoogleFonts.inter(
        color: secondaryTextColor,
        fontWeight: FontWeight.normal,
        fontSize: 14.0,
      ),
      labelSmall: GoogleFonts.inter(
        color: secondaryTextColor,
        fontWeight: FontWeight.normal,
        fontSize: 12.0,
      ),
      bodyLarge: GoogleFonts.inter(
        color: primaryTextColor,
        fontWeight: FontWeight.normal,
        fontSize: 16.0,
      ),
      bodyMedium: GoogleFonts.inter(
        color: primaryTextColor,
        fontWeight: FontWeight.normal,
        fontSize: 14.0,
      ),
      bodySmall: GoogleFonts.inter(
        color: primaryTextColor,
        fontWeight: FontWeight.normal,
        fontSize: 12.0,
      ),
    );
  }
}

/// Extension to easily access custom colors from BuildContext
extension AppColorsExtension on BuildContext {
  /// Get success color
  Color get successColor => AppColors.success;

  /// Get warning color
  Color get warningColor => AppColors.warning;

  /// Get error color
  Color get errorColor => AppColors.error;

  /// Get tertiary color
  Color get tertiaryColor => AppColors.tertiary;

  /// Check if current theme is dark mode
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  /// Get alternate color based on current theme
  Color get alternateColor =>
      isDarkMode ? AppColors.darkAlternate : AppColors.lightAlternate;

  /// Get secondary background based on current theme
  Color get secondaryBackgroundColor => isDarkMode
      ? AppColors.darkSecondaryBackground
      : AppColors.lightSecondaryBackground;
}
