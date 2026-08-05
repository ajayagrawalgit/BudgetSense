import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/feature_providers.dart';
import '../../core/constants/enums.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/seed/default_data.dart';
import '../../domain/entities/config_entities.dart';
import '../common/calm_widgets.dart';

/// Manager for user-defined custom fields (Section 6). Fields can target any
/// combination of transaction types and support the full set of field kinds.
class CustomFieldManagerScreen extends ConsumerWidget {
  const CustomFieldManagerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(customFieldsStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Custom fields')),
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
          data: (fields) {
            if (fields.isEmpty) {
              return const CalmEmptyState(
                title: 'No custom fields',
                message: 'Create fields like "Mood", "Trip", or "Receipt #" '
                    'and attach them to any transaction type.',
                icon: Icons.tune_outlined,
                illustration: CalmIllustration.journal,
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                  Insets.lg, Insets.lg, Insets.lg, 96),
              itemCount: fields.length,
              separatorBuilder: (_, __) => const SizedBox(height: Insets.sm),
              itemBuilder: (context, i) {
                final f = fields[i];
                return CalmCard(
                  onTap: () => _edit(context, ref, f),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              f.name,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${f.fieldType.label}'
                              '${f.required ? ' · required' : ''}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18),
                        onPressed: () => ref
                            .read(customFieldRepositoryProvider)
                            .delete(f.id),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    CustomFieldEntity? existing,
  ) async {
    final result = await showModalBottomSheet<CustomFieldEntity>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _CustomFieldForm(existing: existing),
    );
    if (result != null) {
      await ref.read(customFieldRepositoryProvider).upsert(result);
    }
  }
}

class _CustomFieldForm extends StatefulWidget {
  const _CustomFieldForm({this.existing});
  final CustomFieldEntity? existing;

  @override
  State<_CustomFieldForm> createState() => _CustomFieldFormState();
}

class _CustomFieldFormState extends State<_CustomFieldForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _allowed;
  late CustomFieldType _type;
  late bool _required;
  late Set<TransactionType> _appliesTo;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _allowed = TextEditingController(text: e?.allowedValues.join(', ') ?? '');
    _type = e?.fieldType ?? CustomFieldType.text;
    _required = e?.required ?? false;
    _appliesTo = e?.appliesTo.toSet() ?? {};
  }

  @override
  void dispose() {
    _name.dispose();
    _allowed.dispose();
    super.dispose();
  }

  bool get _needsAllowed =>
      _type == CustomFieldType.dropdown || _type == CustomFieldType.multiSelect;

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
                  widget.existing == null ? 'New field' : 'Edit field',
                  style: text.titleLarge,
                ),
                const SizedBox(height: Insets.md),
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Field name'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: Insets.md),
                DropdownButtonFormField<CustomFieldType>(
                  initialValue: _type,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: [
                    for (final t in CustomFieldType.values)
                      DropdownMenuItem(value: t, child: Text(t.label)),
                  ],
                  onChanged: (v) => setState(() => _type = v ?? _type),
                ),
                if (_needsAllowed) ...[
                  const SizedBox(height: Insets.md),
                  TextFormField(
                    controller: _allowed,
                    decoration: const InputDecoration(
                      labelText: 'Allowed values (comma separated)',
                    ),
                  ),
                ],
                const SizedBox(height: Insets.sm),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Required'),
                  value: _required,
                  onChanged: (v) => setState(() => _required = v),
                ),
                const SizedBox(height: Insets.sm),
                Text('Applies to', style: text.labelMedium),
                const SizedBox(height: Insets.sm),
                Wrap(
                  spacing: Insets.sm,
                  runSpacing: Insets.sm,
                  children: [
                    for (final t in TransactionType.values)
                      FilterChip(
                        label: Text(t.label),
                        selected: _appliesTo.contains(t),
                        onSelected: (sel) => setState(() {
                          if (sel) {
                            _appliesTo.add(t);
                          } else {
                            _appliesTo.remove(t);
                          }
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: Insets.xs),
                Text(
                  'Leave all unselected to apply everywhere.',
                  style: text.bodySmall,
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
    final allowed = _needsAllowed
        ? _allowed.text
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList()
        : <String>[];
    final result = CustomFieldEntity(
      id: e?.id ?? DefaultDataSeeder.newId(),
      name: _name.text.trim(),
      fieldType: _type,
      required: _required,
      displayOrder: e?.displayOrder ?? 9999,
      allowedValues: allowed,
      appliesTo: _appliesTo.toList(),
      createdAt: e?.createdAt ?? now,
      updatedAt: now,
    );
    Navigator.of(context).pop(result);
  }
}
