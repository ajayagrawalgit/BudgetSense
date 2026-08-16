import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/feature_providers.dart';
import '../../app/providers.dart';
import '../../core/constants/enums.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/validation/validators.dart';
import '../../data/seed/default_data.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../domain/services/threshold_service.dart';
import '../common/calm_widgets.dart';

/// Full CRUD editor for financial thresholds (Section 11). Every value is
/// editable; nothing is hard-coded.
class ThresholdEditorScreen extends ConsumerWidget {
  const ThresholdEditorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(thresholdsStreamProvider);
    final cats = ref.watch(categoriesStreamProvider).valueOrNull ??
        const <CategoryEntity>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Thresholds')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _edit(context, ref, null, cats),
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
          data: (rules) {
            if (rules.isEmpty) {
              return const CalmEmptyState(
                title: 'No thresholds',
                message: 'Add a percentage or fixed-amount limit to get gentle '
                    'nudges when spending drifts.',
                icon: Icons.speed_outlined,
                illustration: CalmIllustration.chart,
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                  Insets.lg, Insets.lg, Insets.lg, 96),
              itemCount: rules.length,
              separatorBuilder: (_, __) => const SizedBox(height: Insets.sm),
              itemBuilder: (context, i) {
                final r = rules[i];
                return CalmCard(
                  onTap: () => _edit(context, ref, r, cats),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              r.label,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _describe(r, cats),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: r.enabled,
                        onChanged: (v) => ref
                            .read(thresholdRepositoryProvider)
                            .setEnabled(r.id, enabled: v),
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

  String _describe(ThresholdRule r, List<CategoryEntity> cats) {
    final unit = r.type.isPercentage ? '%' : '';
    final dir = r.type.isMax ? 'Max' : 'Min';
    final label = _scopeLabel(r.scopeKey, cats);
    final scope = label == null ? '' : ' · $label';
    return '$dir ${r.value.toStringAsFixed(r.type.isPercentage ? 0 : 2)}$unit$scope';
  }

  /// Human label for a scope key: app-level scopes get friendly names, and a
  /// category-id scope resolves to that category's current name (dynamic).
  static String? _scopeLabel(String? key, List<CategoryEntity> cats) {
    if (key == null || key.isEmpty) return null;
    if (key == 'investments') return 'Investments';
    if (key == 'unallocated') return 'Unallocated';
    for (final c in cats) {
      if (c.id == key) return c.name;
    }
    return key;
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    ThresholdRule? existing,
    List<CategoryEntity> categories,
  ) async {
    final result = await showModalBottomSheet<ThresholdRule>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) =>
          _ThresholdForm(existing: existing, categories: categories),
    );
    if (result != null) {
      await ref.read(thresholdRepositoryProvider).upsert(result);
    }
  }
}

class _ThresholdForm extends StatefulWidget {
  const _ThresholdForm({this.existing, this.categories = const []});
  final ThresholdRule? existing;
  final List<CategoryEntity> categories;

  @override
  State<_ThresholdForm> createState() => _ThresholdFormState();
}

class _ThresholdFormState extends State<_ThresholdForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _label;
  late final TextEditingController _value;
  late final TextEditingController _scope;
  late ThresholdType _type;
  double _warning = 0.8;
  double _critical = 0.95;

  /// Selectable scopes: app-level ones plus every user category (dynamic), so a
  /// threshold can target whatever categories the user has actually created.
  List<({String value, String label})> get _scopeItems => [
        (value: 'investments', label: 'Investments'),
        (value: 'unallocated', label: 'Unallocated'),
        for (final c in widget.categories) (value: c.id, label: c.name),
      ];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _label = TextEditingController(text: e?.label ?? '');
    _value = TextEditingController(text: e?.value.toString() ?? '');
    _scope = TextEditingController(text: e?.scopeKey ?? '');
    _type = e?.type ?? ThresholdType.maxPercentage;
    _warning = e?.warningPercent ?? 0.8;
    _critical = e?.criticalPercent ?? 0.95;
  }

  @override
  void dispose() {
    _label.dispose();
    _value.dispose();
    _scope.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
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
                  widget.existing == null ? 'New threshold' : 'Edit threshold',
                  style: text.titleLarge,
                ),
                const SizedBox(height: Insets.md),
                TextFormField(
                  controller: _label,
                  decoration: const InputDecoration(labelText: 'Label'),
                  validator: (v) => Validators.name(v, field: 'Label'),
                ),
                const SizedBox(height: Insets.md),
                DropdownButtonFormField<ThresholdType>(
                  initialValue: _type,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: const [
                    DropdownMenuItem(
                      value: ThresholdType.maxPercentage,
                      child: Text('Maximum %'),
                    ),
                    DropdownMenuItem(
                      value: ThresholdType.minPercentage,
                      child: Text('Minimum %'),
                    ),
                    DropdownMenuItem(
                      value: ThresholdType.maxAmount,
                      child: Text('Maximum amount'),
                    ),
                    DropdownMenuItem(
                      value: ThresholdType.minAmount,
                      child: Text('Minimum amount'),
                    ),
                  ],
                  onChanged: (v) => setState(() => _type = v ?? _type),
                ),
                const SizedBox(height: Insets.md),
                TextFormField(
                  controller: _value,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: _type.isPercentage
                        ? 'Percentage (0 to 100)'
                        : 'Amount (major units)',
                  ),
                  validator: (v) => double.tryParse(v ?? '') == null
                      ? 'Enter a number'
                      : null,
                ),
                const SizedBox(height: Insets.md),
                DropdownButtonFormField<String>(
                  initialValue: _scopeItems.any((s) => s.value == _scope.text)
                      ? _scope.text
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Applies to (optional)',
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('None (whole month)'),
                    ),
                    for (final s in _scopeItems)
                      DropdownMenuItem(value: s.value, child: Text(s.label)),
                  ],
                  onChanged: (v) => setState(() => _scope.text = v ?? ''),
                ),
                const SizedBox(height: Insets.md),
                Text(
                  'Warning at ${(_warning * 100).round()}%',
                  style: text.labelMedium,
                ),
                CalmSlider(
                  value: _warning,
                  min: 0.5,
                  divisions: 10,
                  onChanged: (v) => setState(() => _warning = v),
                ),
                Text(
                  'Critical at ${(_critical * 100).round()}%',
                  style: text.labelMedium,
                ),
                CalmSlider(
                  value: _critical,
                  min: 0.5,
                  divisions: 10,
                  onChanged: (v) => setState(() => _critical = v),
                ),
                const SizedBox(height: Insets.md),
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
    final raw = double.parse(_value.text.trim());
    // For amount thresholds, store minor units.
    final value = _type.isPercentage ? raw : raw * 100;
    final rule = (widget.existing ??
            ThresholdRule(
              id: DefaultDataSeeder.newId(),
              label: '',
              type: _type,
              value: 0,
              warningPercent: _warning,
              criticalPercent: _critical,
            ))
        .copyWith(
      label: _label.text.trim(),
      type: _type,
      value: value,
      warningPercent: _warning,
      criticalPercent: _critical,
      scopeKey: _scope.text.trim().isEmpty ? null : _scope.text.trim(),
    );
    Navigator.of(context).pop(rule);
  }
}
