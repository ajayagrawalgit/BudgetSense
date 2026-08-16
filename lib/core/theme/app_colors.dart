import 'package:flutter/material.dart';

/// The four supported theme variants.
///
/// [system] is not a palette itself - it defers to the OS brightness and
/// resolves to [light] or [dark] at runtime.
enum AppThemeVariant { system, light, dark, amoled, glass }

extension AppThemeVariantX on AppThemeVariant {
  String get label => switch (this) {
        AppThemeVariant.system => 'Follow system',
        AppThemeVariant.light => 'Light',
        AppThemeVariant.dark => 'Dark',
        AppThemeVariant.amoled => 'AMOLED',
        AppThemeVariant.glass => 'Transparent glass',
      };
}

/// A calm, Muji-inspired accent. Muted and earthy by design - no neon.
enum AccentPreset { clay, olive, sand, paleBlue, ink, plum }

extension AccentPresetX on AccentPreset {
  String get label => switch (this) {
        AccentPreset.clay => 'Clay',
        AccentPreset.olive => 'Olive',
        AccentPreset.sand => 'Sand',
        AccentPreset.paleBlue => 'Pale blue',
        AccentPreset.ink => 'Ink',
        AccentPreset.plum => 'Plum',
      };

  Color get color => switch (this) {
        AccentPreset.clay => const Color(0xFFB07C5E),
        AccentPreset.olive => const Color(0xFF7B7F52),
        AccentPreset.sand => const Color(0xFFC4A374),
        AccentPreset.paleBlue => const Color(0xFF7E97A6),
        AccentPreset.ink => const Color(0xFF4A4A48),
        AccentPreset.plum => const Color(0xFF8E6E7E),
      };
}

