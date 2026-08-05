import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_fonts.dart';
import 'app_theme.dart';

/// Resolves the concrete [ThemeData] for a chosen [AppThemeVariant],
/// [AccentPreset] and platform [Brightness]. One place decides how a variant
/// maps to a palette - screens never branch on the variant themselves.
abstract final class ThemeResolver {
  static ({ThemeData theme, ThemeMode mode}) resolve({
    required AppThemeVariant variant,
    required AccentPreset accent,
    required Brightness platformBrightness,
    FontChoice font = FontChoice.system,
    bool blurSupported = true,
  }) {
    switch (variant) {
      case AppThemeVariant.system:
        return (
          theme: platformBrightness == Brightness.dark
              ? _dark(accent, font)
              : _light(accent, font),
          mode: ThemeMode.system,
        );
      case AppThemeVariant.light:
        return (theme: _light(accent, font), mode: ThemeMode.light);
      case AppThemeVariant.dark:
        return (theme: _dark(accent, font), mode: ThemeMode.dark);
      case AppThemeVariant.amoled:
        return (
          theme: AppThemeBuilder.build(
            AppColors.amoled(accent.color),
            brightness: Brightness.dark,
            font: font,
          ),
          mode: ThemeMode.dark,
        );
      case AppThemeVariant.glass:
        return (
          theme: AppThemeBuilder.build(
            AppColors.glass(accent.color, blurSupported: blurSupported),
            brightness: Brightness.dark,
            font: font,
          ),
          mode: ThemeMode.dark,
        );
    }
  }

  static ThemeData _light(
    AccentPreset a, [
    FontChoice font = FontChoice.system,
  ]) =>
      AppThemeBuilder.build(
        AppColors.light(a.color),
        brightness: Brightness.light,
        font: font,
      );

  static ThemeData _dark(
    AccentPreset a, [
    FontChoice font = FontChoice.system,
  ]) =>
      AppThemeBuilder.build(
        AppColors.dark(a.color),
        brightness: Brightness.dark,
        font: font,
      );

  /// Build both light + dark for [MaterialApp]'s theme/darkTheme so system mode
  /// switches instantly. For AMOLED/Glass we return the same palette for both.
  static ({ThemeData light, ThemeData dark, ThemeMode mode}) resolvePair({
    required AppThemeVariant variant,
    required AccentPreset accent,
    FontChoice font = FontChoice.system,
    bool blurSupported = true,
  }) {
    switch (variant) {
      case AppThemeVariant.system:
        return (
          light: _light(accent, font),
          dark: _dark(accent, font),
          mode: ThemeMode.system
        );
      case AppThemeVariant.light:
        return (
          light: _light(accent, font),
          dark: _light(accent, font),
          mode: ThemeMode.light
        );
      case AppThemeVariant.dark:
        return (
          light: _dark(accent, font),
          dark: _dark(accent, font),
          mode: ThemeMode.dark
        );
      case AppThemeVariant.amoled:
        final t = AppThemeBuilder.build(
          AppColors.amoled(accent.color),
          brightness: Brightness.dark,
          font: font,
        );
        return (light: t, dark: t, mode: ThemeMode.dark);
      case AppThemeVariant.glass:
        final t = AppThemeBuilder.build(
          AppColors.glass(accent.color, blurSupported: blurSupported),
          brightness: Brightness.dark,
          font: font,
        );
        return (light: t, dark: t, mode: ThemeMode.dark);
    }
  }
}

/// Convenience accessors so widgets can read theme state succinctly.
extension AppColorsContext on BuildContext {
  AppColors get colors =>
      Theme.of(this).extension<AppColors>() ??
      AppColors.light(const Color(0xFFB07C5E));

  /// True when the user (or OS) has asked to reduce motion. The single place
  /// widgets check before playing any decorative animation.
  bool get reduceMotion => MediaQuery.maybeOf(this)?.disableAnimations ?? false;
}
