import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_info.dart';
import '../../core/constants/branding.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/theme_resolver.dart';
import '../../core/utils/app_log.dart';
import '../common/calm_widgets.dart';

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text("Couldn't open that link. Maybe try again in a moment?"),
        ),
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
            // App mark.
            Center(
              child: Column(
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
                    child: Image.asset(kBrandMarkAsset),
                  ),
                  const SizedBox(height: Insets.md),
                  Text(AppInfo.appName, style: text.headlineSmall),
                  const SizedBox(height: Insets.xs),
                  Text(
                    AppInfo.tagline,
                    style:
                        text.bodyMedium?.copyWith(color: colors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: Insets.xs),
                  Text(
                    'Version ${AppInfo.version}',
                    style: text.bodySmall?.copyWith(color: colors.textFaint),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Insets.xl),

            // Author credit.
            const _SectionLabel('Crafted by'),
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
            const _SectionLabel('Open source'),
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.sm, left: Insets.xs),
      child: Text(text, style: Theme.of(context).textTheme.labelMedium),
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
