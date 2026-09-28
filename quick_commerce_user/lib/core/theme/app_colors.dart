import 'package:flutter/material.dart';

/// Suvio Quick brand palette.
///
/// Deliberately not Blinkit-yellow or Zepto-purple: the identity is a deep
/// evergreen ("Suvio Green") paired with a warm citrus accent, which reads as
/// fresh + premium while staying high-contrast at small sizes.
enum AppThemeFlavor {
  appzeto('Appzeto Yellow', Color(0xFF1F9C8A), Color(0xFF16A34A)),
  green('Suvio Green', Color(0xFF0E7C66), Color(0xFFFFB020)),
  indigo('Suvio Indigo', Color(0xFF4338CA), Color(0xFFFF7A59)),
  sunset('Suvio Sunset', Color(0xFFE0533D), Color(0xFF1F9C8A));

  const AppThemeFlavor(this.label, this.seed, this.accent);

  final String label;
  final Color seed;
  final Color accent;

  static AppThemeFlavor fromName(String? name) =>
      AppThemeFlavor.values.firstWhere(
        (f) => f.name == name,
        orElse: () => AppThemeFlavor.green,
        // orElse: () => AppThemeFlavor.appzeto,
      );
}

abstract final class AppColors {
  // Appzeto exact colors
  static const appzetoYellow = Color(0xFFFFD400);
  static const appzetoGreen = Color(0xFF16A34A);
  static const appzetoDarkGreen = Color(0xFF16A34A);
  static const orangeBadge = Color(0xFFFF6B35);

  // Semantic, flavor-independent tokens.
  static const success = Color(0xFF16A34A);
  static const successSoft = Color(0xFFE4F5EC);
  static const warning = Color(0xFFB8761B);
  static const warningSoft = Color(0xFFFDF1DC);
  static const danger = Color(0xFFD7263D);
  static const dangerSoft = Color(0xFFFDE8EB);
  static const info = Color(0xFF2563EB);

  static const veg = Color(0xFF16A34A);
  static const nonVeg = Color(0xFFB3261E);

  // Light surfaces
  static const lightBackground = Color(0xFFFAFAFA);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceAlt = Color(0xFFF1F3F2);
  static const lightBorder = Color(0xFFE3E7E5);
  static const lightTextPrimary = Color(0xFF111111);
  static const lightTextSecondary = Color(0xFF666666);

  // Dark surfaces — hand-picked, not an inversion. Cards sit *above* the
  // background by lightness so elevation stays legible without heavy shadows.
  static const darkBackground = Color(0xFF0C110F);
  static const darkSurface = Color(0xFF161C19);
  static const darkSurfaceAlt = Color(0xFF1F2724);
  static const darkBorder = Color(0xFF2C3532);
  static const darkTextPrimary = Color(0xFFF2F5F3);
  static const darkTextSecondary = Color(0xFFA3AFA9);

  static const discountGradient = [Color(0xFF1E88E5), Color(0xFF1565C0)];

  // Appzeto brand surfaces matching home screen.
  static const brandYellow = Color(0xFFFFD400);
  static const brandYellowSoft = Color(0xFFFFF1C5);
  static const brandYellowFaint = Color(0xFFFFF9E6);
  static const brandGreen = Color(0xFF16A34A);
  static const brandOrange = Color(0xFFFF6B35);

  // Dark-mode counterparts
  static const brandYellowDark = Color(0xFF3A3416);
  static const brandYellowSoftDark = Color(0xFF2B2712);
}

