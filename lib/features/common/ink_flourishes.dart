import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants/branding.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/theme_resolver.dart';
import '../../core/utils/haptics.dart';

/// One-shot brush flourishes: an ensō drawing itself, a single line of ink, and
/// the terracotta seal pressing down.
///
/// These are only ever reached through a deliberate gesture (a long-press, a
/// seventh tap, a typed word), so like the rest of the easter eggs they are
/// deliberately NOT gated behind reduce-motion. The stroke *is* the payoff;
/// removing it would leave the gesture doing nothing at all. Nothing here
/// loops, and nothing here fires on its own.

/// The same words in the app's handwriting face.
///
/// Always derived from the style it replaces, because Flutter refuses to
/// interpolate two text styles that disagree about `inherit`, and these are
/// animated between.
TextStyle handwrittenFrom(TextStyle base) =>
    base.copyWith(fontFamily: 'Caveat', fontSize: 22);

/// How long a full ensō takes to brush.
const Duration kEnsoBrushDuration = Duration(milliseconds: 1600);

/// How long a finished ensō is left on screen before whatever it replaced
/// comes back.
const Duration kEnsoBrushDwell = Duration(milliseconds: 1400);

/// An ensō that draws itself, one continuous stroke, thin at the start and
/// tapering out at the end the way a loaded brush does.
class BrushedEnso extends StatefulWidget {
  const BrushedEnso({
    super.key,
    this.size = 96,
    this.color,
    this.duration = kEnsoBrushDuration,
    this.onDone,
  });

  final double size;

  /// Defaults to the theme's ink.
  final Color? color;
  final Duration duration;
  final VoidCallback? onDone;

  @override
  State<BrushedEnso> createState() => _BrushedEnsoState();
}

class _BrushedEnsoState extends State<BrushedEnso>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  @override
  void initState() {
    super.initState();
    _c.forward().whenCompleteOrCancel(() {
      if (mounted) widget.onDone?.call();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ink = widget.color ?? context.colors.textPrimary;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => CustomPaint(
          size: Size.square(widget.size),
          painter: _BrushPainter(
            progress: Curves.easeInOutSine.transform(_c.value),
            ink: ink,
          ),
        ),
      ),
    );
  }
}

/// Paints a partial ensō as a chain of short, width-varying segments, which is
/// what gives it the loaded-then-drying brush look a plain arc cannot.
class _BrushPainter extends CustomPainter {
  _BrushPainter({required this.progress, required this.ink});

  final double progress;
  final Color ink;

  /// The opening sits at the right, as it does on the brand mark.
  static const _start = 0.22;
  static const _fullSweep = math.pi * 2 * 0.93;
  static const _steps = 140;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = size.width * 0.382;
    final baseWidth = size.width * 0.128;
    final sweep = _fullSweep * progress;

    Offset at(double angle, double radius) => Offset(
          center.dx + radius * math.cos(angle),
          center.dy + radius * math.sin(angle),
        );

    // A little wobble so the circle reads as hand-drawn, not machined.
    double radiusAt(double angle) =>
        baseRadius * (1 + 0.018 * math.sin(angle * 3 + 0.6));

    void stroke({
      required double widthScale,
      required double radiusOffset,
      required double alpha,
      required double from,
      double to = 1,
    }) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..color = ink.withValues(alpha: alpha);

      final steps = math.max(2, (_steps * progress).round());
      Offset? prev;
      for (var i = 0; i <= steps; i++) {
        final u = i / steps;
        // Where along the *whole* circle this sits, so the taper stays put as
        // the stroke grows rather than sliding along with the tip.
        final along = (sweep * u) / _fullSweep;
        final angle = _start + sweep * u;
        final point = at(angle, radiusAt(angle) + radiusOffset);
        if (prev != null && along >= from && along <= to) {
          paint.strokeWidth = baseWidth * widthScale * _weight(along, progress);
          canvas.drawLine(prev, point, paint);
        }
        prev = point;
      }
    }

    stroke(widthScale: 1, radiusOffset: 0, alpha: 1, from: 0);
    // The frayed second pass the brush leaves as it runs dry near the finish.
    stroke(
      widthScale: 0.22,
      radiusOffset: baseRadius * 0.085,
      alpha: 0.55,
      from: 0.45,
      // Stops short of the tip, so it reads as a stray hair rather than a spur
      // hanging off the end of the stroke.
      to: 0.9,
    );
  }

  /// Pressure along the stroke: lands light, carries full through the body,
  /// runs dry at the finish, and stays thin at the tip while still moving.
  double _weight(double along, double head) {
    final landing = (along / 0.06).clamp(0.0, 1.0);
    final lift = ((1 - along) / 0.09).clamp(0.0, 1.0);
    final body = 0.48 + 0.52 * math.min(landing, lift);
    // While the stroke is still being drawn the moving end is a brush tip,
    // not a blunt cut.
    final tip = ((head - along) / 0.03).clamp(0.0, 1.0);
    return body * (0.62 + 0.38 * tip);
  }

  @override
  bool shouldRepaint(_BrushPainter old) =>
      old.progress != progress || old.ink != ink;
}

