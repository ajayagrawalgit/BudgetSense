import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/constants/enums.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/category_icons.dart';
import '../../core/theme/theme_resolver.dart';
import '../../core/utils/icon_suggester.dart';
import '../../data/seed/default_data.dart';
import '../../domain/entities/transaction_entity.dart';
import '../common/calm_widgets.dart';
import '../common/icon_picker.dart';

/// Full category management (Section 5): add, rename, reorder, recolor,
/// change icon, set default, archive, and delete-with-replacement.
class CategoryManagerScreen extends ConsumerWidget {
  const CategoryManagerScreen({super.key});

  static const palette = <int>[
    0xFFB07C5E,
    0xFF7B7F52,
    0xFFC4A374,
    0xFF7E97A6,
    0xFF8E6E7E,
    0xFF6E8B6A,
    0xFFB4675E,
    0xFF4A4A48,
  ];

  static List<int> get icons => kCategoryIcons.map((i) => i.codePoint).toList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(categoriesStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _edit(context, ref, null),
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => CalmEmptyState(
            title: 'Could not load',
            message: '$e',
            icon: Icons.error_outline,
          ),
          data: (cats) {
            if (cats.isEmpty) {
              return const CalmEmptyState(
                title: 'No categories',
                message: 'Add your first category to organize spending.',
                icon: Icons.category_outlined,
                illustration: CalmIllustration.sprig,
              );
            }
            return ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(
                Insets.lg,
                Insets.lg,
                Insets.lg,
                96,
              ),
              itemCount: cats.length,
              onReorderItem: (oldI, newI) {
                final ids = cats.map((c) => c.id).toList();
                final moved = ids.removeAt(oldI);
                ids.insert(newI, moved);
                ref.read(categoryRepositoryProvider).reorder(ids);
              },
              itemBuilder: (context, i) {
                final c = cats[i];
                return Padding(
                  key: ValueKey(c.id),
                  padding: const EdgeInsets.only(bottom: Insets.sm),
                  child: CalmCard(
                    onTap: () => _edit(context, ref, c),
                    padding: const EdgeInsets.all(Insets.md),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: Color(c.colorValue).withValues(alpha: 0.18),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            categoryIcon(c.iconCodePoint),
                            size: 18,
                            color: Color(c.colorValue),
                          ),
                        ),
                        const SizedBox(width: Insets.md),
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  c.name,
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                              ),
                              if (c.isDefault) ...[
                                const SizedBox(width: Insets.sm),
                                _DefaultBadge(),
                              ],
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, size: 18),
                          onSelected: (v) => _action(context, ref, c, v, cats),
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'default',
                              child: Text('Set default'),
                            ),
                            PopupMenuItem(
                              value: 'archive',
                              child: Text('Archive'),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete'),
                            ),
                          ],
                        ),
                        const Icon(Icons.drag_handle, size: 18),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _action(
    BuildContext context,
    WidgetRef ref,
    CategoryEntity c,
    String action,
    List<CategoryEntity> all,
  ) async {
    final repo = ref.read(categoryRepositoryProvider);
    switch (action) {
      case 'default':
        await repo.setDefault(c.id);
      case 'archive':
        await repo.upsert(_archived(c));
      case 'delete':
        await _deleteFlow(context, ref, c, all);
    }
  }

  CategoryEntity _archived(CategoryEntity c) => CategoryEntity(
        id: c.id,
        name: c.name,
        colorValue: c.colorValue,
        iconCodePoint: c.iconCodePoint,
        sortOrder: c.sortOrder,
        isDefault: c.isDefault,
        createdAt: c.createdAt,
        updatedAt: DateTime.now(),
        archivedAt: DateTime.now(),
        syncStatus: c.syncStatus,
      );

  Future<void> _deleteFlow(
    BuildContext context,
    WidgetRef ref,
    CategoryEntity c,
    List<CategoryEntity> all,
  ) async {
    final repo = ref.read(categoryRepositoryProvider);
    try {
      await repo.deleteOrReassign(c.id);
      return;
    } on StateError {
      // In use - ask for a replacement (spec rule, Section 5).
    }
    if (!context.mounted) return;
    final others = all.where((x) => x.id != c.id).toList();
    final replacement = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Reassign transactions to'),
        children: [
          for (final o in others)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, o.id),
              child: Text(o.name),
            ),
        ],
      ),
    );
    if (replacement != null) {
      await repo.deleteOrReassign(c.id, replacementId: replacement);
    }
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    CategoryEntity? existing,
  ) async {
    final result = await showModalBottomSheet<CategoryEntity>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _CategoryForm(existing: existing),
    );
    if (result != null) {
      await ref.read(categoryRepositoryProvider).upsert(result);
    }
  }
}

