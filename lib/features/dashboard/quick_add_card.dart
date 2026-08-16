import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/constants/enums.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/category_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_resolver.dart';
import '../../core/utils/haptics.dart';
import '../../core/utils/money.dart';
import '../../core/validation/validators.dart';
import '../../data/seed/default_data.dart';
import '../../domain/entities/transaction_entity.dart';
import '../common/app_feedback.dart';
import '../settings/settings_controller.dart';

/// A soothing, accent-coloured card on the dashboard for logging an expense in
/// seconds: just a name, an amount and a category, always dated today. Collapsed
/// by default so it never crowds the home screen. Carries a faint app-mark as
/// light branding. This is the "just get it done" path; the full sheet (the +
/// FAB) is still there for everything else.
class QuickAddCard extends ConsumerStatefulWidget {
  const QuickAddCard({super.key});

  @override
  ConsumerState<QuickAddCard> createState() => _QuickAddCardState();
}

class _QuickAddCardState extends ConsumerState<QuickAddCard> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _amount = TextEditingController();
  String? _categoryId;
  bool _open = false;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final categories =
        ref.read(categoriesStreamProvider).valueOrNull ?? const [];
    final categoryId =
        _categoryId ?? (categories.isNotEmpty ? categories.first.id : null);

    setState(() => _saving = true);
    final loc = ref.read(settingsControllerProvider).valueOrNull?.localeCode;
    final now = DateTime.now();
    final amount = Money.tryParse(_amount.text, locale: loc)!;

    final txn = TransactionEntity(
      id: DefaultDataSeeder.newId(),
      type: TransactionType.expense,
      name: _name.text.trim(),
      amount: amount,
      occurredAt: now, // always today, by design
      createdAt: now,
      updatedAt: now,
      categoryId: categoryId,
    );
    await ref.read(transactionRepositoryProvider).upsert(txn);
    Haptics.confirm();
    if (!mounted) return;

    _name.clear();
    _amount.clear();
    setState(() {
      _saving = false;
      _open = false;
    });
    context.showMessage('Added. Onto the next thing.');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final categories =
        ref.watch(categoriesStreamProvider).valueOrNull ?? const [];
    final settings = ref.watch(settingsControllerProvider).valueOrNull;
    final symbol = settings?.currencySymbol ?? Money.defaultCurrencySymbol;
    final loc = settings?.localeCode;

    _categoryId ??= categories.isNotEmpty ? categories.first.id : null;

    return ClipRRect(
      borderRadius: Corners.md,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.accent,
          borderRadius: Corners.md,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Insets.lg,
            vertical: Insets.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(colors, text),
              ClipRect(
                child: AnimatedSize(
                  duration: Motion.base,
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: _open
                      ? _form(colors, text, categories, symbol, loc)
                      : const SizedBox(width: double.infinity),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(AppColors colors, TextTheme text) {
    return InkWell(
      onTap: () {
        setState(() => _open = !_open);
        Haptics.selection();
      },
      borderRadius: Corners.sm,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Insets.sm),
        child: Row(
          children: [
            Icon(Icons.bolt_outlined, size: 20, color: colors.onAccent),
            const SizedBox(width: Insets.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick add',
                    style: text.titleMedium?.copyWith(color: colors.onAccent),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    'One expense, done in seconds. Dated today.',
                    style: text.bodySmall?.copyWith(
                      color: colors.onAccent.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
            AnimatedRotation(
              turns: _open ? 0.5 : 0,
              duration: Motion.fast,
              child: Icon(
                Icons.expand_more,
                size: 20,
                color: colors.onAccent.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _form(
    AppColors colors,
    TextTheme text,
    List<CategoryEntity> categories,
    String symbol,
    String? loc,
  ) {
    // Inputs sit on a legible surface panel so text stays readable on the
    // accent wash (WCAG contrast), while the card overall reads as accent.
    return Padding(
      padding: const EdgeInsets.only(top: Insets.xs, bottom: Insets.md),
      child: Container(
        padding: const EdgeInsets.all(Insets.md),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: Corners.sm,
          border: Border.all(color: colors.border, width: Strokes.hairline),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Just the essentials: what it was, how much, and where it '
                'belongs. We stamp today automatically.',
                style: text.bodySmall?.copyWith(color: colors.textSecondary),
              ),
              const SizedBox(height: Insets.md),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Expense name'),
                validator: (v) => Validators.name(v, field: 'Expense name'),
              ),
              const SizedBox(height: Insets.md),
              TextFormField(
                controller: _amount,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Amount',
                  prefixText: '$symbol ',
                ),
                validator: (v) => Validators.amount(v, locale: loc),
              ),
              const SizedBox(height: Insets.md),
              if (categories.isEmpty)
                Text(
                  'Add a category first to use quick add.',
                  style: text.bodySmall?.copyWith(color: colors.textFaint),
                )
              else
                DropdownButtonFormField<String>(
                  initialValue: _categoryId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: [
                    for (final c in categories)
                      DropdownMenuItem<String>(
                        value: c.id,
                        child: Row(
                          children: [
                            Icon(
                              categoryIcon(c.iconCodePoint),
                              size: 16,
                              color: Color(c.colorValue),
                            ),
                            const SizedBox(width: Insets.sm),
                            Flexible(
                              child: Text(
                                c.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                  onChanged: (v) => setState(() => _categoryId = v),
                ),
              const SizedBox(height: Insets.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving || categories.isEmpty ? null : _save,
                  icon: const Icon(Icons.bolt, size: 18),
                  label: Text(_saving ? 'Adding…' : 'Quick add'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
