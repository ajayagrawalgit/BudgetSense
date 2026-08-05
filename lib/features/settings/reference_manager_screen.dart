import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/feature_providers.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/seed/default_data.dart';
import '../../domain/entities/config_entities.dart';
import '../common/calm_widgets.dart';

/// A named reference item the generic manager can render.
typedef RefItem = ({String id, String name});

/// Generic manager UI for simple named reference lists (accounts, payment
/// methods). One body, two thin wrappers - no duplicated list/edit code.
class ReferenceManagerBody extends StatelessWidget {
  const ReferenceManagerBody({
    required this.title,
    required this.emptyMessage,
    required this.items,
    required this.onSave,
    required this.onDelete,
    super.key,
  });

  final String title;
  final String emptyMessage;
  final List<RefItem> items;
  final void Function(String? id, String name) onSave;
  final void Function(String id) onDelete;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _edit(context, null),
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: items.isEmpty
            ? CalmEmptyState(
                title: 'Nothing here yet',
                message: emptyMessage,
                icon: Icons.list_alt_outlined,
                illustration: CalmIllustration.coin,
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                  Insets.lg,
                  Insets.lg,
                  Insets.lg,
                  96,
                ),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: Insets.sm),
                itemBuilder: (context, i) {
                  final item = items[i];
                  return CalmCard(
                    onTap: () => _edit(context, item),
                    padding: const EdgeInsets.symmetric(
                      horizontal: Insets.lg,
                      vertical: Insets.md,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.name,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18),
                          onPressed: () => onDelete(item.id),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }

  Future<void> _edit(BuildContext context, RefItem? existing) async {
    final ctrl = TextEditingController(text: existing?.name ?? '');
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(existing == null ? 'Add $title' : 'Edit'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) onSave(existing?.id, name);
  }
}

/// Accounts manager.
class AccountsManagerScreen extends ConsumerWidget {
  const AccountsManagerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsStreamProvider).valueOrNull ?? const [];
    final repo = ref.read(accountRepositoryProvider);
    return ReferenceManagerBody(
      title: 'Accounts',
      emptyMessage: 'Add accounts like Cash, Bank, or Card.',
      items: [for (final a in accounts) (id: a.id, name: a.name)],
      onSave: (id, name) {
        final now = DateTime.now();
        final existing = accounts.where((a) => a.id == id).firstOrNull;
        repo.upsert(
          AccountEntity(
            id: id ?? DefaultDataSeeder.newId(),
            name: name,
            sortOrder: existing?.sortOrder ?? accounts.length,
            createdAt: existing?.createdAt ?? now,
            updatedAt: now,
          ),
        );
      },
      onDelete: repo.delete,
    );
  }
}

/// Payment methods manager.
class PaymentMethodsManagerScreen extends ConsumerWidget {
  const PaymentMethodsManagerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final methods =
        ref.watch(paymentMethodsStreamProvider).valueOrNull ?? const [];
    final repo = ref.read(paymentMethodRepositoryProvider);
    return ReferenceManagerBody(
      title: 'Payment methods',
      emptyMessage: 'Add methods like UPI, Cash, or Credit card.',
      items: [for (final m in methods) (id: m.id, name: m.name)],
      onSave: (id, name) {
        final now = DateTime.now();
        final existing = methods.where((m) => m.id == id).firstOrNull;
        repo.upsert(
          PaymentMethodEntity(
            id: id ?? DefaultDataSeeder.newId(),
            name: name,
            sortOrder: existing?.sortOrder ?? methods.length,
            createdAt: existing?.createdAt ?? now,
            updatedAt: now,
          ),
        );
      },
      onDelete: repo.delete,
    );
  }
}
