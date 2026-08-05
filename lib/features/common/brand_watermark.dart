import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/theme_resolver.dart';

/// Draws a single ensō brush stroke: a nearly-closed circle with a small
/// opening, the motif at the heart of the BudgetSense mark. Shared so the
/// empty-state illustration and the [BrandWatermark] speak the same brand
/// language instead of each redrawing their own circle.
///
/// Returns the brush's start point so callers can, for example, drop an accent
/// dot there.
Offset paintEnsoRing(
  Canvas canvas, {
  required Offset center,
  required double radius,
  required Color color,
  required double strokeWidth,
  double startRadians = -0.5,
  double sweepRadians = 5.5,
}) {
  final rect = Rect.fromCircle(center: center, radius: radius);
  canvas.drawArc(
    rect,
    startRadians,
    sweepRadians,
    false,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = color,
  );
  return Offset(
    center.dx + radius * math.cos(startRadians),
    center.dy + radius * math.sin(startRadians),
  );
}

/// Draws a single almond leaf as two mirrored quadratic curves running from
/// [base] to [tip], bowed out by [bulge] on each side. Shared by the sprig
/// illustration, the mood strip and the falling-leaf confetti so they all
/// speak the same hand-drawn language.
void paintInkLeaf(
  Canvas canvas, {
  required Offset base,
  required Offset tip,
  required double bulge,
  required Paint paint,
}) {
  final dir = tip - base;
  final len = dir.distance;
  if (len == 0) return;
  final normal = Offset(-dir.dy, dir.dx) / len;
  final mid = base + dir * 0.5;
  final c1 = mid + normal * bulge;
  final c2 = mid - normal * bulge;
  final path = Path()
    ..moveTo(base.dx, base.dy)
    ..quadraticBezierTo(c1.dx, c1.dy, tip.dx, tip.dy)
    ..quadraticBezierTo(c2.dx, c2.dy, base.dx, base.dy)
    ..close();
  canvas.drawPath(path, paint);
}

/// Lays a very faint ensō mark behind [child], bleeding off a corner, purely as
/// quiet brand texture. It never intercepts touches and is hidden from screen
/// readers. Colour follows the theme, so it reads on light, dark, AMOLED and
/// glass alike.
class BrandWatermark extends StatelessWidget {
  const BrandWatermark({
    required this.child,
    this.alignment = Alignment.bottomRight,
    this.size = 240,
    this.opacity = 0.045,
    super.key,
  });

  final Widget child;
  final Alignment alignment;
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: ClipRect(
                child: Align(
                  alignment: alignment,
                  child: Transform.translate(
                    // Let the mark bleed partly off the corner for a relaxed,
                    // uncontained feel.
                    offset: Offset(size * 0.24, size * 0.24),
                    child: Opacity(
                      opacity: opacity,
                      child: SizedBox(
                        width: size,
                        height: size,
                        child: CustomPaint(
                          painter:
                              _EnsoWatermarkPainter(color: colors.textPrimary),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _EnsoWatermarkPainter extends CustomPainter {
  _EnsoWatermarkPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.42;
    paintEnsoRing(
      canvas,
      center: center,
      radius: radius,
      color: color,
      strokeWidth: size.width * 0.075,
    );
  }

  @override
  bool shouldRepaint(covariant _EnsoWatermarkPainter old) => old.color != color;
}

/// A short, hand-drawn wavy underline in the accent colour, meant to sit just
/// under a section title as a small piece of craft. Fixed, modest width so it
/// reads as a flourish rather than a rule.
class InkFlourish extends StatelessWidget {
  const InkFlourish({this.width = 34, this.color, super.key});

  final double width;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size(width, 6),
        painter: _InkFlourishPainter(color ?? context.colors.accent),
      ),
    );
  }
}

class _InkFlourishPainter extends CustomPainter {
  _InkFlourishPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final y = size.height / 2;
    // A relaxed single brush wobble: up, down, settle.
    final path = Path()
      ..moveTo(0, y + 1)
      ..quadraticBezierTo(w * 0.28, y - 2.5, w * 0.52, y)
      ..quadraticBezierTo(w * 0.76, y + 2.5, w, y - 1);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_InkFlourishPainter old) => old.color != color;
}

/// A title with a small [InkFlourish] tucked beneath its start, for section
/// headers that deserve a touch of craft.
class FlourishTitle extends StatelessWidget {
  const FlourishTitle(this.title, {this.style, super.key});

  final String title;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: style ?? text.titleMedium),
        const SizedBox(height: 5),
        const InkFlourish(),
      ],
    );
  }
}
