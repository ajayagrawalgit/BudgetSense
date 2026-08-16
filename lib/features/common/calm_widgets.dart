import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/constants/branding.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/theme_resolver.dart';
import '../../core/utils/friendly_date.dart';
import '../../core/utils/haptics.dart';
import 'brand_watermark.dart';
import 'ink_veil.dart';

/// The quiet heading that introduces a group of rows on settings-style
/// screens.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.sm, left: Insets.xs),
      child: Text(text, style: Theme.of(context).textTheme.labelMedium),
    );
  }
}

/// The app's standard circular floating action button: flat (no elevation),
/// accent-filled, calm. Each screen supplies its own icon/action so the button
/// always reflects what that particular screen does.
class CalmFab extends StatelessWidget {
  const CalmFab({
    required this.onPressed,
    this.icon = Icons.add,
    this.tooltip,
    this.heroTag,
    super.key,
  });

  final VoidCallback onPressed;
  final IconData icon;
  final String? tooltip;
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return FloatingActionButton(
      onPressed: () {
        // A single soft tick as the primary action opens. This is the one
        // place every screen's main button lives, so it stays consistent.
        Haptics.selection();
        onPressed();
      },
      heroTag: heroTag,
      elevation: 0,
      backgroundColor: colors.accent,
      foregroundColor: colors.onAccent,
      shape: const CircleBorder(),
      tooltip: tooltip,
      child: Icon(icon),
    );
  }
}

/// A [Slider] that emits a gentle haptic tick each time its value changes to a
/// new step. Use this everywhere a seek bar is needed so the tactile feedback
/// stays consistent (thresholds, and any future sliders).
class CalmSlider extends StatelessWidget {
  const CalmSlider({
    required this.value,
    required this.onChanged,
    this.min = 0.0,
    this.max = 1.0,
    this.divisions,
    this.label,
    super.key,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final double min;
  final double max;
  final int? divisions;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Slider(
      value: value,
      min: min,
      max: max,
      divisions: divisions,
      label: label,
      onChanged: (v) {
        if (v != value) Haptics.selection();
        onChanged(v);
      },
    );
  }
}

/// Animated shimmer placeholder shown while content is loading.
class ShimmerBlock extends StatefulWidget {
  const ShimmerBlock({
    this.width = double.infinity,
    this.height = 16,
    this.borderRadius = 4,
    super.key,
  });

  final double width;
  final double height;
  final double borderRadius;

  @override
  State<ShimmerBlock> createState() => _ShimmerBlockState();
}

class _ShimmerBlockState extends State<ShimmerBlock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = BorderRadius.circular(widget.borderRadius);

    // A sweeping highlight is decorative, and it loops. Reduce-motion means a
    // plain resting block: still clearly a placeholder, just not moving.
    if (context.reduceMotion) {
      if (_ctrl.isAnimating) _ctrl.stop();
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            color: colors.surfaceMuted,
          ),
        ),
      );
    }
    if (!_ctrl.isAnimating) _ctrl.repeat();

    // Skeletons come in groups, and each one animates on its own clock. The
    // boundary keeps a block's repaints from dirtying its neighbours or the
    // screen behind them.
    return RepaintBoundary(
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) => DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: LinearGradient(
                begin: Alignment(-1.0 + 2.0 * _ctrl.value, 0),
                end: Alignment(1.0 + 2.0 * _ctrl.value, 0),
                colors: [
                  colors.surfaceMuted,
                  colors.surface,
                  colors.surfaceMuted,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A skeleton placeholder for the dashboard while data loads.
class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Insets.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ShimmerBlock(height: 24, width: 140),
          const SizedBox(height: Insets.md),
          const ShimmerBlock(height: 48, width: 200),
          const SizedBox(height: Insets.lg),
          Row(
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: Insets.md),
                const Expanded(child: ShimmerBlock(height: 52)),
              ],
            ],
          ),
          const SizedBox(height: Insets.xl),
          const ShimmerBlock(height: 18, width: 120),
          const SizedBox(height: Insets.md),
          for (var i = 0; i < 4; i++) ...[
            const ShimmerBlock(height: 14),
            const SizedBox(height: Insets.sm),
          ],
        ],
      ),
    );
  }
}

