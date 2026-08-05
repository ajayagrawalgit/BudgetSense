import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_fonts.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Builds a Flutter [ThemeData] from a semantic [AppColors] palette.
///
/// All four theme variants funnel through here, so component styling
/// (buttons, inputs, cards, nav) stays DRY and consistent. Screens read
/// semantic colors via `Theme.of(context).extension<AppColors>()`.
abstract final class AppThemeBuilder {
  static ThemeData build(
    AppColors c, {
    required Brightness brightness,
    FontChoice font = FontChoice.system,
  }) {
    final textTheme = AppTypography.withFont(
      AppTypography.build(c.textPrimary, c.textSecondary, c.textFaint),
      font,
    );

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: c.accent,
      onPrimary: c.onAccent,
      secondary: c.accent,
      onSecondary: c.onAccent,
      error: c.critical,
      onError: c.onAccent,
      surface: c.surface,
      onSurface: c.textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: c.background,
      canvasColor: c.background,
      dividerColor: c.border,
      textTheme: textTheme,
      splashFactory: NoSplash.splashFactory, // calm: no ripple flare
      extensions: <ThemeExtension<dynamic>>[c],
      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor: c.textPrimary,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: Corners.md,
          side: BorderSide(color: c.border, width: Strokes.hairline),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: c.border,
        thickness: Strokes.hairline,
        space: Insets.lg,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surfaceMuted,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Insets.lg,
          vertical: Insets.md,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: c.textFaint),
        labelStyle: textTheme.labelMedium,
        border: OutlineInputBorder(
          borderRadius: Corners.md,
          borderSide: BorderSide(color: c.border, width: Strokes.hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: Corners.md,
          borderSide: BorderSide(color: c.border, width: Strokes.hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: Corners.md,
          borderSide: BorderSide(color: c.accent, width: Strokes.thin),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: Corners.md,
          borderSide: BorderSide(color: c.critical, width: Strokes.thin),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.accent,
          foregroundColor: c.onAccent,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: Insets.xl,
            vertical: Insets.md,
          ),
          shape: const RoundedRectangleBorder(borderRadius: Corners.md),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.textPrimary,
          side: BorderSide(color: c.border, width: Strokes.thin),
          padding: const EdgeInsets.symmetric(
            horizontal: Insets.xl,
            vertical: Insets.md,
          ),
          shape: const RoundedRectangleBorder(borderRadius: Corners.md),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: c.accent),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.surfaceMuted,
        selectedColor: c.accent.withValues(alpha: 0.16),
        side: BorderSide(color: c.border, width: Strokes.hairline),
        labelStyle: textTheme.labelMedium!,
        shape: const RoundedRectangleBorder(borderRadius: Corners.sm),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.surface,
        contentTextStyle: textTheme.bodyMedium,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: Corners.md,
          side: BorderSide(color: c.border, width: Strokes.hairline),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Corners.lgR),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.accent,
        linearTrackColor: c.surfaceMuted,
      ),
    );
  }
}
