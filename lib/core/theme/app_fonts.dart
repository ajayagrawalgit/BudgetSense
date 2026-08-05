import 'package:flutter/material.dart';

/// The user-selectable typefaces (Section 2: "customize accent colors" and the
/// hand-drawn / journal aesthetic). One place defines every choice so nothing
/// hard-codes a font family across the app.
///
/// [system] uses the platform default (San Francisco on iOS, Roboto on
/// Android). The rest are bundled OFL fonts shipped in `assets/fonts/` - all
/// fully offline, no runtime network fetch.
enum FontChoice {
  system,
  zenMaru,
  caveat,
  patrickHand,
  gochiHand,
  architectsDaughter,
}

extension FontChoiceX on FontChoice {
  /// Human-readable name shown in Settings.
  String get label => switch (this) {
        FontChoice.system => 'System default',
        FontChoice.zenMaru => 'Zen Maru Gothic',
        FontChoice.caveat => 'Caveat',
        FontChoice.patrickHand => 'Patrick Hand',
        FontChoice.gochiHand => 'Gochi Hand',
        FontChoice.architectsDaughter => "Architect's Daughter",
      };

  /// A short flavour note for the picker.
  String get description => switch (this) {
        FontChoice.system => 'Clean and familiar',
        FontChoice.zenMaru => 'Soft rounded Japanese gothic',
        FontChoice.caveat => 'Flowing casual handwriting',
        FontChoice.patrickHand => 'Neat handwritten print',
        FontChoice.gochiHand => 'Relaxed marker script',
        FontChoice.architectsDaughter => 'Hand-lettered blueprint style',
      };

  /// The registered font family, or null for the platform default.
  /// Must match the `family:` names declared in pubspec.yaml.
  String? get fontFamily => switch (this) {
        FontChoice.system => null,
        FontChoice.zenMaru => 'ZenMaruGothic',
        FontChoice.caveat => 'Caveat',
        FontChoice.patrickHand => 'PatrickHand',
        FontChoice.gochiHand => 'GochiHand',
        FontChoice.architectsDaughter => 'ArchitectsDaughter',
      };

  /// Whether this is a decorative handwritten face (vs. a readable UI font).
  bool get isHandwritten =>
      this != FontChoice.system && this != FontChoice.zenMaru;

  /// Handwritten faces have smaller x-heights, so nudge sizes up a touch to
  /// keep numbers and labels comfortably legible (accessibility, Section 19).
  double get sizeFactor => switch (this) {
        FontChoice.caveat => 1.22,
        FontChoice.gochiHand => 1.08,
        FontChoice.patrickHand => 1.06,
        FontChoice.architectsDaughter => 1.08,
        FontChoice.system => 1.0,
        FontChoice.zenMaru => 1.0,
      };

  /// A preview line for the picker - mixes letters, a name and a number so the
  /// user can judge readability of amounts before applying.
  String get sample => 'Coffee  ·  \$4.50';

  /// Preview style rendered in this choice's own font.
  TextStyle previewStyle(Color color) => TextStyle(
        fontFamily: fontFamily,
        fontSize: 18 * sizeFactor,
        color: color,
        height: 1.2,
      );
}