/// A quiet bordered panel - the base surface for the whole app. When the glass
/// theme is active and blur is supported, it frosts its backdrop; otherwise it
/// falls back gracefully to a solid translucent fill (Section 2).
class CalmCard extends StatelessWidget {
  const CalmCard({
    required this.child,
    this.padding = Insets.card,
    this.onTap,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: Corners.md,
        border: Border.all(color: colors.border, width: Strokes.hairline),
      ),
      child: child,
    );

    final wrapped = onTap == null
        ? content
        : Semantics(
            button: true,
            child: InkWell(
              onTap: onTap,
              borderRadius: Corners.md,
              child: content,
            ),
          );

    if (colors.usesBlur) {
      return ClipRRect(
        borderRadius: Corners.md,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: wrapped,
        ),
      );
    }
    return wrapped;
  }
}

/// A [CalmCard] with a tappable header that expands/collapses its body. Used on
/// the dashboard to keep the home screen clean - secondary sections start
/// collapsed and open only when the user wants them.
class CollapsibleCard extends StatefulWidget {
  const CollapsibleCard({
    required this.title,
    required this.child,
    this.initiallyExpanded = false,
    this.subtitle,
    super.key,
  });

  final String title;
  final Widget child;
  final bool initiallyExpanded;

  /// Optional trailing summary shown on the collapsed header (e.g. a total).
  final Widget? subtitle;

  @override
  State<CollapsibleCard> createState() => _CollapsibleCardState();
}

class _CollapsibleCardState extends State<CollapsibleCard> {
  late bool _open = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = context.colors;
    return CalmCard(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.lg,
        vertical: Insets.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              setState(() => _open = !_open);
              Haptics.selection();
            },
            borderRadius: Corners.sm,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Insets.sm),
              child: Row(
                children: [
                  Expanded(child: Text(widget.title, style: text.titleMedium)),
                  if (widget.subtitle != null && !_open) ...[
                    widget.subtitle!,
                    const SizedBox(width: Insets.sm),
                  ],
                  AnimatedRotation(
                    turns: _open ? 0.5 : 0,
                    duration: Motion.fast,
                    child: Icon(
                      Icons.expand_more,
                      size: 20,
                      color: colors.textFaint,
                    ),
                  ),
                ],
              ),
            ),
          ),
          ClipRect(
            child: AnimatedSize(
              duration: Motion.base,
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _open
                  ? Padding(
                      padding: const EdgeInsets.only(
                        top: Insets.xs,
                        bottom: Insets.sm,
                      ),
                      child: widget.child,
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ),
        ],
      ),
    );
  }
}

/// A small labelled figure used on the dashboard summary grid.
class StatTile extends StatelessWidget {
  const StatTile({
    required this.label,
    required this.value,
    this.valueColor,
    this.icon,
    this.revealed = true,
    this.veilSeed = 0,
    super.key,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final IconData? icon;

  /// When false the figure is brushed over with an [InkVeil]. The label and
  /// icon stay legible: it is the amount that is private, not what it measures.
  final bool revealed;

  /// Varies the brushwork so a row of tiles does not repeat one identical mark.
  final int veilSeed;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = context.colors;
    return Semantics(
      label: revealed ? '$label: $value' : '$label: hidden',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: colors.textFaint),
                const SizedBox(width: Insets.xs),
              ],
              Flexible(
                child: Text(
                  label,
                  style: text.labelMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.xs),
          InkVeil(
            revealed: revealed,
            seed: veilSeed,
            child: Text(
              value,
              style: text.titleMedium?.copyWith(color: valueColor),
            ),
          ),
        ],
      ),
    );
  }
}

/// A gentle horizontal progress bar for category / threshold usage. Uses text
/// and icon cues alongside color so status never depends on color alone.
class CalmProgressBar extends StatelessWidget {
  const CalmProgressBar({
    required this.fraction,
    required this.color,
    this.height = 8,
    super.key,
  });

