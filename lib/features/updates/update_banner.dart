import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/update_providers.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/theme_resolver.dart';
import '../../data/updates/update_service.dart';
import '../common/calm_widgets.dart';

/// A gentle, dismissible "new version is ready" banner for sideloaded builds.
///
/// It NEVER forces or blocks. The app works exactly the same whether the user
/// updates or not; this is only an offer. Shows nothing unless an update is
/// genuinely available (or a download is in progress).
class UpdateBanner extends ConsumerWidget {
  const UpdateBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(updateServiceProvider);
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final s = service.state;
        if (!s.hasUpdate) return const SizedBox.shrink();
        return Padding(
          padding:
              const EdgeInsets.fromLTRB(Insets.lg, Insets.md, Insets.lg, 0),
          child: _Card(service: service, state: s),
        );
      },
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.service, required this.state});
  final UpdateService service;
  final UpdateState state;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = context.colors;
    final m = state.manifest!;
    final busy = state.status == UpdateStatus.downloading ||
        state.status == UpdateStatus.verifying ||
        state.status == UpdateStatus.installing;

    return CalmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.eco_outlined, size: 18, color: colors.positive),
              const SizedBox(width: Insets.xs),
              Expanded(
                child: Text('A new version is ready', style: text.titleSmall),
              ),
              Text('v${m.versionName}',
                  style: text.labelMedium?.copyWith(color: colors.textFaint)),
            ],
          ),
          const SizedBox(height: Insets.xs),
          // Warm, human, no pressure.
          Text(
            busy
                ? _busyLine(state.status)
                : 'Whenever you are ready, there is a fresh version waiting. No '
                    'rush at all. Everything you have stays exactly where it is; '
                    'this just brings the newest improvements over.',
            style: text.bodyMedium,
          ),
          if (!busy && m.notes.isNotEmpty) ...[
            const SizedBox(height: Insets.xs),
            Text("What's new: ${m.notes}",
                style: text.bodySmall?.copyWith(color: colors.textFaint)),
          ],
          if (state.status == UpdateStatus.downloading) ...[
            const SizedBox(height: Insets.sm),
            Semantics(
              label: 'Downloading update '
                  '${(state.progress * 100).round()} percent',
              child: CalmProgressBar(
                fraction: state.progress,
                color: colors.positive,
              ),
            ),
          ],
          if (state.message != null) ...[
            const SizedBox(height: Insets.xs),
            Text(state.message!,
                style: text.bodySmall?.copyWith(color: colors.critical)),
          ],
          const SizedBox(height: Insets.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (!busy) ...[
                TextButton(
                  onPressed: () => service.dismiss(),
                  child: const Text('Maybe later'),
                ),
                const SizedBox(width: Insets.xs),
                FilledButton.icon(
                  onPressed: () => service.downloadAndInstall(),
                  icon: const Icon(Icons.download_outlined, size: 16),
                  label: const Text('Update now'),
                ),
              ] else
                const Padding(
                  padding: EdgeInsets.only(right: Insets.sm),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _busyLine(UpdateStatus status) => switch (status) {
        UpdateStatus.downloading => 'Getting the new version...',
        UpdateStatus.verifying =>
          'Just checking the download is safe before installing...',
        UpdateStatus.installing => 'Opening the installer for you...',
        _ => 'Working on it...',
      };
}
