import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/theme_resolver.dart';
import '../../core/utils/haptics.dart';

/// The persistent bottom-navigation shell wrapping the five primary sections.
///
/// Uses an [IndexedStack]-backed [StatefulNavigationShell] so each tab keeps
/// its own state and scroll position. A calm, borderless bottom bar with a
/// central quick-add action (Section 4). Switching sections (by swipe or tap)
/// plays one subtle, calming fade-and-slide so movement never feels abrupt.
class AppShell extends StatefulWidget {
  const AppShell({required this.navShell, super.key});

  final StatefulNavigationShell navShell;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell>
    with SingleTickerProviderStateMixin {
  static const _items = <({IconData icon, String label})>[
    (icon: Icons.dashboard_outlined, label: 'Dashboard'),
    (icon: Icons.receipt_long_outlined, label: 'Expenses'),
    (icon: Icons.event_repeat_outlined, label: 'Payments'),
    (icon: Icons.insights_outlined, label: 'Insights'),
    (icon: Icons.settings_outlined, label: 'Settings'),
  ];

  late final AnimationController _transition = AnimationController(
    vsync: this,
    duration: Motion.base,
    value: 1,
  );

  /// Driven animations rather than per-frame maths inside a builder. [Opacity]
  /// and [Transform] accept an [Animation] and repaint without rebuilding the
  /// subtree beneath them. Here that subtree is the whole five-section
  /// [IndexedStack], so keeping it out of the animation loop is the difference
  /// between a smooth section change and a visible hitch.
  late final CurvedAnimation _eased = CurvedAnimation(
    parent: _transition,
    curve: Curves.easeOutCubic,
  );

  /// Never fades to nothing: the section stays legible throughout, so the move
  /// reads as a shift of attention rather than a blink.
  late final Animation<double> _fade =
      _eased.drive(Tween<double>(begin: 0.35, end: 1));

  /// Rebuilt on each direction change; the slide always lands on zero offset.
  late Animation<Offset> _slide = _flat;

  static const Animation<Offset> _flat =
      AlwaysStoppedAnimation<Offset>(Offset.zero);

  @override
  void dispose() {
    _eased.dispose();
    _transition.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(AppShell old) {
    super.didUpdateWidget(old);
    final prev = old.navShell.currentIndex;
    final now = widget.navShell.currentIndex;
    if (prev == now) return;

    if (context.reduceMotion) {
      _slide = _flat;
      _transition.value = 1;
      return;
    }
    // Later sections slide in from the right, earlier ones from the left.
    // Measured in logical pixels via a fixed offset on the child, not a
    // fraction of its size, so the travel stays identical on every screen.
    final from = now > prev ? 26.0 : -26.0;
    _slide = _eased.drive(
      Tween<Offset>(begin: Offset(from, 0), end: Offset.zero),
    );
    _transition.forward(from: 0);
  }

  void _go(int index) {
    // A single soft tick marks the deliberate act of moving between sections.
    Haptics.selection();
    final alreadySelected = index == widget.navShell.currentIndex;
    if (alreadySelected) {
      // Tapping the active tab returns to that tab's root screen, popping any
      // sub-sections the user has pushed (e.g. Settings > Categories).
      branchNavigatorKeys[index].currentState?.popUntil((r) => r.isFirst);
    }
    widget.navShell.goBranch(index, initialLocation: alreadySelected);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final navShell = widget.navShell;

    return PopScope(
      canPop: navShell.currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          navShell.goBranch(0, initialLocation: true);
        }
      },
      child: Scaffold(
        // Horizontal fling over the content moves between sections. Screens with
        // their own horizontal gestures (the dashboard month header, the expenses
        // filter chips) win in their own area, so this only fires elsewhere.
        body: GestureDetector(
          onHorizontalDragEnd: (d) {
            final v = d.primaryVelocity ?? 0;
            final i = navShell.currentIndex;
            if (v < -220 && i < _items.length - 1) {
              _go(i + 1);
            } else if (v > 220 && i > 0) {
              _go(i - 1);
            }
          },
          child: FadeTransition(
            opacity: _fade,
            child: AnimatedBuilder(
              animation: _slide,
              // Rasterise the section once and then merely composite it while
              // it fades and slides. Without this every frame of the
              // transition repaints five screens' worth of content.
              child: RepaintBoundary(child: navShell),
              builder: (context, child) => Transform.translate(
                offset: _slide.value,
                child: child,
              ),
            ),
          ),
        ),
        bottomNavigationBar: _CalmBottomBar(
          items: _items,
          currentIndex: navShell.currentIndex,
          onTap: _go,
          surface: colors.surface,
          border: colors.border,
          accent: colors.accent,
          faint: colors.textFaint,
        ),
      ),
    );
  }
}

class _CalmBottomBar extends StatelessWidget {
  const _CalmBottomBar({
    required this.items,
    required this.currentIndex,
    required this.onTap,
    required this.surface,
    required this.border,
    required this.accent,
    required this.faint,
  });

  final List<({IconData icon, String label})> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final Color surface;
  final Color border;
  final Color accent;
  final Color faint;

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      color: surface,
      elevation: 0,
      height: 64,
      padding: EdgeInsets.zero,
      child: Container(
        decoration: BoxDecoration(
          border:
              Border(top: BorderSide(color: border, width: Strokes.hairline)),
        ),
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: _NavItem(
                  data: items[i],
                  selected: i == currentIndex,
                  accent: accent,
                  faint: faint,
                  onTap: () => onTap(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.data,
    required this.selected,
    required this.accent,
    required this.faint,
    required this.onTap,
  });

  final ({IconData icon, String label}) data;
  final bool selected;
  final Color accent;
  final Color faint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? accent : faint;
    // Honour the OS "reduce motion" setting: no scale/colour animation there.
    final duration = context.reduceMotion ? Duration.zero : Motion.fast;
    final labelStyle =
        (Theme.of(context).textTheme.labelSmall ?? const TextStyle())
            .copyWith(color: color);
    return Semantics(
      button: true,
      selected: selected,
      label: data.label,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: selected ? 1.12 : 1.0,
              duration: duration,
              curve: Curves.easeOut,
              child: TweenAnimationBuilder<Color?>(
                tween: ColorTween(end: color),
                duration: duration,
                builder: (context, animated, _) =>
                    Icon(data.icon, size: 22, color: animated ?? color),
              ),
            ),
            const SizedBox(height: Insets.xxs),
            AnimatedDefaultTextStyle(
              duration: duration,
              style: labelStyle,
              child: Text(data.label),
            ),
          ],
        ),
      ),
    );
  }
}
