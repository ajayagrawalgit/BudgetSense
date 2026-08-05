import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/theme_resolver.dart';
import '../../../domain/services/import_service.dart';
import '../../common/calm_widgets.dart';
import 'paisa_import_screen.dart';

/// Lists the third-party budgeting apps BudgetSense can import from. Paisa is
/// first; more sources slot in here as the [ImportSource] enum grows.
class ImportHubScreen extends StatelessWidget {
  const ImportHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(title: const Text('Import from another app')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Insets.lg),
          children: [
            CalmCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Bring your history with you', style: text.titleSmall),
                  const SizedBox(height: Insets.xs),
                  Text(
                    'Switching to BudgetSense? Import everything from your old '
                    'app: expenses, income, categories, accounts, even your '
                    'name and currency, and pick up right where you left off. '
                    'It all stays on your device.',
                    style: text.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: Insets.lg),
            const _SectionLabel('Available sources'),
            CalmCard(
              padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
              child: Column(
                children: [
                  for (final source in ImportSource.values)
                    _SourceTile(
                      source: source,
                      last: source == ImportSource.values.last,
                    ),
                ],
              ),
            ),
            const SizedBox(height: Insets.lg),
            Text(
              'More apps are on the way. Don\'t see yours? Your data is yours. '
              'Reach out and we\'ll add it.',
              style: text.bodySmall?.copyWith(color: colors.textFaint),
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({required this.source, this.last = false});

  final ImportSource source;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final enabled = source.available;

    return Column(
      children: [
        InkWell(
          onTap: enabled
              ? () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => PaisaImportScreen(source: source),
                    ),
                  )
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Insets.md),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colors.accent.withValues(alpha: 0.14),
                    borderRadius: Corners.sm,
                  ),
                  child: Icon(Icons.swap_horiz, color: colors.accent, size: 22),
                ),
                const SizedBox(width: Insets.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(source.label, style: text.titleSmall),
                      const SizedBox(height: 2),
                      Text(
                        source.tagline,
                        style:
                            text.bodySmall?.copyWith(color: colors.textFaint),
                      ),
                    ],
                  ),
                ),
                if (enabled)
                  Icon(Icons.chevron_right, size: 18, color: colors.textFaint)
                else
                  Text('Coming soon', style: text.labelSmall),
              ],
            ),
          ),
        ),
        if (!last) Divider(height: 1, color: colors.border),
      ],
    );
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