  final double fraction; // 0.0 to 1.0+, clamped for display
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final display = fraction.clamp(0.0, 1.0);
    return Semantics(
      value: '${(fraction * 100).round()}%',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: Stack(
          children: [
            Container(height: height, color: colors.surfaceMuted),
            FractionallySizedBox(
              widthFactor: display,
              child: Container(height: height, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hand-drawn line-art motifs for empty states, painted with a [CustomPainter]
/// (no image assets, no packages). Quiet ink strokes with a single warm accent -
/// a small piece of craft where most apps show a flat glyph.
enum CalmIllustration { sprig, journal, calendar, chart, enso }

/// Standard empty-state used across list screens - warm, not clinical. Prefers a
/// hand-drawn [illustration] when one is given; otherwise falls back to [icon]
/// so existing call sites (including error states) keep their exact look.
class CalmEmptyState extends StatelessWidget {
  const CalmEmptyState({
    required this.title,
    required this.message,
    this.icon = Icons.spa_outlined,
    this.illustration,
    this.brandAsset,
    super.key,
  });

  final String title;
  final String message;
  final IconData icon;
  final CalmIllustration? illustration;

  /// A single-colour brand mask from [BrandAssets], drawn in the faint ink
  /// colour. Reserved for the few states that carry real weight (a first run,
  /// an empty journal); the painted [illustration] motifs cover the rest.
  final String? brandAsset;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = context.colors;
    final art = illustration;
    final brand = brandAsset;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Insets.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (brand != null)
              BrandMarks.tinted(brand, color: colors.textFaint, size: 92)
            else if (art != null)
              SizedBox(
                width: 76,
                height: 76,
                child: CustomPaint(
                  painter: _CalmIllustrationPainter(
                    illustration: art,
                    ink: colors.textFaint,
                    accent: colors.accent,
                  ),
                ),
              )
            else
              Icon(icon, size: 40, color: colors.textFaint),
            const SizedBox(height: Insets.lg),
            Text(title, style: text.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: Insets.sm),
            Text(
              message,
              style: text.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Paints the [CalmIllustration] motifs. Coordinates are authored in a 72x72
/// space and scaled to the widget's box, so the same math works at any size.
class _CalmIllustrationPainter extends CustomPainter {
  _CalmIllustrationPainter({
    required this.illustration,
    required this.ink,
    required this.accent,
  });

  final CalmIllustration illustration;
  final Color ink;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 72.0, size.height / 72.0);

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = ink;
    final soft = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..color = ink.withValues(alpha: 0.55);
    final dot = Paint()
      ..style = PaintingStyle.fill
      ..color = accent;

    switch (illustration) {
      case CalmIllustration.sprig:
        _paintSprig(canvas, stroke, soft, dot);
      case CalmIllustration.journal:
        _paintJournal(canvas, stroke, soft, dot);
      case CalmIllustration.calendar:
        _paintCalendar(canvas, stroke, soft, dot);
      case CalmIllustration.chart:
        _paintChart(canvas, stroke, soft, dot);
      case CalmIllustration.enso:
        _paintEnso(canvas, dot);
    }
  }

  void _paintSprig(Canvas c, Paint stroke, Paint soft, Paint dot) {
    final stem = Path()
      ..moveTo(36, 64)
      ..quadraticBezierTo(30, 40, 36, 16);
    c.drawPath(stem, stroke);
    paintInkLeaf(
      c,
      base: const Offset(34, 50),
      tip: const Offset(19, 44),
      bulge: 5,
      paint: soft,
    );
    paintInkLeaf(
      c,
      base: const Offset(37, 42),
      tip: const Offset(53, 36),
      bulge: 5,
      paint: soft,
    );
    paintInkLeaf(
      c,
      base: const Offset(34, 34),
      tip: const Offset(21, 27),
      bulge: 4,
      paint: soft,
    );
    c.drawCircle(const Offset(36, 15), 3, dot);
  }

  void _paintJournal(Canvas c, Paint stroke, Paint soft, Paint dot) {
    const spineTop = Offset(36, 22);
    const spineBot = Offset(36, 54);
    final left = Path()
      ..moveTo(spineTop.dx, spineTop.dy)
      ..lineTo(14, 26)
      ..lineTo(14, 50)
      ..lineTo(spineBot.dx, spineBot.dy);
    final right = Path()
      ..moveTo(spineTop.dx, spineTop.dy)
      ..lineTo(58, 26)
      ..lineTo(58, 50)
      ..lineTo(spineBot.dx, spineBot.dy);
    c
      ..drawPath(left, stroke)
      ..drawPath(right, stroke)
      ..drawLine(spineTop, spineBot, stroke)
      ..drawLine(const Offset(20, 33), const Offset(31, 32), soft)
      ..drawLine(const Offset(20, 39), const Offset(31, 38), soft)
      ..drawLine(const Offset(41, 32), const Offset(52, 33), soft)
      ..drawLine(const Offset(41, 38), const Offset(52, 39), soft)
      ..drawCircle(const Offset(36, 22), 2.6, dot);
  }

  void _paintCalendar(Canvas c, Paint stroke, Paint soft, Paint dot) {
    final body = RRect.fromRectAndRadius(
      const Rect.fromLTWH(14, 18, 44, 40),
      const Radius.circular(5),
    );
    c
      ..drawRRect(body, stroke)
      // Header rule.
      ..drawLine(const Offset(14, 30), const Offset(58, 30), stroke)
      // Two hanging rings.
      ..drawLine(const Offset(26, 14), const Offset(26, 22), soft)
      ..drawLine(const Offset(46, 14), const Offset(46, 22), soft)
      // A few day ticks.
      ..drawLine(const Offset(22, 40), const Offset(30, 40), soft)
      ..drawLine(const Offset(38, 40), const Offset(50, 40), soft)
      ..drawLine(const Offset(22, 48), const Offset(30, 48), soft)
      // The marked day.
      ..drawCircle(const Offset(44, 48), 3, dot);
  }

  void _paintChart(Canvas c, Paint stroke, Paint soft, Paint dot) {
    // Axes.
    c.drawLine(const Offset(16, 14), const Offset(16, 56), stroke);
    c.drawLine(const Offset(16, 56), const Offset(58, 56), stroke);
    // A gently rising line.
    final line = Path()
      ..moveTo(20, 48)
      ..lineTo(30, 40)
      ..lineTo(40, 44)
      ..lineTo(52, 24);
    c.drawPath(line, soft);
    // The high point.
    c.drawCircle(const Offset(52, 24), 3, dot);
  }

  void _paintEnso(Canvas c, Paint dot) {
    final start = paintEnsoRing(
      c,
      center: const Offset(36, 36),
      radius: 22,
      color: ink,
      strokeWidth: 3.2,
    );
    // The accent bead where the brush lifts.
    c.drawCircle(start, 3, dot);
  }

  @override
  bool shouldRepaint(covariant _CalmIllustrationPainter old) =>
      old.illustration != illustration ||
      old.ink != ink ||
      old.accent != accent;
}

/// Month navigation bar with left/right arrows and a centered month label.
/// Tapping the label resets to the current month.
class MonthNavigator extends StatelessWidget {
  const MonthNavigator({
    required this.focusedMonth,
    required this.onPrevious,
    required this.onNext,
    required this.onReset,
    super.key,
  });

  final DateTime focusedMonth;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onReset;

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return focusedMonth.year == now.year && focusedMonth.month == now.month;
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = context.colors;
    final label = FriendlyDate.monthYear(focusedMonth);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.lg,
        vertical: Insets.sm,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              Haptics.selection();
              onPrevious();
            },
            tooltip: 'Previous month',
            iconSize: 22,
            color: colors.textPrimary,
          ),
          GestureDetector(
            onTap: _isCurrentMonth
                ? null
                : () {
                    Haptics.selection();
                    onReset();
                  },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: text.titleSmall),
                if (!_isCurrentMonth) ...[
                  const SizedBox(width: Insets.xs),
                  Icon(Icons.today, size: 14, color: colors.accent),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _isCurrentMonth
                ? null
                : () {
                    Haptics.selection();
                    onNext();
                  },
            tooltip: 'Next month',
            iconSize: 22,
            color: _isCurrentMonth ? colors.textFaint : colors.textPrimary,
          ),
        ],
      ),
    );
  }
}
