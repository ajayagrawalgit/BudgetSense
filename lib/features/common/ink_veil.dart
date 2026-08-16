import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/theme_resolver.dart';

/// Hides a sensitive figure behind a hand-brushed ink wash until [revealed].
///
/// A gaussian blur was the obvious way to do this and it looked it: smeared
/// digits still carry their shape, so a large number stayed guessable from its
/// silhouette while the card picked up a soft-focus haze that belongs to no
/// other surface in the app.
///
/// This takes the opposite approach. The number is not smudged, it is simply
/// never painted, and a few sumi-e brush strokes are laid over the space it
/// would have occupied. Nothing can be read back from a stroke that was never
/// derived from the glyphs, and ink on paper is the language the rest of the
/// UI already speaks.
///
/// The child stays in the tree at zero opacity so the layout does not shift
/// when the eye is tapped, and it is kept out of the semantics tree while
/// hidden so a screen reader never announces a concealed amount.
class InkVeil extends StatelessWidget {
  const InkVeil({
    required this.revealed,
    required this.child,
    this.seed = 0,
    super.key,
  });

  final bool revealed;
  final Widget child;

  /// Varies the brushwork between veils, so a row of them reads as three
  /// separate strokes of a pen rather than one bitmap stamped three times.
  final int seed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // Reduce-motion readers get the swap outright: the cross-fade is purely
    // decorative and the eye tap has already confirmed the intent.
    final duration = context.reduceMotion ? Duration.zero : Motion.base;

    return Stack(
      alignment: Alignment.centerLeft,
      children: [
        AnimatedOpacity(
          opacity: revealed ? 1 : 0,
          duration: duration,
          curve: Curves.easeOut,
          child: revealed ? child : ExcludeSemantics(child: child),
        ),
        if (!revealed)
          Positioned.fill(
            child: Semantics(
              label: 'Amount hidden. Tap the eye icon to reveal.',
              child: CustomPaint(
                painter: InkVeilPainter(
                  ink: colors.textSecondary,
                  accent: colors.accent,
                  seed: seed,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Paints the wash: a couple of loaded brush strokes with a soft edge, sized to
/// whatever box it is handed.
@visibleForTesting
class InkVeilPainter extends CustomPainter {
  InkVeilPainter({required this.ink, required this.accent, this.seed = 0});

  final Color ink;
  final Color accent;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    // Deterministic: the veil must not shimmer or redraw differently between
    // frames, it is a still mark on the page.
    final rand = math.Random(seed * 977 + 31);

    // Two sweeps of a loaded brush. Tapered rather than stroked at a constant
    // width, because an even-width bar is what makes a redaction read as a
    // skeleton loading placeholder instead of a mark someone made on purpose.
    const sweeps = 2;
    for (var i = 0; i < sweeps; i++) {
      final centre = size.height * (0.42 + i * 0.22);
      final start = size.width * (0.005 + rand.nextDouble() * 0.02);
      final end = size.width * (0.88 + rand.nextDouble() * 0.10);
      // Each sweep sits at a slightly different angle, as a wrist would.
      final tilt = (rand.nextDouble() - 0.5) * size.height * 0.10;
      final weight = size.height * (0.46 - i * 0.10);

      canvas.drawPath(
        _sweep(
          start: start,
          end: end,
          centre: centre,
          tilt: tilt,
          weight: weight,
          rand: rand,
        ),
        Paint()
          ..style = PaintingStyle.fill
          ..color = ink.withValues(alpha: 0.34 - i * 0.11)
          // A whisper of softness reads as wet ink bleeding into paper. Any
          // more and we are back to a gaussian smudge.
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.4),
      );
    }

    // Dry-brush flecks trailing off the end, where the bristles ran out of ink.
    final fleck = Paint()..color = ink.withValues(alpha: 0.16);
    for (var i = 0; i < 3; i++) {
      canvas.drawCircle(
        Offset(
          size.width * (0.90 + rand.nextDouble() * 0.09),
          size.height * (0.38 + rand.nextDouble() * 0.30),
        ),
        size.height * (0.02 + rand.nextDouble() * 0.025),
        fleck,
      );
    }

    // A single accent bead where the brush lifts, echoing the ensō mark.
    canvas.drawCircle(
      Offset(size.width * 0.055, size.height * 0.46),
      size.height * 0.05,
      Paint()..color = accent.withValues(alpha: 0.30),
    );
  }

  /// One brush sweep: thin where the brush lands, full through the middle,
  /// tapering as it lifts. Built as an outline so the width can vary along it.
  Path _sweep({
    required double start,
    required double end,
    required double centre,
    required double tilt,
    required double weight,
    required math.Random rand,
  }) {
    const steps = 14;
    final top = <Offset>[];
    final bottom = <Offset>[];

    for (var s = 0; s <= steps; s++) {
      final p = s / steps;
      final x = start + (end - start) * p;
      // Fat in the belly of the stroke, tapering to a point at either end.
      final taper = math.sin(math.pi * math.pow(p, 0.78).toDouble());
      final half = weight * 0.5 * taper;
      // Slight vertical drift plus grain, so no edge is perfectly straight.
      final drift = centre + tilt * (p - 0.5) * 2;
      final grain = (rand.nextDouble() - 0.5) * weight * 0.10;
      top.add(Offset(x, drift - half + grain));
      bottom.add(Offset(x, drift + half + grain));
    }

    final path = Path()..moveTo(top.first.dx, top.first.dy);
    for (final o in top.skip(1)) {
      path.lineTo(o.dx, o.dy);
    }
    for (final o in bottom.reversed) {
      path.lineTo(o.dx, o.dy);
    }
    return path..close();
  }

  @override
  bool shouldRepaint(InkVeilPainter old) =>
      old.ink != ink || old.accent != accent || old.seed != seed;
}
