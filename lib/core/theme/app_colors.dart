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
