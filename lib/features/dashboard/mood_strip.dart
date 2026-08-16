import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/feature_providers.dart';
import '../../app/providers.dart';
import '../../core/constants/enums.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/theme_resolver.dart';
import '../../core/utils/haptics.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../domain/services/threshold_service.dart';
import '../common/brand_watermark.dart';
import '../common/calm_widgets.dart';
import '../common/confetti_overlay.dart';
import '../common/feedback_widgets.dart';

// ---------------------------------------------------------------------------
// Pure helpers (unit-tested). These decide the "vibe" from real numbers so the
// painters stay dumb and the logic stays honest.
// ---------------------------------------------------------------------------

/// The weather of your wallet: a mood read from balance and saving, nothing
/// more. Purely for charm.
enum WalletWeather { sunny, fair, cloudy, drizzle }

/// Classifies the month's mood. Sunny when you are comfortably ahead, drizzle
/// when the balance has gone red, with two calm steps between.
WalletWeather classifyWeather({
  required bool balancePositive,
  required double savingsRate,
}) {
  if (!balancePositive) return WalletWeather.drizzle;
  if (savingsRate >= 0.20) return WalletWeather.sunny;
  if (savingsRate >= 0.05) return WalletWeather.fair;
  return WalletWeather.cloudy;
}

/// Counts the days in [txns]' month that had no expense, from the 1st up to
/// today (or the whole month if it is already in the past). Investments and
/// income do not count as spending. Pure so the sprig can be trusted.
int noSpendDaysThisMonth(List<TransactionEntity> txns, DateTime now) {
  // Anchor on the month the transactions belong to (dashboard's focused month).
  final anchor = txns.isNotEmpty ? txns.first.occurredAt : now;
  final year = anchor.year;
  final month = anchor.month;
  final isCurrentMonth = now.year == year && now.month == month;
  final lastDay = isCurrentMonth ? now.day : DateTime(year, month + 1, 0).day;

  final spentDays = <int>{};
  for (final t in txns) {
    if (t.isArchived) continue;
    if (t.occurredAt.year != year || t.occurredAt.month != month) continue;
    final isSpend = t.isOutflow && t.type != TransactionType.investment;
    if (isSpend) spentDays.add(t.occurredAt.day);
  }
  var clean = 0;
  for (var d = 1; d <= lastDay; d++) {
    if (!spentDays.contains(d)) clean++;
  }
  return clean;
}

/// The month's saving target as a fraction (0..1). Honours the first enabled
/// min-percentage threshold the user has set; falls back to a gentle 20%.
double savingsTarget(List<ThresholdRule> rules) {
  for (final r in rules) {
    if (r.enabled && r.type == ThresholdType.minPercentage) {
      final t = r.value / 100.0;
      if (t > 0) return t.clamp(0.05, 1.0);
    }
  }
  return 0.20;
}

/// Chooses which celebration to rain from the all-clear card, so the double-tap
/// feels like it *knows* the moment. Priority: beating last month's saving rate
/// (firework), then a freshly-cleared loan (coins), then autumn (leaves), else
/// confetti. Pure, so the vibe logic is testable.
ConfettiVariant celebrationVariant({
  required bool beatLastMonth,
  required bool loanCleared,
  required int month,
}) {
  if (beatLastMonth) return ConfettiVariant.firework;
  if (loanCleared) return ConfettiVariant.coins;
  if (month >= 9 && month <= 11) return ConfettiVariant.leaves;
  return ConfettiVariant.confetti;
}

// ---------------------------------------------------------------------------
// The mood strip: three quiet pieces of craft in one calm card.
// ---------------------------------------------------------------------------

/// A purely-for-delight card: an ensō that completes as you save, a sprig that
/// grows a leaf per no-spend day, and a little wallet-weather read. None of it
/// is actionable. It is here to make the month *feel* like something.
class MoodStrip extends ConsumerWidget {
  const MoodStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(monthlySummaryProvider);
    final rules = ref.watch(thresholdsStreamProvider).valueOrNull ?? const [];
    final txns = ref.watch(monthTransactionsProvider).valueOrNull ?? const [];
    final text = Theme.of(context).textTheme;
    final colors = context.colors;

