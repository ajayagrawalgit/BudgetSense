import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/constants/enums.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/category_icons.dart';
import '../../core/theme/theme_resolver.dart';
import '../../core/utils/friendly_date.dart';
import '../../data/seed/default_data.dart';
import '../../domain/entities/transaction_entity.dart';
import '../common/calm_widgets.dart';
import '../quick_add/quick_add_sheet.dart';
import '../settings/settings_controller.dart';
import '../../core/utils/haptics.dart';

enum _Sort { dateDesc, dateAsc, amountDesc, amountAsc }

/// Searchable, filterable, groupable transaction history with sort, edit,
/// duplicate, archive, bulk selection and undo-on-delete (Section 13).
class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  String _query = '';
  TransactionType? _typeFilter;
  _Sort _sort = _Sort.dateDesc;
  bool _groupByDate = true;
  final Set<String> _selected = {};

  bool get _selecting => _selected.isNotEmpty;

  List<TransactionEntity> _apply(List<TransactionEntity> all) {
    final filtered = all.where((t) {
      final q = _query.isEmpty ||
          t.name.toLowerCase().contains(_query) ||
          (t.notes?.toLowerCase().contains(_query) ?? false);
      final typeOk = _typeFilter == null || t.type == _typeFilter;
      return q && typeOk;
    }).toList();

    switch (_sort) {
      case _Sort.dateDesc:
        filtered.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
      case _Sort.dateAsc:
        filtered.sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
      case _Sort.amountDesc:
        filtered.sort((a, b) => b.amount.compareTo(a.amount));
      case _Sort.amountAsc:
        filtered.sort((a, b) => a.amount.compareTo(b.amount));
    }
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final txnsAsync = ref.watch(monthTransactionsProvider);
    final settings = ref.watch(settingsControllerProvider).valueOrNull;
    final symbol = settings?.currencySymbol ?? '₹';
    final locale = settings?.localeCode;

    return Scaffold(
      appBar: AppBar(
        title: Text(_selecting ? '${_selected.length} selected' : 'Expenses'),
        actions: [
          if (_selecting)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _bulkDelete(txnsAsync.valueOrNull ?? const []),
            )
          else ...[
            PopupMenuButton<_Sort>(
              icon: const Icon(Icons.sort),
              onSelected: (s) => setState(() => _sort = s),
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: _Sort.dateDesc,
                  child: Text('Newest first'),
                ),
                PopupMenuItem(
                  value: _Sort.dateAsc,
                  child: Text('Oldest first'),
                ),
                PopupMenuItem(
                  value: _Sort.amountDesc,
                  child: Text('Amount high→low'),
                ),
                PopupMenuItem(
                  value: _Sort.amountAsc,
                  child: Text('Amount low→high'),
                ),
              ],
            ),
            IconButton(
              icon: Icon(_groupByDate ? Icons.view_agenda : Icons.list),
              tooltip: 'Group by date',
              onPressed: () => setState(() => _groupByDate = !_groupByDate),
            ),
          ],
        ],
      ),
      floatingActionButton: _selecting
          ? null
          : CalmFab(
              tooltip: 'Add expense',
              heroTag: 'fab_expenses',
              onPressed: () => QuickAddSheet.show(context),
            ),
      body: SafeArea(
        child: Column(
          children: [
            MonthNavigator(
              focusedMonth: ref.watch(focusedMonthProvider),
              onPrevious: () {
                final current = ref.read(focusedMonthProvider);
                ref.read(focusedMonthProvider.notifier).state =
                    DateTime(current.year, current.month - 1);
              },
              onNext: () {
                final current = ref.read(focusedMonthProvider);
                ref.read(focusedMonthProvider.notifier).state =
                    DateTime(current.year, current.month + 1);
              },
              onReset: () {
                ref.read(focusedMonthProvider.notifier).state = DateTime.now();
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Insets.lg,
                Insets.sm,
                Insets.lg,
                Insets.sm,
              ),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Search transactions',
                  prefixIcon: Icon(Icons.search, size: 18),
                ),
                onChanged: (v) => setState(() => _query = v.toLowerCase()),
              ),
            ),
            _TypeFilterBar(
              selected: _typeFilter,
              onChanged: (t) => setState(() => _typeFilter = t),
            ),
            const Divider(height: 1),
            Expanded(
              child: txnsAsync.when(
                data: (all) {
                  final items = _apply(all);
                  if (items.isEmpty) {
                    return const CalmEmptyState(
                      title: 'Nothing here yet',
                      message:
                          'Add your first transaction with the + button below.',
                      icon: Icons.receipt_long_outlined,
                      illustration: CalmIllustration.wallet,
                    );
                  }
                  return _groupByDate
                      ? _buildGrouped(items, symbol, locale)
                      : _buildFlat(items, symbol, locale);
                },
                loading: () => const DashboardSkeleton(),
                error: (e, _) => CalmEmptyState(
                  title: 'Could not load',
                  message: '$e',
                  icon: Icons.error_outline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFlat(
    List<TransactionEntity> items,
    String symbol,
    String? locale,
  ) {
    return ListView.separated(
      padding: const EdgeInsets.all(Insets.lg),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: Insets.sm),
      itemBuilder: (context, i) => _row(items[i], symbol, locale),
    );
  }

  Widget _buildGrouped(
    List<TransactionEntity> items,
    String symbol,
    String? locale,
  ) {
    final groups = groupBy<TransactionEntity, String>(
      items,
      (t) => _dayKey(t.occurredAt, locale),
    );
    final keys = groups.keys.toList();

    // Flatten into a mixed list of headers and items for fully lazy building.
    final flatItems = <Object>[];
    for (final key in keys) {
      flatItems.add(key); // String header
      flatItems.addAll(groups[key]!);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(Insets.lg),
      itemCount: flatItems.length,
      itemBuilder: (context, i) {
        final item = flatItems[i];
        if (item is String) {
          return Padding(
            padding: const EdgeInsets.only(top: Insets.md, bottom: Insets.sm),
            child: Text(item, style: Theme.of(context).textTheme.labelMedium),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: Insets.sm),
          child: _row(item as TransactionEntity, symbol, locale),
        );
      },
    );
  }

  Widget _row(TransactionEntity txn, String symbol, String? locale) {
    final selected = _selected.contains(txn.id);
    return _TransactionRow(
      txn: txn,
      symbol: symbol,
      locale: locale,
      selected: selected,
      selecting: _selecting,
      onTap: () {
        if (_selecting) {
          _toggleSelect(txn.id);
        } else {
          QuickAddSheet.show(context, existing: txn);
        }
      },
      onLongPress: () => _toggleSelect(txn.id),
      onDelete: () => _deleteWithUndo(txn),
      onAction: (a) => _rowAction(txn, a),
    );
  }

  void _toggleSelect(String id) {
    setState(() {
      if (!_selected.remove(id)) _selected.add(id);
    });
  }

  Future<void> _rowAction(TransactionEntity txn, String action) async {
    final repo = ref.read(transactionRepositoryProvider);
    switch (action) {
      case 'edit':
        await QuickAddSheet.show(context, existing: txn);
      case 'duplicate':
        final cats = ref.read(categoriesStreamProvider).valueOrNull ?? const [];
        final categoryExists =
            txn.categoryId != null && cats.any((c) => c.id == txn.categoryId);
        final dupe = txn.copyDuplicate(
          DefaultDataSeeder.newId(),
          clearCategory: !categoryExists && txn.categoryId != null,
        );
        await repo.upsert(dupe);
      case 'archive':
        await repo.archive(txn.id);
        Haptics.confirm();
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text('Moved "${txn.name}" to Trash'),
              duration: const Duration(seconds: 10),
              action: SnackBarAction(
                label: 'Undo',
                onPressed: () => repo.unarchive(txn.id),
              ),
            ),
          );
    }
  }

  Future<void> _bulkDelete(List<TransactionEntity> all) async {
    final ids = _selected.toList();
    final repo = ref.read(transactionRepositoryProvider);
    final removed = all.where((t) => _selected.contains(t.id)).toList();
    // Soft-delete: everything lands in the Trash can (Settings > Trash) and can
    // be restored there even after the snackbar is gone.
    for (final id in ids) {
      await repo.archive(id);
    }
    Haptics.impact();
    setState(_selected.clear);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text('Moved ${removed.length} to Trash'),
          duration: const Duration(seconds: 10),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              for (final t in removed) {
                repo.unarchive(t.id);
              }
            },
          ),
        ),
      );
  }

  Future<void> _deleteWithUndo(TransactionEntity txn) async {
    final repo = ref.read(transactionRepositoryProvider);
    // Soft-delete to Trash (Settings > Trash). The 10-second Undo is a quick
    // shortcut; even if it's missed, the item is safe in the Trash can.
    await repo.archive(txn.id);
    Haptics.confirm();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text('Moved "${txn.name}" to Trash'),
          duration: const Duration(seconds: 10),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => repo.unarchive(txn.id),
          ),
        ),
      );
  }

  String _dayKey(DateTime d, String? locale) =>
      FriendlyDate.relative(d, locale: locale);
}

