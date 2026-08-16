import 'dart:math';

import 'package:flutter/material.dart';

import 'brand_watermark.dart';

/// The flavour of a one-shot celebration. All are dependency-free, painted with
/// a [CustomPainter].
enum ConfettiVariant {
  /// Classic paper confetti in the calm palette.
  confetti,

  /// Autumn leaves drifting down (used in Sep..Nov, or for a gentle mood).
  leaves,

  /// Soft coins tumbling (a loan reached the finish line).
  coins,

  /// A single warm firework burst (you beat last month).
  firework,
}

/// A one-shot, full-screen celebration painted with a [CustomPainter] - no
/// packages, no image assets, just a little joy.
///
/// Insert it with [ConfettiOverlay.shower]: it drops a single root [Overlay]
/// entry that covers the ENTIRE screen (above the nav bar and everything else),
/// plays once, and removes itself when the animation finishes. It is wrapped in
/// an [IgnorePointer] so it never eats a tap.
///
/// Deliberately NOT gated behind reduce-motion: this only ever fires from an
/// explicit, deliberate user gesture (double-tapping the all-clear card), it
/// is not ambient or looping motion, and it is the entire payoff of that
/// easter egg. Easter eggs should behave the same for every user regardless
/// of their settings, so this always plays.
abstract final class ConfettiOverlay {
  static void shower(
    BuildContext context, {
    ConfettiVariant variant = ConfettiVariant.confetti,
    int? pieces,
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _CelebrationLayer(
        variant: variant,
        pieces: pieces ?? _defaultPieces(variant),
        onDone: () {
          if (entry.mounted) entry.remove();
        },
      ),
    );
    overlay.insert(entry);
  }

  static int _defaultPieces(ConfettiVariant v) => switch (v) {
        ConfettiVariant.confetti => 90,
        ConfettiVariant.leaves => 34,
        ConfettiVariant.coins => 40,
        ConfettiVariant.firework => 64,
      };
}

enum _Shape { rect, circle, leaf, coin }

const _palettes = <ConfettiVariant, List<Color>>{
  ConfettiVariant.confetti: [
    Color(0xFFB07C5E), // clay
    Color(0xFF7B7F52), // olive
    Color(0xFFC4A374), // sand
    Color(0xFF7E97A6), // pale blue
    Color(0xFF8E6E7E), // plum
    Color(0xFF6E8B6A), // sage
    Color(0xFFE7C873), // soft gold
  ],
  ConfettiVariant.leaves: [
    Color(0xFFB5651D), // rust
    Color(0xFFC87941), // amber
    Color(0xFFA6612F), // russet
    Color(0xFF8A6E3B), // ochre
    Color(0xFF6E7B3E), // moss
  ],
  ConfettiVariant.coins: [
    Color(0xFFE7C873), // soft gold
    Color(0xFFCBA44B), // deep gold
    Color(0xFFD8B667), // honey
    Color(0xFFC4A374), // sand
  ],
  ConfettiVariant.firework: [
    Color(0xFFE7C873), // gold
    Color(0xFFB07C5E), // clay
    Color(0xFFC4677A), // rose
    Color(0xFF7E97A6), // blue
    Color(0xFFE0A96D), // apricot
  ],
};

/// A single falling piece for the drift-down variants.
class _Piece {
  _Piece(Random r, ConfettiVariant variant)
      : startX = r.nextDouble(),
        color = _palettes[variant]![r.nextInt(_palettes[variant]!.length)],
        size = _sizeFor(variant, r),
        drift = (r.nextDouble() - 0.5) *
            (variant == ConfettiVariant.leaves ? 0.5 : 0.3),
        fall = _fallFor(variant, r),
        spin = (r.nextDouble() - 0.5) *
            (variant == ConfettiVariant.coins ? 16 : 10),
        phase = r.nextDouble() * pi * 2,
        wobble = (variant == ConfettiVariant.leaves ? 0.06 : 0.03) +
            r.nextDouble() * 0.05,
        delay = r.nextDouble() * 0.28,
        shape = _shapeFor(variant, r);

  final double startX;
  final Color color;
  final double size;
  final double drift;
  final double fall;
  final double spin;
  final double phase;
  final double wobble;
  final double delay;
  final _Shape shape;

  static double _sizeFor(ConfettiVariant v, Random r) => switch (v) {
        ConfettiVariant.confetti => 6 + r.nextDouble() * 7,
        ConfettiVariant.leaves => 13 + r.nextDouble() * 9,
        ConfettiVariant.coins => 10 + r.nextDouble() * 6,
        ConfettiVariant.firework => 6 + r.nextDouble() * 5,
      };

  static double _fallFor(ConfettiVariant v, Random r) => switch (v) {
        ConfettiVariant.leaves => 0.6 + r.nextDouble() * 0.4,
        ConfettiVariant.coins => 0.95 + r.nextDouble() * 0.5,
        _ => 0.85 + r.nextDouble() * 0.5,
      };

  static _Shape _shapeFor(ConfettiVariant v, Random r) => switch (v) {
        ConfettiVariant.leaves => _Shape.leaf,
        ConfettiVariant.coins => _Shape.coin,
        _ => r.nextBool() ? _Shape.circle : _Shape.rect,
      };
}

/// A single spark for the firework burst.
class _Spark {
  _Spark(Random r)
      : angle = r.nextDouble() * pi * 2,
        speed = 0.35 + r.nextDouble() * 0.65,
        color = _palettes[ConfettiVariant.firework]![
            r.nextInt(_palettes[ConfettiVariant.firework]!.length)],
        size = 2.5 + r.nextDouble() * 2.5,
        originX = 0.42 + r.nextDouble() * 0.16;