/// A single horizontal line of ink, drawn left to right and nothing else.
class InkLine extends StatelessWidget {
  const InkLine({
    super.key,
    this.width = 140,
    this.color,
    this.duration = const Duration(milliseconds: 1100),
  });

  final double width;
  final Color? color;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final ink = color ?? context.colors.textPrimary;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      curve: Curves.easeInOutCubic,
      builder: (_, t, __) => CustomPaint(
        size: Size(width, width * 0.07),
        painter: _InkLinePainter(progress: t, ink: ink),
      ),
    );
  }
}

class _InkLinePainter extends CustomPainter {
  _InkLinePainter({required this.progress, required this.ink});

  final double progress;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final y = size.height / 2;
    final end = size.width * progress;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..color = ink;

    const steps = 80;
    final maxWidth = size.height * 0.85;
    var prev = Offset(0, y);
    for (var i = 1; i <= steps; i++) {
      final u = i / steps;
      final x = end * u;
      final along = x / size.width;
      // Barely a rise, as if the wrist moved.
      final point =
          Offset(x, y - math.sin(along * math.pi) * size.height * 0.1);
      final landing = (along / 0.05).clamp(0.0, 1.0);
      final lift = ((1 - along) / 0.13).clamp(0.0, 1.0);
      paint.strokeWidth = maxWidth * (0.14 + 0.86 * math.min(landing, lift));
      canvas.drawLine(prev, point, paint);
      prev = point;
    }
  }

  @override
  bool shouldRepaint(_InkLinePainter old) =>
      old.progress != progress || old.ink != ink;
}

/// How long a pressed seal stays on the page before it lifts away.
const Duration kSealDwell = Duration(milliseconds: 1900);

/// The terracotta hanko coming down onto the page: overshoot, contact, settle.
class SealStamp extends StatefulWidget {
  const SealStamp({
    super.key,
    this.size = 92,
    this.onDone,
  });

  final double size;
  final VoidCallback? onDone;

  @override
  State<SealStamp> createState() => _SealStampState();
}

class _SealStampState extends State<SealStamp>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void initState() {
    super.initState();
    _c.forward().whenCompleteOrCancel(() {
      if (mounted) widget.onDone?.call();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) {
        final t = Curves.easeOutCubic.transform(_c.value);
        return Opacity(
          opacity: (t * 2.2).clamp(0.0, 1.0),
          child: Transform.rotate(
            // Comes in very slightly askew, like a hand pressing it.
            angle: (1 - t) * -0.09,
            child: Transform.scale(
              scale: 1 + (1 - t) * 0.55,
              child: child,
            ),
          ),
        );
      },
      child: Image.asset(
        BrandAssets.seal,
        width: widget.size,
        height: widget.size,
        excludeFromSemantics: true,
      ),
    );
  }
}

/// How long a single wave takes to cross the page and settle.
const Duration kWaterRippleDuration = Duration(milliseconds: 1700);

/// How far past the top the dashboard has to be pulled before the water shows
/// up, in logical pixels.
///
/// Well beyond an ordinary bounce: this should feel like you leaned on it, not
/// like you flicked the list a bit too hard.
const double kOverPullDepth = 120;

/// A single ink wave travelling across the page, fading up as it arrives and
/// away as it goes.
class WaterRipple extends StatefulWidget {
  const WaterRipple({
    super.key,
    this.duration = kWaterRippleDuration,
    this.onDone,
  });

  final Duration duration;
  final VoidCallback? onDone;

  @override
  State<WaterRipple> createState() => _WaterRippleState();
}

