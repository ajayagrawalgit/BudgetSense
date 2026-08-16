import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_info.dart';
import '../../core/constants/branding.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/theme_resolver.dart';
import '../../core/utils/app_log.dart';
import '../../core/utils/haptics.dart';
import '../common/app_feedback.dart';
import '../common/calm_widgets.dart';
import '../common/ink_flourishes.dart';

/// About & credits (Section 18). A calm, elegant acknowledgement of the person
/// who designed and built BudgetSense, plus links to the source project.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Future<void> _open(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    var ok = false;
    try {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e, s) {
      AppLog.error('Failed to open link', error: e, stackTrace: s);
    }
    if (!ok && context.mounted) {
      AppLog.error('Could not open link: $url');
      context.showMessage(
        "Couldn't open that link. Maybe try again in a moment?",
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Insets.lg),
          children: [
            const SizedBox(height: Insets.md),
            const Center(child: _AppMark()),
            const SizedBox(height: Insets.xl),

            // Author credit.
            const SectionLabel('Crafted by'),
            CalmCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: colors.surfaceMuted,
                        child: Text(
                          _initials(AppInfo.authorName),
                          style: text.titleMedium
                              ?.copyWith(color: colors.textPrimary),
                        ),
                      ),
                      const SizedBox(width: Insets.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(AppInfo.authorName, style: text.titleSmall),
                            const SizedBox(height: 2),
                            Text(
                              'Designer & developer',
                              style: text.bodySmall
                                  ?.copyWith(color: colors.textFaint),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: Insets.xl),
                  _LinkRow(
                    icon: Icons.code,
                    label: 'GitHub',
                    value: 'ajayagrawalgit',
                    onTap: () => _open(context, AppInfo.githubUrl),
                  ),
                  const SizedBox(height: Insets.md),
                  _LinkRow(
                    icon: Icons.work_outline,
                    label: 'LinkedIn',
                    value: 'theajayagrawal',
                    onTap: () => _open(context, AppInfo.linkedInUrl),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Insets.lg),

            // Open source.
            const SectionLabel('Open source'),
            CalmCard(
              child: AppInfo.hasRepositoryLink
                  ? _LinkRow(
                      icon: Icons.public,
                      label: 'Source code',
                      value: 'View on GitHub',
                      onTap: () => _open(context, AppInfo.repositoryUrl),
                    )
                  : Row(
                      children: [
                        Icon(
                          Icons.public,
                          size: 20,
                          color: colors.textFaint,
                        ),
                        const SizedBox(width: Insets.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Source code', style: text.bodyLarge),
                              const SizedBox(height: 2),
                              Text(
                                'Open source · coming soon',
                                style: text.bodySmall
                                    ?.copyWith(color: colors.textFaint),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: Insets.md),
            // The packages and fonts BudgetSense bundles are distributed under
            // licences that require their notices to travel with the app.
            // Flutter collects them for us; this just makes them reachable.
            CalmCard(
              child: _LinkRow(
                icon: Icons.description_outlined,
                label: 'Open source licences',
                value: 'Notices for the software BudgetSense uses',
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: AppInfo.appName,
                  applicationVersion: 'Version ${AppInfo.version}',
                  applicationLegalese: '© 2026 ${AppInfo.authorName}. '
                      'Released under the GNU GPL v3.0.',
                ),
              ),
            ),
            const SizedBox(height: Insets.xl),

            // BudgetSense ships no self-updater: downloading and installing an
            // APK from inside the app is a code-execution channel that bypasses
            // the platform's signature verification. This row only opens the
            // releases page in the browser.
            const SectionLabel('Updates'),
            CalmCard(
              child: _LinkRow(
                icon: Icons.system_update_outlined,
                label: 'Check for new releases',
                value: 'Opens the releases page in your browser',
                onTap: () => _open(context, AppInfo.releasesUrl),
              ),
            ),
            const SizedBox(height: Insets.xl),
            Center(
              child: Text(
                'Made with care · offline-first · your data stays yours',
                style: text.bodySmall?.copyWith(color: colors.textFaint),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }
}

/// The logo, name, tagline and version at the top of About.
///
/// A quiet easter egg lives on the version line: tap it seven times, the way
/// Android has trained everyone to, and the mark redraws itself as an ensō
/// while the tagline turns to handwriting. It settles back on its own. Taps
/// stop counting after a couple of seconds of stillness, so nobody stumbles
/// into it by accident, and the version line is not a control, so nothing real
/// is intercepted.
class _AppMark extends StatefulWidget {
  const _AppMark();

  @override
  State<_AppMark> createState() => _AppMarkState();
}

class _AppMarkState extends State<_AppMark> {
  /// The Android convention. Seven taps, no more, no fewer.
  static const _tapsToReveal = 7;

  /// Long enough to be unhurried, short enough that idle taps do not add up.
  static const _tapWindow = Duration(seconds: 2);

  int _taps = 0;
  bool _revealed = false;
  Timer? _forget;
  Timer? _settle;

  @override
  void dispose() {
    _forget?.cancel();
    _settle?.cancel();
    super.dispose();
  }

  void _onVersionTap() {
    if (_revealed) return;
    _forget?.cancel();
    _taps++;

    if (_taps >= _tapsToReveal) {
      _taps = 0;
      Haptics.confirm();
      setState(() => _revealed = true);
      return;
    }

    // A faint tick once you are clearly counting, so the last few taps feel
    // like they are landing somewhere.
    if (_taps >= 4) Haptics.selection();
    _forget = Timer(_tapWindow, () {
      if (mounted) _taps = 0;
    });
  }

  void _settleBack() {
    if (mounted) setState(() => _revealed = false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final tagline = text.bodyMedium?.copyWith(color: colors.textSecondary) ??
        const TextStyle();

    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          padding: const EdgeInsets.all(Insets.md),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: Corners.lg,
            border: Border.all(
              color: colors.border,
              width: Strokes.hairline,
            ),
          ),
          child: AnimatedSwitcher(
            duration: Motion.slow,
            child: _revealed
                ? BrushedEnso(
                    key: const ValueKey('enso'),
                    size: 76,
                    color: colors.textPrimary,
                    onDone: () {
                      _settle?.cancel();
                      _settle = Timer(kEnsoBrushDwell, _settleBack);
                    },
                  )
                : Image.asset(
                    BrandMarks.of(context),
                    key: const ValueKey('mark'),
                    excludeFromSemantics: true,
                  ),
          ),
        ),
        const SizedBox(height: Insets.md),
        Text(AppInfo.appName, style: text.headlineSmall),
        const SizedBox(height: Insets.xs),
        AnimatedDefaultTextStyle(
          duration: Motion.slow,
          // Both styles have to come off the same base: interpolating between
          // a theme style and a bare TextStyle throws on the inherit mismatch.
          style: _revealed ? handwrittenFrom(tagline) : tagline,
          textAlign: TextAlign.center,
          child: const Text(AppInfo.tagline, textAlign: TextAlign.center),
        ),
        const SizedBox(height: Insets.xs),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _onVersionTap,
          child: Padding(
            // A little room to tap without turning it into a visible button.
            padding: const EdgeInsets.symmetric(
              horizontal: Insets.md,
              vertical: Insets.xs,
            ),
            child: Text(
              'Version ${AppInfo.version}',
              style: text.bodySmall?.copyWith(color: colors.textFaint),
            ),
          ),
        ),
      ],
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: Corners.sm,
      child: Row(
        children: [
          Icon(icon, size: 20, color: colors.accent),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: text.bodyLarge),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: text.bodySmall?.copyWith(color: colors.textFaint),
                ),
              ],
            ),
          ),
          Icon(Icons.open_in_new, size: 16, color: colors.textFaint),
        ],
      ),
    );
  }
}
