import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_fonts.dart';
import 'app_theme.dart';

/// Resolves the concrete [ThemeData] for a chosen [AppThemeVariant],
/// [AccentPreset] and platform [Brightness]. One place decides how a variant
/// maps to a palette - screens never branch on the variant themselves.
abstract final class ThemeResolver {
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

  /// The last resolved pair, keyed by the inputs that produced it.
  static ({ThemeData light, ThemeData dark, ThemeMode mode})? _cached;
  static ({
    AppThemeVariant variant,
    AccentPreset accent,
    FontChoice font,
    bool blurSupported,
  })? _cacheKey;

  /// Build both light + dark for [MaterialApp]'s theme/darkTheme so system mode
  /// switches instantly. For AMOLED/Glass we return the same palette for both.
  ///
  /// Results are memoised on their inputs. `App.build` runs on every settings
  /// change and every provider tick, and a freshly built [ThemeData] is a
  /// *different object* even when it looks identical. `MaterialApp` restarts
  /// its theme animation whenever that object changes, so without this an
  /// unrelated rebuild could kick off a spurious theme lerp. Returning the
  /// identical instance for identical inputs makes that impossible.
  static ({ThemeData light, ThemeData dark, ThemeMode mode}) resolvePair({
    required AppThemeVariant variant,
    required AccentPreset accent,
    FontChoice font = FontChoice.system,
    bool blurSupported = true,
  }) {
    final key = (
      variant: variant,
      accent: accent,
      font: font,
      blurSupported: blurSupported,
    );
    final cached = _cached;
    if (cached != null && _cacheKey == key) return cached;

    final resolved = _resolvePair(variant, accent, font, blurSupported);
    _cacheKey = key;
    _cached = resolved;
    return resolved;
  }

  static ({ThemeData light, ThemeData dark, ThemeMode mode}) _resolvePair(
    AppThemeVariant variant,
    AccentPreset accent,
    FontChoice font,
    bool blurSupported,
  ) {
    switch (variant) {
      case AppThemeVariant.system:
        return (
          light: _light(accent, font),
          dark: _dark(accent, font),
          mode: ThemeMode.system
        );
      case AppThemeVariant.light:
        final t = _light(accent, font);
        return (light: t, dark: t, mode: ThemeMode.light);
      case AppThemeVariant.dark:
        final t = _dark(accent, font);
        return (light: t, dark: t, mode: ThemeMode.dark);
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
