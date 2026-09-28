import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_radii.dart';
import 'app_spacing.dart';
import 'app_text_styles.dart';

abstract final class AppTheme {
  static ThemeData light(AppThemeFlavor flavor) => _build(flavor, Brightness.light);
  static ThemeData dark(AppThemeFlavor flavor) => _build(flavor, Brightness.dark);

  static ThemeData _build(AppThemeFlavor flavor, Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    // The brand colour is the yellow. Green is a *status* colour (success,
    // veg, active) and reaches the UI through `semantic.success`, never through
    // `colorScheme.primary` — having it as primary is what put green on the
    // splash, the buttons, the progress indicators and the focus rings.
    final primaryColor =
        flavor == AppThemeFlavor.appzeto ? AppColors.appzetoYellow : flavor.seed;
    final secondaryColor = flavor == AppThemeFlavor.appzeto
        ? AppColors.appzetoGreen
        : flavor.accent;

    final scheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: brightness,
    ).copyWith(
      primary: primaryColor,
      // Yellow is a light colour: anything painted on it has to be dark or it
      // is unreadable. Every on-primary foreground reads this, so the pairing
      // is decided once here.
      onPrimary: AppColors.lightTextPrimary,
      secondary: secondaryColor,
      onSecondary: AppColors.lightSurface,
      tertiary: AppColors.orangeBadge,
      surface: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      onSurface: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
      error: isDark ? const Color(0xFFFF6B7A) : AppColors.danger,
    );

    final semantic =
        isDark ? AppSemanticColors.dark(flavor) : AppSemanticColors.light(flavor);
    final text = AppTextStyles.textTheme(scheme.onSurface, semantic.textSecondary);
    final background = isDark ? AppColors.darkBackground : AppColors.lightBackground;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      textTheme: text,
      extensions: [semantic],
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
        iconTheme: IconThemeData(color: scheme.onSurface),
        systemOverlayStyle:
            isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.rLg),
      ),
      dividerTheme: DividerThemeData(
        color: semantic.border,
        thickness: 1,
        space: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: semantic.surfaceAlt,
        selectedColor: scheme.primary.withValues(alpha: 0.12),
        side: BorderSide(color: semantic.border),
        labelStyle: text.titleSmall!,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.rPill),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: semantic.surfaceAlt,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        hintStyle: text.bodyLarge!.copyWith(color: semantic.textSecondary),
        border: OutlineInputBorder(
          borderRadius: AppRadii.rMd,
          borderSide: BorderSide(color: semantic.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadii.rMd,
          borderSide: BorderSide(color: semantic.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadii.rMd,
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadii.rMd,
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadii.rMd,
          borderSide: BorderSide(color: scheme.error, width: 1.6),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.sheetTop),
        showDragHandle: false,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.rXl),
        titleTextStyle: text.headlineSmall,
        contentTextStyle: text.bodyLarge!.copyWith(color: semantic.textSecondary),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primary.withValues(alpha: 0.14),
        elevation: 0,
        height: 66,
        labelTextStyle: WidgetStatePropertyAll(text.labelMedium),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
      listTileTheme: ListTileThemeData(
        titleTextStyle: text.titleMedium,
        subtitleTextStyle: text.bodySmall,
        iconColor: scheme.onSurface,
      ),
    );
  }
}

/// Sugar so widgets read `context.semantic.border` instead of a lookup dance.
extension AppThemeX on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
  AppSemanticColors get semantic =>
      Theme.of(this).extension<AppSemanticColors>()!;
}
