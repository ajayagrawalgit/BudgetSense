import 'package:flutter/material.dart';

import 'app_fonts.dart';

/// Typography scale with strong readability and quiet character.
///
/// We intentionally avoid a display-heavy type ramp; the design is editorial
/// and calm. The base scale is font-agnostic; [withFont] overlays the user's
/// chosen [FontChoice] in one place so every text style stays consistent.
abstract final class AppTypography {
  static TextTheme build(Color primary, Color secondary, Color faint) {
    TextStyle base(
      double size,
      FontWeight weight,
      Color color, {
      double height = 1.35,
      double spacing = 0,
    }) =>
        TextStyle(
          fontSize: size,
          fontWeight: weight,
          color: color,
          height: height,
          letterSpacing: spacing,
        );

    return TextTheme(
      displaySmall: base(30, FontWeight.w600, primary, height: 1.2),
      headlineMedium: base(24, FontWeight.w600, primary, height: 1.25),
      headlineSmall: base(20, FontWeight.w600, primary, height: 1.3),
      titleLarge: base(18, FontWeight.w600, primary),
      titleMedium: base(16, FontWeight.w500, primary),
      titleSmall: base(14, FontWeight.w500, secondary),
      bodyLarge: base(16, FontWeight.w400, primary),
      bodyMedium: base(14, FontWeight.w400, secondary),
      bodySmall: base(12, FontWeight.w400, faint),
      labelLarge: base(14, FontWeight.w500, primary, spacing: 0.2),
      labelMedium: base(12, FontWeight.w500, secondary, spacing: 0.3),
      labelSmall: base(11, FontWeight.w500, faint, spacing: 0.4),
    );
  }

  /// Overlay the chosen [font] on a base [TextTheme]. Applying the family here
  /// (rather than per-style) keeps the whole app on one typeface with a single
  /// call, and scales sizes up slightly for handwritten faces (readability).
  static TextTheme withFont(TextTheme base, FontChoice font) => base.apply(
        fontFamily: font.fontFamily,
        fontSizeFactor: font.sizeFactor,
      );
}