/// Small extension to make a de-identified copy for duplication.
extension _Duplicate on TransactionEntity {
  TransactionEntity copyDuplicate(
    String newId, {
    String? validatedCategoryId,
    bool clearCategory = false,
  }) =>
      TransactionEntity(
        id: newId,
        type: type,
        name: name,
        amount: amount,
        occurredAt: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        categoryId: clearCategory ? null : (validatedCategoryId ?? categoryId),
        incomeType: incomeType,
        accountId: accountId,
        paymentMethodId: paymentMethodId,
        merchant: merchant,
        notes: notes,
        tags: tags,
      );
}

class _TypeFilterBar extends StatelessWidget {
  const _TypeFilterBar({required this.selected, required this.onChanged});

  final TransactionType? selected;
  final ValueChanged<TransactionType?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: Insets.sm),
            child: ChoiceChip(
              label: const Text('All'),
              selected: selected == null,
              onSelected: (_) => onChanged(null),
            ),
          ),
          for (final t in TransactionType.values)
            Padding(
              padding: const EdgeInsets.only(right: Insets.sm),
              child: ChoiceChip(
                label: Text(t.label),
                selected: selected == t,
                onSelected: (_) => onChanged(t),
              ),
            ),
        ],
      ),
    );
  }
}

class _TransactionRow extends ConsumerWidget {
  const _TransactionRow({
    required this.txn,
    required this.symbol,
    required this.locale,
    required this.selected,
    required this.selecting,
    required this.onTap,
    required this.onLongPress,
    required this.onDelete,
    required this.onAction,
  });