  final double angle;
  final double speed;
  final Color color;
  final double size;
  final double originX;
}

class _CelebrationLayer extends StatefulWidget {
  const _CelebrationLayer({
    required this.variant,
    required this.pieces,
    required this.onDone,
  });

  final ConfettiVariant variant;
  final int pieces;
  final VoidCallback onDone;

  @override
  State<_CelebrationLayer> createState() => _CelebrationLayerState();
}

class _CelebrationLayerState extends State<_CelebrationLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Piece> _pieces;
  late final List<_Spark> _sparks;

  @override
  void initState() {
    super.initState();
    final r = Random();
    final isFirework = widget.variant == ConfettiVariant.firework;
    _pieces = isFirework
        ? const []
        : List.generate(widget.pieces, (_) => _Piece(r, widget.variant));
    _sparks =
        isFirework ? List.generate(widget.pieces, (_) => _Spark(r)) : const [];
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: isFirework ? 1900 : 2600),
    )..addStatusListener((s) {
        if (s == AnimationStatus.completed) widget.onDone();
      });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The painter drives its own repaint straight from the controller
    // (`super.repaint: _controller`). That means NO widget rebuild and NO
    // painter/Paint allocation per frame - the render object simply re-invokes
    // paint() each tick, which is the smoothest way to animate a CustomPaint.
    // willChange tells the raster cache not to waste effort caching a layer
    // that changes every frame.
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          willChange: true,
          painter: widget.variant == ConfettiVariant.firework
              ? _FireworkPainter(_sparks, _controller)
              : _FallPainter(_pieces, _controller),
        ),
      ),
    );
  }
}

class _FallPainter extends CustomPainter {
  _FallPainter(this.pieces, this.anim) : super(repaint: anim);

  final List<_Piece> pieces;
  final Animation<double> anim;

  // Hoisted so the whole burst reuses three Paint objects instead of
  // allocating dozens every frame (that per-frame garbage was the stutter).
  final Paint _fill = Paint()..style = PaintingStyle.fill;
  final Paint _stroke = Paint()..style = PaintingStyle.stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final t = anim.value;

    for (final p in pieces) {
      final local = ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final opacity = local < 0.7 ? 1.0 : (1 - (local - 0.7) / 0.3);

      final dx =
          (p.startX + p.drift * local + sin(p.phase + local * 12) * p.wobble)
                  .clamp(-0.1, 1.1) *
              size.width;
      final dy = (-0.08 + p.fall * local * 1.12) * size.height;
      final angle = p.phase + p.spin * local * pi;

      canvas.save();
      canvas.translate(dx, dy);
      canvas.rotate(angle);
      _fill.color = p.color.withValues(alpha: opacity.clamp(0.0, 1.0));

      switch (p.shape) {
        case _Shape.circle:
          canvas.drawCircle(Offset.zero, p.size / 2, _fill);
        case _Shape.rect:
          canvas.drawRect(
            Rect.fromCenter(
              center: Offset.zero,
              width: p.size,
              height: p.size * 0.62,
            ),
            _fill,
          );
        case _Shape.leaf:
          final h = p.size;
          paintInkLeaf(
            canvas,
            base: Offset(0, -h / 2),
            tip: Offset(0, h / 2),
            bulge: h * 0.3,
            paint: _fill,
          );
          // A faint centre vein.
          _stroke
            ..strokeWidth = 0.9
            ..color = Colors.black.withValues(alpha: 0.12);
          canvas.drawLine(Offset(0, -h / 2), Offset(0, h / 2), _stroke);
        case _Shape.coin:
          canvas.drawCircle(Offset.zero, p.size / 2, _fill);
          _stroke
            ..strokeWidth = 1.2
            ..color = Colors.white.withValues(alpha: opacity * 0.35);
          canvas.drawCircle(Offset.zero, p.size / 2, _stroke);
      }
      canvas.restore();
    }
  }

  // Repaint is driven by the animation listenable (super.repaint), not by
  // instance swaps, so this can safely say no.
  @override
  bool shouldRepaint(_FallPainter old) => false;
}

class _FireworkPainter extends CustomPainter {
  _FireworkPainter(this.sparks, this.anim) : super(repaint: anim);

  final List<_Spark> sparks;
  final Animation<double> anim;

  final Paint _line = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  final Paint _dot = Paint()..style = PaintingStyle.fill;

  @override
  void paint(Canvas canvas, Size size) {
    final t = anim.value;
    // Ease-out expansion (inlined cubic, no dart:math pow), then a soft fade.
    final inv = 1 - t;
    final expand = 1 - inv * inv * inv;
    final opacity = t < 0.55 ? 1.0 : (1 - (t - 0.55) / 0.45).clamp(0.0, 1.0);
    final reach = size.shortestSide * 0.42;
    final originY = size.height * 0.34;
    final gravity = size.height * 0.10 * t * t;

    for (final s in sparks) {
      final dir = Offset(cos(s.angle), sin(s.angle));
      final origin = Offset(size.width * s.originX, originY);
      final dist = reach * s.speed * expand;
      final head = origin + dir * dist + Offset(0, gravity);
      // A short trailing tail so each spark reads as a streak, not a dot.
      final tail = origin + dir * (dist * 0.82) + Offset(0, gravity * 0.82);

      final color = s.color.withValues(alpha: opacity);
      _line
        ..color = color
        ..strokeWidth = s.size * 0.6;
      canvas.drawLine(tail, head, _line);
      _dot.color = color;
      canvas.drawCircle(head, s.size * 0.5, _dot);
    }
  }

  @override
  bool shouldRepaint(_FireworkPainter old) => false;
}