class _DefaultBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: context.colors.accent.withValues(alpha: 0.15),
        borderRadius: Corners.sm,
      ),
      child: Text('Default', style: Theme.of(context).textTheme.labelSmall),
    );
  }
}

class _CategoryForm extends StatefulWidget {
  const _CategoryForm({this.existing});
  final CategoryEntity? existing;

  @override
  State<_CategoryForm> createState() => _CategoryFormState();
}

class _CategoryFormState extends State<_CategoryForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late int _color;
  late int _icon;

  /// True once the user manually picks an icon, so we stop auto-detecting from
  /// the name and never overwrite their explicit choice.
  bool _iconTouched = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _color = e?.colorValue ?? CategoryManagerScreen.palette.first;
    _icon = e?.iconCodePoint ?? CategoryManagerScreen.icons.first;
    // Editing an existing category counts as an explicit icon already.
    _iconTouched = e != null;
  }

  void _onNameChanged(String value) {
    if (_iconTouched) return;
    final cp = IconSuggester.suggestCodePoint(value);
    if (cp != null && cp != _icon) setState(() => _icon = cp);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Insets.lg),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.existing == null ? 'New category' : 'Edit category',
                  style: text.titleLarge,
                ),
                const SizedBox(height: Insets.md),
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                  onChanged: _onNameChanged,
                ),
                const SizedBox(height: Insets.lg),
                Text('Color', style: text.labelMedium),
                const SizedBox(height: Insets.sm),
                Wrap(
                  spacing: Insets.sm,
                  runSpacing: Insets.sm,
                  children: [
                    for (final c in CategoryManagerScreen.palette)
                      GestureDetector(
                        onTap: () => setState(() => _color = c),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: Color(c),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _color == c
                                  ? context.colors.textPrimary
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: Insets.lg),
                Text('Icon', style: text.labelMedium),
                const SizedBox(height: Insets.sm),
                Row(
                  children: [
                    IconChoiceButton(
                      codePoint: _icon,
                      color: Color(_color),
                      suggested: !_iconTouched,
                      onChanged: (cp) => setState(() {
                        _icon = cp;
                        _iconTouched = true;
                      }),
                    ),
                    const SizedBox(width: Insets.md),
                    Expanded(
                      child: Text(
                        _iconTouched
                            ? 'Tap to change the icon.'
                            : 'Auto-picked from the name. Tap to change.',
                        style: text.bodySmall
                            ?.copyWith(color: context.colors.textFaint),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Insets.lg),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _submit,
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final now = DateTime.now();
    final e = widget.existing;
    final result = CategoryEntity(
      id: e?.id ?? DefaultDataSeeder.newId(),
      name: _name.text.trim(),
      colorValue: _color,
      iconCodePoint: _icon,
      sortOrder: e?.sortOrder ?? 9999,
      isDefault: e?.isDefault ?? false,
      createdAt: e?.createdAt ?? now,
      updatedAt: now,
      syncStatus: e?.syncStatus ?? SyncStatus.localOnly,
    );
    Navigator.of(context).pop(result);
  }
}
