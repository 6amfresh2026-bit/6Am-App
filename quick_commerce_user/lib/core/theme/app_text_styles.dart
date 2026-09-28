import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Centralized Typography configuration using GoogleFonts.poppins for global Material 3 text roles.
abstract final class AppTextStyles {
  static TextTheme textTheme(Color primary, Color secondary) {
    final base = GoogleFonts.poppinsTextTheme();
    TextStyle s(
      double size,
      FontWeight weight, {
      double? height,
      double? spacing,
      Color? color,
    }) =>
        base.bodyMedium!.copyWith(
          fontSize: size,
          fontWeight: weight,
          height: height,
          letterSpacing: spacing,
          color: color ?? primary,
        );

    return TextTheme(
      // Heading 1 (displayLarge): Bold (700), 28px — Main screen titles & hero header texts
      displayLarge: s(28, FontWeight.bold, height: 1.15, spacing: -0.5),

      // Heading 2 (displayMedium): Bold (w700), 24px — Major section headers & modal popups
      displayMedium: s(24, FontWeight.w700, height: 1.2, spacing: -0.4),

      // Heading 3 (displaySmall): Semi-Bold (w600), 20px — Card section headers & category titles
      displaySmall: s(20, FontWeight.w600, height: 1.25, spacing: -0.3),

      // Heading 4 (headlineMedium): Semi-Bold (w600), 18px — AppBar titles & dialog headers
      headlineMedium: s(18, FontWeight.w600, height: 1.25, spacing: -0.2),
      headlineSmall: s(17, FontWeight.w600, height: 1.3),

      titleLarge: s(18, FontWeight.w600, height: 1.3),
      titleMedium: s(15, FontWeight.w600, height: 1.3),
      titleSmall: s(13.5, FontWeight.w600, height: 1.3),

      // Body Large (bodyLarge): Normal (w400), 16px — Primary descriptions & detail paragraphs
      bodyLarge: s(16, FontWeight.normal, height: 1.45),

      // Body Medium (bodyMedium): Normal (w400), 14px — Standard UI text, list tiles, input field text
      bodyMedium: s(14, FontWeight.normal, height: 1.45, color: secondary),

      // Body Small (bodySmall): Normal (w400), 12px — Secondary text, timestamps, helper text
      bodySmall: s(12, FontWeight.normal, height: 1.4, color: secondary),

      // Button Text (labelLarge): Semi-Bold (w600), Spacing 0.5, 16px — Action buttons, bottom bar actions
      labelLarge: s(16, FontWeight.w600, height: 1.2, spacing: 0.5),

      labelMedium: s(12, FontWeight.w600, height: 1.2, spacing: 0.3),

      // Captions (labelSmall): Normal (w400), Spacing 0.4, 10px — Small badges, sub-captions & tags
      labelSmall: s(10, FontWeight.normal, height: 1.1, spacing: 0.4),
    );
  }
}

/// Use-case styles that are not part of the Material scale.
extension AppTextStyleContext on TextTheme {
  /// Bold, tabular figures so prices in a column line up.
  TextStyle get price => titleMedium!.copyWith(
        fontWeight: FontWeight.w800,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  TextStyle get priceLarge => headlineSmall!.copyWith(
        fontWeight: FontWeight.w800,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  TextStyle get mrp => bodySmall!.copyWith(
        decoration: TextDecoration.lineThrough,
        fontWeight: FontWeight.w600,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  TextStyle get badgeLabel => labelSmall!.copyWith(fontWeight: FontWeight.w800);

  TextStyle get sectionHeader => titleLarge!.copyWith(letterSpacing: -0.3);
}