  final TransactionEntity txn;
  final String symbol;
  final String? locale;
  final bool selected;
  final bool selecting;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onDelete;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context).textTheme;
    final colors = context.colors;
    final amountColor = txn.isOutflow ? colors.negative : colors.positive;
    final prefix = txn.isOutflow ? '-' : '+';
    final compact = ref
            .watch(settingsControllerProvider)
            .valueOrNull
            ?.numberFormatCompact ??
        false;

    // Resolve the row icon: the transaction's own icon wins, else its
    // category's icon, else a neutral fallback. Colour follows the category.
    final cats = ref.watch(categoriesStreamProvider).valueOrNull ?? const [];
    final cat = txn.categoryId == null
        ? null
        : cats.where((c) => c.id == txn.categoryId).firstOrNull;
    final iconCp = txn.iconCodePoint ?? cat?.iconCodePoint;
    final iconColor = cat == null ? colors.accent : Color(cat.colorValue);

    final card = GestureDetector(
      onLongPress: onLongPress,
      child: CalmCard(
        onTap: onTap,
        padding: const EdgeInsets.all(Insets.md),
        child: Row(
          children: [
            if (selecting)
              Padding(
                padding: const EdgeInsets.only(right: Insets.sm),
                child: Icon(
                  selected ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 20,
                  color: selected ? colors.accent : colors.textFaint,
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(right: Insets.md),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    categoryIcon(iconCp ?? kFallbackCategoryIcon.codePoint),
                    size: 18,
                    color: iconColor,
                  ),
                ),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(txn.name, style: theme.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    '${txn.type.label} · '
                    '${FriendlyDate.short(txn.occurredAt, locale: locale)}',
                    style: theme.bodySmall,
                  ),
                ],
              ),
            ),
            Text(
              '$prefix${txn.amount.format(currencySymbol: symbol, locale: locale, compact: compact)}',
              style: theme.titleSmall?.copyWith(color: amountColor),
            ),
            if (!selecting)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 18),
                onSelected: onAction,
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
                  PopupMenuItem(value: 'archive', child: Text('Move to Trash')),
                ],
              ),
          ],
        ),
      ),
    );

    if (selecting) return card;

    return Dismissible(
      key: ValueKey(txn.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: Insets.lg),
        decoration: BoxDecoration(
          color: colors.negative.withValues(alpha: 0.12),
          borderRadius: Corners.md,
        ),
        child: Icon(Icons.delete_outline, color: colors.negative),
      ),
      onDismissed: (_) => onDelete(),
      child: card,
    );
  }
}
