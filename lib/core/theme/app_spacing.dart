import 'package:flutter/widgets.dart';

/// Centralized spacing, radius, and elevation tokens.
///
/// Everything spatial in the app references these so the "gentle spacing" of
/// the design stays consistent. No magic numbers sprinkled across widgets.
abstract final class Insets {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  static const EdgeInsets screen = EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets card = EdgeInsets.all(lg);
}

/// Selectively-rounded corners. The design uses rounding sparingly.
abstract final class Corners {
  static const Radius smR = Radius.circular(6);
  static const Radius mdR = Radius.circular(10);
  static const Radius lgR = Radius.circular(16);

  static const BorderRadius sm = BorderRadius.all(smR);
  static const BorderRadius md = BorderRadius.all(mdR);
  static const BorderRadius lg = BorderRadius.all(lgR);
}

/// Hairline border widths for the "fine borders" aesthetic.
abstract final class Strokes {
  static const double hairline = 0.75;
  static const double thin = 1.0;
}

/// Animation durations - deliberately subtle. Respect reduce-motion elsewhere.
abstract final class Motion {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration base = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);
}