    final target = savingsTarget(rules);
    final rate = summary.savingsRate;
    final progress = target <= 0 ? 0.0 : (rate / target).clamp(0.0, 1.0);
    final weather = classifyWeather(
      balancePositive: !summary.totalBalance.isNegative,
      savingsRate: rate,
    );
    final clean = noSpendDaysThisMonth(txns, DateTime.now());

    return CalmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FlourishTitle('A feeling for the month'),
          const SizedBox(height: Insets.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              EnsoMoodRing(
                progress: progress,
                rate: rate,
                complete: progress >= 1,
              ),
              const SizedBox(width: Insets.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      progress >= 1
                          ? 'Circle complete. You met your saving target.'
                          : 'Saving ${(rate * 100).round()}% '
                              'toward ${(target * 100).round()}%.',
                      style: text.bodyMedium,
                    ),
                    const SizedBox(height: Insets.md),
                    _WeatherRow(
                      weather: weather,
                      glowing: clean > kFireflyCleanDays,
                    ),
                    const SizedBox(height: Insets.md),
                    _SprigRow(cleanDays: clean),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.sm),
          Text(
            _weatherCaption(weather),
            style: text.bodySmall?.copyWith(color: colors.textFaint),
          ),
        ],
      ),
    );
  }

  static String _weatherCaption(WalletWeather w) => switch (w) {
        WalletWeather.sunny => 'Sunny, with a chance of chai.',
        WalletWeather.fair => 'Bright and mostly clear.',
        WalletWeather.cloudy => 'A little overcast. Nothing alarming.',
        WalletWeather.drizzle => 'Light drizzle. It passes.',
      };
}

/// Past [kFireflyCleanDays] no-spend days the sprig and the weather glyph pick
/// up a firefly glow. Six leaves is all the stem can hold, so beyond that the
/// only way left to show the streak still growing is to let it give off light.
const int kFireflyCleanDays = 7;

class _WeatherRow extends StatelessWidget {
  const _WeatherRow({required this.weather, this.glowing = false});

  final WalletWeather weather;
  final bool glowing;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        SizedBox(
          width: 34,
          height: 30,
          child: FireflyPulse(
            enabled: glowing,
            // Offset from the sprig's own cycle: two fireflies in one card
            // breathing in step would look mechanical.
            period: const Duration(milliseconds: 4200),
            builder: (context, clock) => CustomPaint(
              painter: _WeatherPainter(
                weather: weather,
                ink: context.colors.textSecondary,
                accent: context.colors.accent,
                sun: context.colors.warning,
                pulse: clock,
              ),
            ),
          ),
        ),
        const SizedBox(width: Insets.sm),
        Text(_label(weather), style: text.bodySmall),
      ],
    );
  }

  static String _label(WalletWeather w) => switch (w) {
        WalletWeather.sunny => 'Sunny',
        WalletWeather.fair => 'Fair',
        WalletWeather.cloudy => 'Cloudy',
        WalletWeather.drizzle => 'Drizzle',
      };
}

class _SprigRow extends StatelessWidget {
  const _SprigRow({required this.cleanDays});