/// Tokens the Material [ColorScheme] has no slot for.
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.accent,
    required this.brandSurface,
    required this.brandSurfaceSoft,
    required this.onBrandSurface,
    required this.success,
    required this.successSoft,
    required this.warning,
    required this.warningSoft,
    required this.danger,
    required this.dangerSoft,
    required this.border,
    required this.surfaceAlt,
    required this.textSecondary,
    required this.cardShadow,
    required this.sheetShadow,
    required this.floatingShadow,
  });

  final Color accent;

  /// The saturated brand plate: app header, bottom-nav highlight, badges.
  final Color brandSurface;

  /// The tinted plate used behind hero and promo cards.
  final Color brandSurfaceSoft;

  /// Text/icon colour that is legible on [brandSurface].
  final Color onBrandSurface;

  final Color success;
  final Color successSoft;
  final Color warning;
  final Color warningSoft;
  final Color danger;
  final Color dangerSoft;
  final Color border;
  final Color surfaceAlt;
  final Color textSecondary;
  final List<BoxShadow> cardShadow;
  final List<BoxShadow> sheetShadow;
  final List<BoxShadow> floatingShadow;

  factory AppSemanticColors.light(AppThemeFlavor flavor) => AppSemanticColors(
        accent: flavor == AppThemeFlavor.appzeto
            ? AppColors.appzetoGreen
            : flavor.accent,
        brandSurface: flavor == AppThemeFlavor.appzeto
            ? AppColors.appzetoYellow
            : flavor.accent,
        brandSurfaceSoft: flavor == AppThemeFlavor.appzeto
            ? AppColors.brandYellowSoft
            : flavor.accent.withValues(alpha: 0.16),
        onBrandSurface: AppColors.lightTextPrimary,
        success: AppColors.success,
        successSoft: AppColors.successSoft,
        warning: AppColors.warning,
        warningSoft: AppColors.warningSoft,
        danger: AppColors.danger,
        dangerSoft: AppColors.dangerSoft,
        border: AppColors.lightBorder,
        surfaceAlt: AppColors.lightSurfaceAlt,
        textSecondary: AppColors.lightTextSecondary,
        cardShadow: const [
          BoxShadow(color: Color(0x0F101613), blurRadius: 16, offset: Offset(0, 4)),
        ],
        sheetShadow: const [
          BoxShadow(color: Color(0x1A101613), blurRadius: 32, offset: Offset(0, -8)),
        ],
        floatingShadow: [
          BoxShadow(
            color: flavor.seed.withValues(alpha: 0.28),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      );

  factory AppSemanticColors.dark(AppThemeFlavor flavor) => AppSemanticColors(
        accent: flavor.accent,
        brandSurface: flavor == AppThemeFlavor.appzeto
            ? AppColors.brandYellowDark
            : AppColors.darkSurfaceAlt,
        brandSurfaceSoft: flavor == AppThemeFlavor.appzeto
            ? AppColors.brandYellowSoftDark
            : AppColors.darkSurfaceAlt,
        onBrandSurface: AppColors.darkTextPrimary,
        success: const Color(0xFF3DD68C),
        successSoft: const Color(0xFF13301F),
        warning: const Color(0xFFF2B950),
        warningSoft: const Color(0xFF33260D),
        danger: const Color(0xFFFF6B7A),
        dangerSoft: const Color(0xFF3A1319),
        border: AppColors.darkBorder,
        surfaceAlt: AppColors.darkSurfaceAlt,
        textSecondary: AppColors.darkTextSecondary,
        cardShadow: const [
          BoxShadow(color: Color(0x66000000), blurRadius: 18, offset: Offset(0, 6)),
        ],
        sheetShadow: const [
          BoxShadow(color: Color(0x99000000), blurRadius: 36, offset: Offset(0, -10)),
        ],
        floatingShadow: [
          BoxShadow(
            color: flavor.seed.withValues(alpha: 0.42),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      );

  @override
  AppSemanticColors copyWith({
    Color? accent,
    Color? brandSurface,
    Color? brandSurfaceSoft,
    Color? onBrandSurface,
    Color? success,
    Color? successSoft,
    Color? warning,
    Color? warningSoft,
    Color? danger,
    Color? dangerSoft,
    Color? border,
    Color? surfaceAlt,
    Color? textSecondary,
    List<BoxShadow>? cardShadow,
    List<BoxShadow>? sheetShadow,
    List<BoxShadow>? floatingShadow,
  }) {
    return AppSemanticColors(
      accent: accent ?? this.accent,
      brandSurface: brandSurface ?? this.brandSurface,
      brandSurfaceSoft: brandSurfaceSoft ?? this.brandSurfaceSoft,
      onBrandSurface: onBrandSurface ?? this.onBrandSurface,
      success: success ?? this.success,
      successSoft: successSoft ?? this.successSoft,
      warning: warning ?? this.warning,
      warningSoft: warningSoft ?? this.warningSoft,
      danger: danger ?? this.danger,
      dangerSoft: dangerSoft ?? this.dangerSoft,
      border: border ?? this.border,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      textSecondary: textSecondary ?? this.textSecondary,
      cardShadow: cardShadow ?? this.cardShadow,
      sheetShadow: sheetShadow ?? this.sheetShadow,
      floatingShadow: floatingShadow ?? this.floatingShadow,
    );
  }

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      accent: Color.lerp(accent, other.accent, t)!,
      brandSurface: Color.lerp(brandSurface, other.brandSurface, t)!,
      brandSurfaceSoft:
          Color.lerp(brandSurfaceSoft, other.brandSurfaceSoft, t)!,
      onBrandSurface: Color.lerp(onBrandSurface, other.onBrandSurface, t)!,
      success: Color.lerp(success, other.success, t)!,
      successSoft: Color.lerp(successSoft, other.successSoft, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningSoft: Color.lerp(warningSoft, other.warningSoft, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerSoft: Color.lerp(dangerSoft, other.dangerSoft, t)!,
      border: Color.lerp(border, other.border, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      cardShadow: t < 0.5 ? cardShadow : other.cardShadow,
      sheetShadow: t < 0.5 ? sheetShadow : other.sheetShadow,
      floatingShadow: t < 0.5 ? floatingShadow : other.floatingShadow,
    );
  }
}
