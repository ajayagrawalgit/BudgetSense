import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/constants/enums.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/category_icons.dart';
import '../../core/theme/theme_resolver.dart';
import '../../core/utils/friendly_date.dart';
import '../../domain/entities/transaction_entity.dart';
import '../common/calm_widgets.dart';
import 'settings_controller.dart';
import '../../core/utils/haptics.dart';

/// The Trash can (Settings > Trash). Everything the user swipes away or removes
/// is soft-deleted here (archived), not destroyed. From here they can restore
/// an item or delete it forever. Trashed items are included in backups and
/// restored on import, so nothing is ever silently lost.
class TrashScreen extends ConsumerWidget {
  const TrashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(archivedTransactionsProvider);
    final settings = ref.watch(settingsControllerProvider).valueOrNull;
    final symbol = settings?.currencySymbol ?? '₹';
    final locale = settings?.localeCode;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trash'),
        actions: [
          if ((async.valueOrNull ?? const []).isNotEmpty)
            TextButton(
              onPressed: () => _emptyTrash(context, ref),
              child: const Text('Empty'),
            ),
        ],
      ),
      body: SafeArea(
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => CalmEmptyState(
            title: 'Could not load',
            message: '$e',
            icon: Icons.error_outline,
          ),
          data: (items) {
            if (items.isEmpty) {
              return const CalmEmptyState(
                title: 'Trash is empty',
                message:
                    'Removed transactions land here. You can restore them any '
                    'time, and they are always included in your backups.',
                icon: Icons.delete_outline,
                illustration: CalmIllustration.sprig,
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(Insets.lg),
              itemCount: items.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: Insets.sm),
              itemBuilder: (context, i) {
                if (i == 0) return _TrashHint(count: items.length);
                final t = items[i - 1];
                return _TrashRow(
                  txn: t,
                  symbol: symbol,
                  locale: locale,
                  compact: settings?.numberFormatCompact ?? false,
                  onRestore: () => _restore(context, ref, t),
                  onDeleteForever: () => _deleteForever(context, ref, t),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _restore(
    BuildContext context,
    WidgetRef ref,
    TransactionEntity t,
  ) async {
    await ref.read(transactionRepositoryProvider).unarchive(t.id);
    Haptics.confirm();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text('Restored "${t.name}"')));
  }

  Future<void> _deleteForever(
    BuildContext context,
    WidgetRef ref,
    TransactionEntity t,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete forever?'),
        content: Text(
          '"${t.name}" will be permanently removed. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete forever'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(transactionRepositoryProvider).delete(t.id);
    Haptics.impact();
  }

  Future<void> _emptyTrash(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Empty Trash?'),
        content: const Text(
          'Every item in the Trash will be permanently deleted. This cannot be '
          'undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Empty Trash'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(transactionRepositoryProvider).emptyTrash();
    Haptics.impact();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        const SnackBar(content: Text('Trash emptied. A clean slate.')),
      );
  }
}

class _TrashHint extends StatelessWidget {
  const _TrashHint({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.sm),
      child: Text(
        '$count item${count == 1 ? '' : 's'} in Trash. Restore keeps them in '
        'your history; deleting forever is permanent.',
        style: text.bodySmall?.copyWith(color: colors.textFaint),
      ),
    );
  }
}

class _TrashRow extends StatelessWidget {
  const _TrashRow({
    required this.txn,
    required this.symbol,
    required this.locale,
    this.compact = false,
    required this.onRestore,
    required this.onDeleteForever,
  });

  final TransactionEntity txn;
  final String symbol;
  final String? locale;
  final bool compact;
  final VoidCallback onRestore;
  final VoidCallback onDeleteForever;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = context.colors;
    final prefix = txn.isOutflow ? '-' : '+';
    final amountColor = txn.isOutflow ? colors.negative : colors.positive;

    return CalmCard(
      padding: const EdgeInsets.all(Insets.md),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: Insets.md),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: colors.surfaceMuted,
                shape: BoxShape.circle,
              ),
              child: Icon(
                categoryIcon(
                  txn.iconCodePoint ?? kFallbackCategoryIcon.codePoint,
                ),
                size: 18,
                color: colors.textFaint,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(txn.name, style: text.titleSmall),
                const SizedBox(height: 2),
                Text(
                  '${txn.type.label} · '
                  '${FriendlyDate.short(txn.occurredAt, locale: locale)}',
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
          Text(
            '$prefix${txn.amount.format(currencySymbol: symbol, locale: locale, compact: compact)}',
            style: text.titleSmall?.copyWith(color: amountColor),
          ),
          IconButton(
            tooltip: 'Restore',
            icon: Icon(Icons.restore, size: 20, color: colors.positive),
            onPressed: onRestore,
          ),
          IconButton(
            tooltip: 'Delete forever',
            icon: Icon(
              Icons.delete_forever_outlined,
              size: 20,
              color: colors.critical,
            ),
            onPressed: onDeleteForever,
          ),
        ],
      ),
    );
  }
}