class _WaterRippleState extends State<WaterRipple>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  @override
  void initState() {
    super.initState();
    _c.forward().whenCompleteOrCancel(() {
      if (mounted) widget.onDone?.call();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ink = context.colors.textFaint;

    return IgnorePointer(
      // Water never spills onto the rest of the screen.
      child: ClipRect(
        child: LayoutBuilder(
          builder: (context, box) {
            // Inside a filled Stack these are bounded, but a zero or infinite
            // constraint would otherwise produce a NaN offset.
            if (!box.hasBoundedWidth || box.maxWidth <= 0) {
              return const SizedBox.shrink();
            }
            final pageWidth = box.maxWidth;
            final waveWidth = pageWidth * 0.85;

            return AnimatedBuilder(
              animation: _c,
              builder: (context, child) {
                final t = _c.value;
                final crossed = Curves.easeInOutCubic.transform(t);
                return Stack(
                  children: [
                    Positioned(
                      // Enters just off the left edge, leaves just off the right.
                      left: -waveWidth + (pageWidth + waveWidth) * crossed,
                      top: 0,
                      bottom: 0,
                      width: waveWidth,
                      child: Opacity(
                        opacity: (math.sin(t * math.pi) * 0.5).clamp(0.0, 1.0),
                        child: Center(child: child),
                      ),
                    ),
                  ],
                );
              },
              child: BrandMarks.tinted(
                BrandAssets.waves,
                color: ink,
                width: waveWidth,
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Wraps a scrollable so that pulling it well past its top sends one wave
/// across the page.
///
/// A quiet easter egg: over-pull the dashboard and the water crosses once,
/// then settles. There is no refresh behind it, because the figures are already
/// live; this is only the pull, answered.
///
/// The gesture has to be deliberate to count. Overscroll is accumulated for as
/// long as a single drag keeps pulling past the top, one wave is allowed per
/// drag, and the tally resets whenever scrolling starts or ends, so a series of
/// ordinary flicks can never add up into it.
class OverPullRipple extends StatefulWidget {
  const OverPullRipple({
    super.key,
    required this.child,
    this.depth = kOverPullDepth,
  });

  final Widget child;

  /// How far past the top counts as an over-pull.
  final double depth;

  @override
  State<OverPullRipple> createState() => _OverPullRippleState();
}

class _OverPullRippleState extends State<OverPullRipple> {
  double _pulled = 0;

  /// Whether this drag is still allowed to produce a wave. One per pull.
  bool _armed = true;
  Key? _ripple;

  bool _onScroll(ScrollNotification n) {
    // Only the scrollable this directly wraps, and only its vertical axis: the
    // dashboard also carries horizontal month swipes and a nested calendar.
    if (n.depth != 0 || n.metrics.axis != Axis.vertical) return false;

    if (n is ScrollStartNotification || n is ScrollEndNotification) {
      _pulled = 0;
      // A finished drag re-arms; a new one starts from nothing.
      if (n is ScrollEndNotification) _armed = true;
    } else if (n is OverscrollNotification && n.overscroll < 0) {
      // Negative overscroll is a pull past the top. The far end never counts.
      _pulled += -n.overscroll;
      if (_armed && _ripple == null && _pulled >= widget.depth) _release();
    }

    // Never swallow the notification: scrolling, the glow and anything else
    // listening upstream must all behave exactly as before.
    return false;
  }

  void _release() {
    _armed = false;
    Haptics.selection();
    setState(() => _ripple = UniqueKey());
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: Stack(
        children: [
          widget.child,
          if (_ripple != null)
            Positioned.fill(
              child: WaterRipple(
                key: _ripple,
                onDone: () {
                  if (mounted) setState(() => _ripple = null);
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// Wraps a month's summary so a finished month can be chopped the way you'd
/// seal a closed ledger page.
///
/// A quiet easter egg: long-press the summary of any month that is already
/// over and the terracotta hanko presses down onto it, with a firmer haptic
/// than the rest of the app uses. It lifts away on its own.
///
/// A month still in progress is deliberately not sealable, because it isn't
/// finished. For that month this adds no gesture at all and the card behaves
/// exactly as it did before.
class SealableSummary extends StatefulWidget {
  const SealableSummary({
    super.key,
    required this.closed,
    required this.child,
  });

  /// Whether the period this summarises is over.
  final bool closed;
  final Widget child;

  @override
  State<SealableSummary> createState() => _SealableSummaryState();
}

class _SealableSummaryState extends State<SealableSummary> {
  bool _pressed = false;
  Timer? _lift;

  @override
  void dispose() {
    _lift?.cancel();
    super.dispose();
  }

  void _press() {
    if (_pressed) return;
    // Firmer than a selection tick: this is the thump of a stamp, not a tap.
    Haptics.impact();
    setState(() => _pressed = true);
    _lift = Timer(kSealDwell, () {
      if (mounted) setState(() => _pressed = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.closed) return widget.child;

    return GestureDetector(
      onLongPress: _press,
      // Claim the whole summary, not just whatever inside it happens to be
      // hit-testable. Children still get first refusal on their own taps.
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
          widget.child,
          Positioned(
            right: Insets.md,
            bottom: Insets.md,
            child: IgnorePointer(
              child: AnimatedSwitcher(
                duration: Motion.slow,
                child: _pressed
                    ? const Opacity(
                        // Ink on paper, not a sticker.
                        opacity: 0.92,
                        child: SealStamp(size: 78),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
