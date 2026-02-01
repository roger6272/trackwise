import 'package:flutter/material.dart';

/// App color palette matching the existing FlutterFlow theme.
///
/// This allows gradual migration from FlutterFlowTheme to standard Flutter theming.
class AppColors {
  AppColors._();

  // ==================== Primary Colors ====================

  /// Primary brand color (purple) - use primaryAdaptive() for dark mode support
  static const Color primary = Color(0xFF4B39EF);

  /// Lighter primary for dark mode (better contrast)
  static const Color primaryLight = Color(0xFF8B7FFF);

  /// Secondary brand color (teal)
  static const Color secondary = Color(0xFF39D2C0);

  /// Tertiary brand color (orange)
  static const Color tertiary = Color(0xFFEE8B60);

  // ==================== Semantic Colors ====================

  /// Success color (green)
  static const Color success = Color(0xFF249689);

  /// Warning color (yellow)
  static const Color warning = Color(0xFFF9CF58);

  /// Error color (red)
  static const Color error = Color(0xFFFF5963);

  /// Info color
  static const Color info = Color(0xFF4B39EF);

  // ==================== Light Mode Colors ====================

  static const Color lightPrimaryText = Color(0xFF14181B);
  static const Color lightSecondaryText = Color(0xFF57636C);
  static const Color lightPrimaryBackground = Color(0xFFF1F4F8);
  static const Color lightSecondaryBackground = Color(0xFFFFFFFF);
  static const Color lightAlternate = Color(0xFFE0E3E7);

  // Accent colors (with transparency)
  static const Color lightAccent1 = Color(0x4C4B39EF);
  static const Color lightAccent2 = Color(0x4D39D2C0);
  static const Color lightAccent3 = Color(0x4DEE8B60);
  static const Color lightAccent4 = Color(0xCCFFFFFF);

  // ==================== Dark Mode Colors ====================

  static const Color darkPrimaryText = Color(0xFFFFFFFF);
  static const Color darkSecondaryText = Color(0xFF95A1AC);
  static const Color darkPrimaryBackground = Color(0xFF14181B);
  static const Color darkSecondaryBackground = Color(0xFF1D2428);
  static const Color darkAlternate = Color(0xFF262D34);

  // Accent colors (with transparency)
  static const Color darkAccent1 = Color(0x4C4B39EF);
  static const Color darkAccent2 = Color(0x4D39D2C0);
  static const Color darkAccent3 = Color(0x4DEE8B60);
  static const Color darkAccent4 = Color(0xB2262D34);

  // ==================== Trend/Stat Colors ====================

  /// Positive trend (green)
  static const Color positive = Color(0xFF017400);

  /// Negative trend (red)
  static const Color negative = Color(0xFF9F0202);

  /// Neutral trend (grey)
  static const Color neutral = Color(0xFF6B7280);

  // ==================== Slidable Action Colors ====================

  static const Color actionActivate = Color(0xFF3C38B5);
  static const Color actionMoveToTop = Color(0xFF0891B2);
  static const Color actionDelete = Color(0xFFD11F43);
  static const Color actionDisabled = Color(0xFF565656);

  // ==================== Activated Item Highlight ====================

  static const Color activatedLight = Color(0xFFCAC6FF);
  static const Color activatedDark = Color(0xFF3D3A6D);
  static Color activated(Brightness brightness) =>
      brightness == Brightness.dark ? activatedDark : activatedLight;

  // ==================== Surface Variant ====================

  static const Color surfaceLight = Color(0xFFF8F9FB);
  static const Color surfaceDark = Color(0xFF1C1C1E);
  static Color surface(Brightness brightness) =>
      brightness == Brightness.dark ? surfaceDark : surfaceLight;

  // ==================== Error Background ====================

  static Color errorBackground(Brightness brightness) =>
      brightness == Brightness.dark
          ? error.withValues(alpha: 0.15)
          : const Color(0xFFFFE6E6);

  // ==================== Helper Methods ====================

  /// Get primary text color based on brightness
  static Color primaryText(Brightness brightness) =>
      brightness == Brightness.dark ? darkPrimaryText : lightPrimaryText;

  /// Get secondary text color based on brightness
  static Color secondaryText(Brightness brightness) =>
      brightness == Brightness.dark ? darkSecondaryText : lightSecondaryText;

  /// Get primary background color based on brightness
  static Color primaryBackground(Brightness brightness) =>
      brightness == Brightness.dark
          ? darkPrimaryBackground
          : lightPrimaryBackground;

  /// Get secondary background color based on brightness
  static Color secondaryBackground(Brightness brightness) =>
      brightness == Brightness.dark
          ? darkSecondaryBackground
          : lightSecondaryBackground;

  /// Get alternate color based on brightness
  static Color alternate(Brightness brightness) =>
      brightness == Brightness.dark ? darkAlternate : lightAlternate;

  /// Get primary color based on brightness (lighter in dark mode for contrast)
  static Color primaryAdaptive(Brightness brightness) =>
      brightness == Brightness.dark ? primaryLight : primary;
}
