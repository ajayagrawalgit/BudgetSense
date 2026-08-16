import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Wraps the whole app in a subtle paper-grain overlay so the UI reads like
/// ink printed on soft paper (think Kindle / e-ink). The overlay is static,
/// pointer-transparent, and cached in its own layer, so it never interferes
/// with interaction or scroll performance.
///
/// The grain sits *above* the content at a very low opacity: dark flecks on a
/// light background, light flecks on a dark one, plus a whisper of a vignette
/// to give the page a gentle, tactile depth.
class PaperTexture extends StatelessWidget {
  const PaperTexture({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Stack(
      children: [
        Positioned.fill(child: child),
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(
                // The grain is thousands of tiny draw calls and it covers the
                // entire window. `isComplex` asks the engine to cache the
                // resulting raster, and `willChange: false` promises it is
                // worth caching, because this only ever repaints when the
                // brightness flips.
                isComplex: true,
                willChange: false,
                painter: _PaperGrainPainter(brightness: brightness),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PaperGrainPainter extends CustomPainter {
  _PaperGrainPainter({required this.brightness});

  final Brightness brightness;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final isDark = brightness == Brightness.dark;

    // Deterministic seed => stable grain, no shimmer between frames.
    final rand = math.Random(1974);

    // Fine ink/paper flecks.
    final fleckCount = (size.width * size.height / 520).round();
    final darkFleck = Paint()
      ..color = const Color(0xFF3B342A).withValues(alpha: 0.035);
    final lightFleck = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.030);

    for (var i = 0; i < fleckCount; i++) {
      final dx = rand.nextDouble() * size.width;
      final dy = rand.nextDouble() * size.height;
      final r = 0.3 + rand.nextDouble() * 0.7;
      // Mostly the "ink" tone, with a few paper highlights for grain contrast.
      final useLight =
          isDark ? rand.nextDouble() < 0.72 : rand.nextDouble() < 0.22;
      canvas.drawCircle(Offset(dx, dy), r, useLight ? lightFleck : darkFleck);
    }

    // A handful of soft paper fibres (very short faint strokes).
    final fibreCount = (size.width * size.height / 9000).round();
    final fibre = Paint()
      ..color = (isDark ? Colors.white : const Color(0xFF2B2A27))
          .withValues(alpha: 0.018)
      ..strokeWidth = 0.6
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < fibreCount; i++) {
      final dx = rand.nextDouble() * size.width;
      final dy = rand.nextDouble() * size.height;
      final len = 3 + rand.nextDouble() * 9;
      final angle = rand.nextDouble() * math.pi;
      canvas.drawLine(
        Offset(dx, dy),
        Offset(dx + math.cos(angle) * len, dy + math.sin(angle) * len),
        fibre,
      );
    }

    // Gentle vignette: paper edges catch a touch less light.
    final vignette = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.9,
        colors: [
          Colors.transparent,
          (isDark ? Colors.black : const Color(0xFF2B2A27))
              .withValues(alpha: isDark ? 0.10 : 0.028),
        ],
        stops: const [0.72, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, vignette);
  }

  @override
  bool shouldRepaint(_PaperGrainPainter oldDelegate) =>
      oldDelegate.brightness != brightness;
}
