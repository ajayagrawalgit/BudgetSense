import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/theme_resolver.dart';

/// A checkmark that draws itself inside a softly scaling accent disc, for the
/// moment an action lands. Warmer than a gray SnackBar sliding up. Calls
/// [onCompleted] once the animation finishes so the caller can dismiss.
///
/// Honours the OS "reduce motion" setting: it appears fully drawn and simply
/// waits a beat before completing.
class SuccessCheck extends StatefulWidget {
  const SuccessCheck({
    this.size = 64,
    this.onCompleted,
    super.key,
  });

  final double size;
  final VoidCallback? onCompleted;

  @override
  State<SuccessCheck> createState() => _SuccessCheckState();
}

class _SuccessCheckState extends State<SuccessCheck>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: Motion.slow,
  );
  bool _notified = false;

  @override
  void initState() {
    super.initState();
    _ctrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) _notify();
    });
  }

  void _notify() {
    if (_notified) return;
    _notified = true;
    widget.onCompleted?.call();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ctrl.status == AnimationStatus.dismissed) {
      if (context.reduceMotion) {
        _ctrl.value = 1;
        // Still give the eye a moment to register before dismissing.
        Future.delayed(Motion.slow, _notify);
      } else {
        _ctrl.forward();
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) => CustomPaint(
          painter: _SuccessCheckPainter(
            progress: _ctrl.value,
            disc: colors.accent,
            tick: colors.onAccent,
          ),
        ),
      ),
    );
  }
}

class _SuccessCheckPainter extends CustomPainter {
  _SuccessCheckPainter({
    required this.progress,
    required this.disc,
    required this.tick,
  });

  final double progress;
  final Color disc;
  final Color tick;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Disc scales in over the first 60% with a gentle overshoot.
    final discT =
        Curves.easeOutBack.transform((progress / 0.6).clamp(0.0, 1.0));
    canvas.drawCircle(
      center,
      radius * discT,
      Paint()..color = disc,
    );

    // Checkmark draws from 35% to 100%.
    final tickT = ((progress - 0.35) / 0.65).clamp(0.0, 1.0);
    if (tickT <= 0) return;

    final s = size.width;
    final path = Path()
      ..moveTo(s * 0.30, s * 0.52)
      ..lineTo(s * 0.44, s * 0.66)
      ..lineTo(s * 0.72, s * 0.36);

    final drawn = _partialPath(path, tickT);
    canvas.drawPath(
      drawn,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.075
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = tick,
    );
  }

  /// Returns the leading [fraction] of [path], so the check appears to be drawn.
  Path _partialPath(Path path, double fraction) {
    final result = Path();
    for (final ui.PathMetric metric in path.computeMetrics()) {
      result.addPath(
        metric.extractPath(0, metric.length * fraction),
        Offset.zero,
      );
    }
    return result;
  }

  @override
  bool shouldRepaint(covariant _SuccessCheckPainter old) =>
      old.progress != progress || old.disc != disc || old.tick != tick;
}

/// A money figure that counts up (or down) to its new value instead of snapping,
/// so a changing balance feels alive. Formatting is delegated so currency and
/// locale stay in one place at the call site.
///
/// Honours "reduce motion": the value updates instantly there.
class AnimatedMoneyText extends StatelessWidget {
  const AnimatedMoneyText({
    required this.minorUnits,
    required this.format,
    this.style,
    this.duration = Motion.slow,
    super.key,
  });

  /// The target amount in integer minor units (never a double: exact money).
  final int minorUnits;

  /// Turns an interpolated minor-unit amount into display text.
  final String Function(int minorUnits) format;

  final TextStyle? style;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = context.reduceMotion;
    return TweenAnimationBuilder<double>(
      // A null begin means the first build shows the value with no count-up;
      // only later changes animate from the previous amount to the new one.
      tween: Tween<double>(end: minorUnits.toDouble()),
      duration: reduceMotion ? Duration.zero : duration,
      curve: Curves.easeOutCubic,
      builder: (context, value, _) => Text(format(value.round()), style: style),
    );
  }
}

/// Wraps [child] in a barely-there breathing scale pulse, to make a calm figure
/// feel alive when all is well. It stands perfectly still under reduce-motion
/// (returns the child untouched). The effect is deliberately tiny, about 1.5%,
/// so it soothes rather than distracts.
class BreathingPulse extends StatefulWidget {
  const BreathingPulse({
    required this.child,
    this.enabled = true,
    this.amplitude = 0.015,
    this.period = const Duration(milliseconds: 3800),
    super.key,
  });

  final Widget child;
  final bool enabled;
  final double amplitude;
  final Duration period;

  @override
  State<BreathingPulse> createState() => _BreathingPulseState();
}

class _BreathingPulseState extends State<BreathingPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.period,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _sync(bool animate) {
    if (animate) {
      if (!_controller.isAnimating) _controller.repeat(reverse: true);
    } else {
      _controller
        ..stop()
        ..value = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = context.reduceMotion;
    final animate = widget.enabled && !reduceMotion;
    // Reconcile after the frame so we never call repeat() during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _sync(animate);
    });
    if (!animate) return widget.child;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_controller.value);
        return Transform.scale(
          alignment: Alignment.centerLeft,
          scale: 1 + widget.amplitude * t,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// One firefly's swell at a point in its cycle: bright, then almost out, and
/// never quite the same way twice.
///
/// [clock] loops 0..1. [phase] shifts one insect against the next so a cluster
/// never blinks in unison. The two sines beat against each other, which is what
/// keeps the glow from reading as a machine blinking on a timer.
double fireflyGlow(double clock, {double phase = 0}) {
  final x = (clock + phase) % 1.0;
  final swell = math.sin(x * 2 * math.pi);
  final flicker = math.sin(x * 6 * math.pi + 1.1);
  return (0.46 + 0.36 * swell + 0.12 * flicker).clamp(0.0, 1.0);
}

/// Drives a slow firefly glow for whatever [builder] paints.
///
/// The builder is handed a looping 0..1 clock to feed [fireflyGlow], or null
/// when nothing should glow: either [enabled] is false, or the reader asked for
/// reduced motion, and something blinking at the edge of vision is exactly the
/// kind of ambient movement that setting exists to stop.
class FireflyPulse extends StatefulWidget {
  const FireflyPulse({
    required this.builder,
    this.enabled = true,
    this.period = const Duration(milliseconds: 3600),
    super.key,
  });

  final Widget Function(BuildContext context, double? clock) builder;
  final bool enabled;
  final Duration period;

  @override
  State<FireflyPulse> createState() => _FireflyPulseState();
}

class _FireflyPulseState extends State<FireflyPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.period,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _sync(bool animate) {
    if (animate) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller
        ..stop()
        ..value = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final animate = widget.enabled && !context.reduceMotion;
    // Reconcile after the frame so we never call repeat() during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _sync(animate);
    });
    if (!animate) return widget.builder(context, null);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => widget.builder(context, _controller.value),
    );
  }
}