  final int cleanDays;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        SizedBox(
          width: 34,
          height: 34,
          child: FireflyPulse(
            enabled: cleanDays > kFireflyCleanDays,
            builder: (context, clock) => CustomPaint(
              painter: _SprigPainter(
                leaves: cleanDays,
                ink: context.colors.textSecondary,
                leaf: context.colors.positive,
                dot: context.colors.accent,
                pulse: clock,
              ),
            ),
          ),
        ),
        const SizedBox(width: Insets.sm),
        Text(
          cleanDays == 0
              ? 'No-spend days will sprout here.'
              : '$cleanDays ${cleanDays == 1 ? 'clean day' : 'clean days'}',
          style: text.bodySmall,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// The ensō mood ring.
// ---------------------------------------------------------------------------

/// A hand-brushed ensō that fills as [progress] (savings vs target) climbs. At
/// full it closes into a near-complete circle with a warm bead where the brush
/// lifts. The rate sits quietly in the centre. Animates on change; the tween is
/// instant under reduce-motion because the value simply settles.
///
/// A quiet easter egg: long-press it and the app brushes one complete ensō for
/// you (the ring blooms to full, then eases back to where you actually are).
/// Deliberately NOT gated behind reduce-motion: it only fires from an explicit
/// long-press, never ambient motion, and it is the whole point of the gesture.
/// Easter eggs should behave the same regardless of settings.
class EnsoMoodRing extends StatefulWidget {
  const EnsoMoodRing({
    required this.progress,
    required this.rate,
    required this.complete,
    this.size = 92,
    super.key,
  });

  final double progress;
  final double rate;
  final bool complete;
  final double size;

  @override
  State<EnsoMoodRing> createState() => _EnsoMoodRingState();
}

/// How long the ring takes to travel to a new value.
const Duration kEnsoRingStroke = Duration(milliseconds: 950);

/// How long a fully brushed circle is held before it eases back.
const Duration kEnsoBloomDwell = Duration(milliseconds: 250);

/// How long the ring should take to reach a new value.
///
/// Ambient changes honour reduce-motion, but the long-press bloom does not:
/// it is an explicit gesture and the stroke is the entire payoff, so removing
/// it would leave the gesture doing nothing visible at all.
Duration ensoRingDuration({
  required bool reduceMotion,
  required bool bloomPlaying,
}) =>
    (bloomPlaying || !reduceMotion) ? kEnsoRingStroke : Duration.zero;

class _EnsoMoodRingState extends State<EnsoMoodRing> {
  late double _shown = widget.progress.clamp(0.0, 1.0);
  bool _blooming = false;

  /// Held so a bloom in flight can be cancelled outright when the ring goes
  /// away, rather than left pending and relying on a mounted check.
  Timer? _easeBack;
  Timer? _finish;

  @override
  void didUpdateWidget(EnsoMoodRing old) {
    super.didUpdateWidget(old);
    if (!_blooming && old.progress != widget.progress) {
      setState(() => _shown = widget.progress.clamp(0.0, 1.0));
    }
  }

  @override
  void dispose() {
    _easeBack?.cancel();
    _finish?.cancel();
    super.dispose();
  }

  void _bloom() {
    if (_blooming) return;
    Haptics.selection();
    setState(() {
      _blooming = true;
      _shown = 1.0;
    });
    _easeBack = Timer(kEnsoRingStroke + kEnsoBloomDwell, () {
      if (!mounted) return;
      // Stay marked as blooming through the return leg, so easing back is
      // animated too rather than snapping under reduce-motion.
      setState(() => _shown = widget.progress.clamp(0.0, 1.0));
      _finish = Timer(kEnsoRingStroke, () {
        if (!mounted) return;
        setState(() => _blooming = false);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final reduceMotion = context.reduceMotion;

    return Semantics(
      label:
          'Saving progress ${(widget.progress * 100).round()} percent of target',
      child: GestureDetector(
        onLongPress: _bloom,
        // Claim the whole square. The ring is painted, so without this the
        // corners and the hole in the middle are not hit-testable and the
        // long-press only lands if you happen to find the stroke.
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: _shown),
                duration: ensoRingDuration(
                  reduceMotion: reduceMotion,
                  bloomPlaying: _blooming,
                ),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) => CustomPaint(
                  size: Size.square(widget.size),
                  painter: _EnsoRingPainter(
                    progress: value,
                    track: colors.border,
                    ink: colors.textPrimary,
                    accent: colors.accent,
                    glow:
                        (widget.complete || _blooming) ? colors.positive : null,
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${(widget.rate * 100).round()}%',
                    style:
                        text.titleMedium?.copyWith(color: colors.textPrimary),
                  ),
                  Text(
                    'saved',
                    style: text.labelSmall?.copyWith(color: colors.textFaint),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EnsoRingPainter extends CustomPainter {
  _EnsoRingPainter({
    required this.progress,
    required this.track,
    required this.ink,
    required this.accent,
    this.glow,
  });

  final double progress;
  final Color track;
  final Color ink;
  final Color accent;
  final Color? glow;

  // The ensō leaves a small gap even when "complete", true to the motif.
  static const _start = -math.pi / 2 - 0.35;
  static const _fullSweep = math.pi * 2 * 0.94;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.40;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final stroke = size.width * 0.055;

    // Faint full track so the ring has a home even at 0%.
    canvas.drawArc(
      rect,
      _start,
      _fullSweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = stroke * 0.7
        ..color = track,
    );

    if (glow != null) {
      // A soft halo when the target is met.
      canvas.drawArc(
        rect,
        _start,
        _fullSweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = stroke * 2.4
          ..color = glow!.withValues(alpha: 0.14)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }

    final sweep = _fullSweep * progress;
    if (sweep <= 0) return;

    // The brush: slightly heavier in the middle by layering two passes.
    canvas.drawArc(
      rect,
      _start,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = stroke
        ..color = ink,
    );

    // The accent bead where the brush currently rests.
    final tip = _start + sweep;
    final beadPos = Offset(
      center.dx + radius * math.cos(tip),
      center.dy + radius * math.sin(tip),
    );
    canvas.drawCircle(
      beadPos,
      stroke * 0.62,
      Paint()
        ..style = PaintingStyle.fill
        ..color = accent,
    );
  }

  @override
  bool shouldRepaint(_EnsoRingPainter old) =>
      old.progress != progress ||
      old.ink != ink ||
      old.accent != accent ||
      old.glow != glow ||
      old.track != track;
}

// ---------------------------------------------------------------------------
// The seasonal sprig.
// ---------------------------------------------------------------------------

class _SprigPainter extends CustomPainter {
  _SprigPainter({
    required this.leaves,
    required this.ink,
    required this.leaf,
    required this.dot,
    this.pulse,
  });

  /// How many clean days to show as leaves (capped visually).
  final int leaves;
  final Color ink;
  final Color leaf;
  final Color dot;

  /// The firefly clock, or null when the leaves should sit still and dark.
  final double? pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final base = Offset(w * 0.5, h * 0.96);
    final top = Offset(w * 0.5, h * 0.10);

    final stem = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..color = ink;
    // A gently curved stem.
    final stemPath = Path()
      ..moveTo(base.dx, base.dy)
      ..quadraticBezierTo(w * 0.40, h * 0.5, top.dx, top.dy);
    canvas.drawPath(stemPath, stem);

    final leafPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = leaf.withValues(alpha: 0.85);

    // Grow up to 6 leaves up the stem, alternating sides; the crown bud shows
    // once at least one clean day exists.
    final visible = leaves.clamp(0, 6);
    for (var i = 0; i < visible; i++) {
      final t = (i + 1) / 7.0; // fraction up the stem
      final on = base + (top - base) * t;
      final left = i.isEven;
      final tipX = on.dx + (left ? -w * 0.30 : w * 0.30);
      final tipY = on.dy - h * 0.06;
      final tip = Offset(tipX, tipY);
      final bulge = w * 0.10;

      // The glow is a blurred copy of the leaf sitting under it, so the light
      // takes the leaf's own shape instead of haloing a circle around it. Each
      // leaf runs on its own phase, the way a cluster of fireflies does.
      final clock = pulse;
      if (clock != null) {
        final g = fireflyGlow(clock, phase: i * 0.17);
        paintInkLeaf(
          canvas,
          base: on,
          tip: tip,
          bulge: bulge * 1.5,
          paint: Paint()
            ..style = PaintingStyle.fill
            ..color = leaf.withValues(alpha: 0.10 + 0.30 * g)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 1.6 + 2.2 * g),
        );
      }

      paintInkLeaf(
        canvas,
        base: on,
        tip: tip,
        bulge: bulge,
        paint: leafPaint,
      );
    }
    if (leaves > 0) {
      canvas.drawCircle(
        top,
        w * 0.06,
        Paint()
          ..style = PaintingStyle.fill
          ..color = dot,
      );
    }
  }

  @override
  bool shouldRepaint(_SprigPainter old) =>
      old.leaves != leaves ||
      old.ink != ink ||
      old.leaf != leaf ||
      old.dot != dot ||
      old.pulse != pulse;
}

// ---------------------------------------------------------------------------
// The wallet weather glyphs.
// ---------------------------------------------------------------------------

class _WeatherPainter extends CustomPainter {
  _WeatherPainter({
    required this.weather,
    required this.ink,
    required this.accent,
    required this.sun,
    this.pulse,
  });

  final WalletWeather weather;
  final Color ink;
  final Color accent;
  final Color sun;

  /// The firefly clock, or null when the glyph should sit still and dark.
  final double? pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = ink;
    final sunPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..color = sun;

    // Lay a blurred copy of the same glyph down first and the light appears to
    // come off the drawing itself rather than sitting behind it as a disc.
    final clock = pulse;
    if (clock != null) {
      final g = fireflyGlow(clock, phase: 0.42);
      final blur = MaskFilter.blur(BlurStyle.normal, 2.0 + 2.6 * g);
      _glyph(
        canvas,
        size,
        stroke: Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = ink.withValues(alpha: 0.10 + 0.28 * g)
          ..maskFilter = blur,
        sunPaint: Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6
          ..strokeCap = StrokeCap.round
          ..color = sun.withValues(alpha: 0.14 + 0.38 * g)
          ..maskFilter = blur,
        rain: accent.withValues(alpha: 0.12 + 0.30 * g),
        rainBlur: blur,
      );
    }

    _glyph(canvas, size, stroke: stroke, sunPaint: sunPaint, rain: accent);
  }

  /// The glyph for [weather], drawn with whatever paints it is handed, so the
  /// glow pass and the ink pass can never drift out of shape.
  void _glyph(
    Canvas canvas,
    Size size, {
    required Paint stroke,
    required Paint sunPaint,
    required Color rain,
    MaskFilter? rainBlur,
  }) {
    switch (weather) {
      case WalletWeather.sunny:
        _sun(canvas, size, sunPaint, full: true);
      case WalletWeather.fair:
        _sun(canvas, size, sunPaint, full: false);
        _cloud(canvas, size, stroke, small: true);
      case WalletWeather.cloudy:
        _cloud(canvas, size, stroke, small: false);
      case WalletWeather.drizzle:
        _cloud(canvas, size, stroke, small: false);
        _rain(canvas, size, rain, blur: rainBlur);
    }
  }

  void _sun(Canvas c, Size s, Paint p, {required bool full}) {
    final center = full
        ? Offset(s.width * 0.5, s.height * 0.45)
        : Offset(s.width * 0.34, s.height * 0.36);
    final r = s.width * (full ? 0.22 : 0.17);
    c.drawCircle(center, r, p);
    if (!full) return;
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      final from = center + Offset(math.cos(a), math.sin(a)) * (r + 2);
      final to = center + Offset(math.cos(a), math.sin(a)) * (r + 6);
      c.drawLine(from, to, p);
    }
  }

  void _cloud(Canvas c, Size s, Paint p, {required bool small}) {
    final y = s.height * (small ? 0.62 : 0.52);
    final cx = s.width * (small ? 0.56 : 0.5);
    final scale = small ? 0.8 : 1.0;
    final path = Path()
      ..moveTo(cx - 12 * scale, y + 6)
      ..quadraticBezierTo(cx - 16 * scale, y + 6, cx - 15 * scale, y)
      ..quadraticBezierTo(
        cx - 15 * scale,
        y - 8 * scale,
        cx - 6 * scale,
        y - 7 * scale,
      )
      ..quadraticBezierTo(
        cx - 3 * scale,
        y - 14 * scale,
        cx + 4 * scale,
        y - 9 * scale,
      )
      ..quadraticBezierTo(cx + 14 * scale, y - 11 * scale, cx + 13 * scale, y)
      ..quadraticBezierTo(cx + 15 * scale, y + 6, cx + 10 * scale, y + 6)
      ..close();
    c.drawPath(path, p);
  }

  void _rain(Canvas c, Size s, Color color, {MaskFilter? blur}) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = blur == null ? 1.6 : 2.6
      ..strokeCap = StrokeCap.round
      ..maskFilter = blur
      ..color = color;
    final y = s.height * 0.74;
    for (var i = 0; i < 3; i++) {
      final x = s.width * (0.36 + i * 0.14);
      c.drawLine(Offset(x, y), Offset(x - 2, y + 5), p);
    }
  }

  @override
  bool shouldRepaint(_WeatherPainter old) =>
      old.weather != weather ||
      old.ink != ink ||
      old.accent != accent ||
      old.sun != sun;
}