/// Immutable palette describing every semantic color a screen may need.
///
/// Screens should read colors from [AppColors] (exposed via the theme
/// extension) rather than hard-coding hex values, so all four variants stay
/// consistent and swappable.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textFaint,
    required this.accent,
    required this.onAccent,
    // Semantic financial signal colors (calm, never aggressive).
    required this.positive,
    required this.negative,
    required this.warning,
    required this.critical,
    required this.info,
    // Glass-specific.
    required this.glassTint,
    required this.usesBlur,
  });

  final Color background;
  final Color surface;
  final Color surfaceMuted;
  final Color border;

  final Color textPrimary;
  final Color textSecondary;
  final Color textFaint;

  final Color accent;
  final Color onAccent;

  final Color positive;
  final Color negative;
  final Color warning;
  final Color critical;
  final Color info;

  /// Overlay tint used behind frosted panels in the glass theme.
  final Color glassTint;

  /// Whether this variant intends to use backdrop blur (glass only).
  final bool usesBlur;

  // ---- Light -------------------------------------------------------------
  static AppColors light(Color accent) => AppColors(
        background: const Color(0xFFF3ECDE), // warm cream paper
        surface: const Color(0xFFFAF5EA),
        surfaceMuted: const Color(0xFFEDE6D6),
        border: const Color(0xFFD9D1BF),
        textPrimary: const Color(0xFF262219), // deep warm ink
        textSecondary: const Color(0xFF57534A),
        textFaint: const Color(0xFF8C887C),
        accent: accent,
        onAccent: const Color(0xFFFCFAF4),
        positive: const Color(0xFF6E8B6A), // desaturated sage
        negative: const Color(0xFFB4675E), // desaturated red/clay
        warning:
            const Color(0xFF7C5E1E), // dark ochre - WCAG AA on paper (5.1:1)
        critical: const Color(0xFFA85A50),
        info: const Color(
            0xFF4A6675), // dark slate blue - WCAG AA on paper (5.2:1)
        glassTint: const Color(0x00000000),
        usesBlur: false,
      );

  // ---- Dark --------------------------------------------------------------
  static AppColors dark(Color accent) => AppColors(
        background: const Color(0xFF23221F), // soft charcoal
        surface: const Color(0xFF2C2B27),
        surfaceMuted: const Color(0xFF34332E),
        border: const Color(0xFF44423B),
        textPrimary: const Color(0xFFE6E2D8), // warm grey
        textSecondary: const Color(0xFFB4B0A6),
        textFaint: const Color(0xFF817E76),
        accent: accent,
        onAccent: const Color(0xFF1E1D1A),
        positive: const Color(0xFF8AA585),
        negative: const Color(0xFFC08379),
        warning: const Color(0xFFCBAE85),
        critical: const Color(0xFFC57C71),
        info: const Color(0xFF93AAB8),
        glassTint: const Color(0x00000000),
        usesBlur: false,
      );

  // ---- AMOLED ------------------------------------------------------------
  static AppColors amoled(Color accent) => AppColors(
        background: const Color(0xFF000000), // true black
        surface: const Color(0xFF0A0A0A),
        surfaceMuted: const Color(0xFF141414),
        border: const Color(0xFF2A2A28),
        textPrimary: const Color(0xFFEDEAE1),
        textSecondary: const Color(0xFFAFACA3),
        textFaint: const Color(0xFF6F6D66),
        accent: accent,
        onAccent: const Color(0xFF000000),
        positive: const Color(0xFF87A282),
        negative: const Color(0xFFC08379),
        warning: const Color(0xFFCBAE85),
        critical: const Color(0xFFC57C71),
        info: const Color(0xFF8FA7B5),
        glassTint: const Color(0x00000000),
        usesBlur: false,
      );

  // ---- Glass -------------------------------------------------------------
  static AppColors glass(Color accent, {required bool blurSupported}) =>
      AppColors(
        background: const Color(0xFF1B1F24),
        surface: const Color(0x33FFFFFF), // translucent frosted panel
        surfaceMuted: const Color(0x22FFFFFF),
        border: const Color(0x33FFFFFF),
        textPrimary: const Color(0xFFF2F1EC),
        textSecondary: const Color(0xFFCFCEC7),
        textFaint: const Color(0xFF9B9A93),
        accent: accent,
        onAccent: const Color(0xFF1B1F24),
        positive: const Color(0xFF9CB697),
        negative: const Color(0xFFD08E84),
        warning: const Color(0xFFD6BA92),
        critical: const Color(0xFFD08579),
        info: const Color(0xFF9FB6C4),
        glassTint: const Color(0x22FFFFFF),
        usesBlur: blurSupported,
      );

  @override
  AppColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceMuted,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? textFaint,
    Color? accent,
    Color? onAccent,
    Color? positive,
    Color? negative,
    Color? warning,
    Color? critical,
    Color? info,
    Color? glassTint,
    bool? usesBlur,
  }) {
    return AppColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textFaint: textFaint ?? this.textFaint,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      positive: positive ?? this.positive,
      negative: negative ?? this.negative,
      warning: warning ?? this.warning,
      critical: critical ?? this.critical,
      info: info ?? this.info,
      glassTint: glassTint ?? this.glassTint,
      usesBlur: usesBlur ?? this.usesBlur,
    );
  }

  @override
  AppColors lerp(covariant AppColors? other, double t) {
    if (other == null) return this;
    return AppColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      border: Color.lerp(border, other.border, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textFaint: Color.lerp(textFaint, other.textFaint, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      positive: Color.lerp(positive, other.positive, t)!,
      negative: Color.lerp(negative, other.negative, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      critical: Color.lerp(critical, other.critical, t)!,
      info: Color.lerp(info, other.info, t)!,
      glassTint: Color.lerp(glassTint, other.glassTint, t)!,
      usesBlur: t < 0.5 ? usesBlur : other.usesBlur,
    );
  }

  // Value equality is not cosmetic here, it is a performance contract.
  //
  // [ThemeData] compares its extensions to decide whether a theme actually
  // changed. Without these, every rebuild produced a palette that looked
  // identical but compared unequal, so `MaterialApp` believed the theme was
  // new and ran a full `ThemeData.lerp` for the whole animation window. That
  // lerp interpolates font sizes, which forces every piece of text in the app
  // to re-layout on every frame. That was the stutter.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppColors &&
        other.background == background &&
        other.surface == surface &&
        other.surfaceMuted == surfaceMuted &&
        other.border == border &&
        other.textPrimary == textPrimary &&
        other.textSecondary == textSecondary &&
        other.textFaint == textFaint &&
        other.accent == accent &&
        other.onAccent == onAccent &&
        other.positive == positive &&
        other.negative == negative &&
        other.warning == warning &&
        other.critical == critical &&
        other.info == info &&
        other.glassTint == glassTint &&
        other.usesBlur == usesBlur;
  }

  @override
  int get hashCode => Object.hash(
        background,
        surface,
        surfaceMuted,
        border,
        textPrimary,
        textSecondary,
        textFaint,
        accent,
        onAccent,
        positive,
        negative,
        warning,
        critical,
        info,
        glassTint,
        usesBlur,
      );
}
