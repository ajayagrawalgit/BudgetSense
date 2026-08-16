import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/constants/enums.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/category_icons.dart';
import '../../core/theme/theme_resolver.dart';
import '../../core/utils/icon_suggester.dart';
import '../../core/utils/money.dart';
import '../../core/validation/validators.dart';
import '../../data/seed/default_data.dart';
import '../../domain/entities/transaction_entity.dart';
import '../common/icon_picker.dart';
import '../common/calm_widgets.dart';
import '../common/feedback_widgets.dart';
import '../settings/settings_controller.dart';
import '../../core/utils/friendly_date.dart';
import '../../core/utils/haptics.dart';

/// The quick-add bottom sheet (Section 4 & 23). Requires minimal interaction:
/// pick a type, type a name + amount, pick a category, save. Everything else is
/// optional. Threshold evaluation happens reactively once the transaction is
/// persisted (the dashboard recomputes from the live stream).
class QuickAddSheet extends ConsumerStatefulWidget {
  const QuickAddSheet({
    this.initialType = TransactionType.expense,
    this.existing,
    this.defaultNote,
    this.defaultName,
    this.defaultAmount,
    super.key,
  });

  final TransactionType initialType;

  /// When provided, the sheet edits this transaction instead of creating one.
  final TransactionEntity? existing;

  /// A note applied silently when the user leaves the notes field empty (used
  /// by the home-screen quick-add widget). Never shown pre-filled in the field;
  /// any note the user types takes priority.
  final String? defaultNote;

  /// Optional prefilled name (used by preset widget buttons, e.g. the chai
  /// shortcut). The user still confirms, so nothing is written silently.
  final String? defaultName;

  /// Optional prefilled amount in major units (e.g. "100").
  final String? defaultAmount;

  static Future<void> show(
    BuildContext context, {
    TransactionType initialType = TransactionType.expense,
    TransactionEntity? existing,
    String? defaultNote,
    String? defaultName,
    String? defaultAmount,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: QuickAddSheet(
          initialType: initialType,
          existing: existing,
          defaultNote: defaultNote,
          defaultName: defaultName,
          defaultAmount: defaultAmount,
        ),
      ),
    );
  }

  @override
  ConsumerState<QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends ConsumerState<QuickAddSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  late TransactionType _type;
  String? _categoryId;
  IncomeType _incomeType = IncomeType.salary;
  DateTime _occurredAt = DateTime.now();
  bool _saving = false;

  /// Once the record lands, the sheet swaps to a brief success check before it
  /// closes itself. Nicer than a gray SnackBar.
  bool _saved = false;

  /// Optional per-transaction icon. Null falls back to the category icon.
  int? _icon;

  /// Once true, we stop auto-detecting the icon from the name.
  bool _iconTouched = false;

  /// Falls back to the first available category when the user hasn't
  /// explicitly picked one from the dropdown.
  String? get _resolvedCategoryId {
    final cats = ref.read(categoriesStreamProvider).valueOrNull;
    return (cats != null && cats.isNotEmpty) ? cats.first.id : null;
  }

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _type = e?.type ?? widget.initialType;
    if (e != null) {
      _nameCtrl.text = e.name;
      _amountCtrl.text = e.amount.major.toString();
      _notesCtrl.text = e.notes ?? '';
      _categoryId = e.categoryId;
      _incomeType = e.incomeType ?? IncomeType.salary;
      _occurredAt = e.occurredAt;
      _icon = e.iconCodePoint;
      _iconTouched = e.iconCodePoint != null;
    } else {
      // Preset prefills (e.g. from a widget button). The user still confirms.
      if (widget.defaultName != null) {
        _nameCtrl.text = widget.defaultName!;
        _icon = IconSuggester.suggestCodePoint(widget.defaultName!);
      }
      if (widget.defaultAmount != null) {
        _amountCtrl.text = widget.defaultAmount!;
      }
    }
  }

  void _onNameChanged(String value) {
    if (_iconTouched) return;
    final cp = IconSuggester.suggestCodePoint(value);
    if (cp != null && cp != _icon) setState(() => _icon = cp);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _occurredAt,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    if (!mounted) return;
    final time = TimeOfDay.fromDateTime(_occurredAt);
    setState(() {
      _occurredAt = DateTime(
        picked.year,
        picked.month,
        picked.day,
        time.hour,
        time.minute,
      );
    });
  }

  bool _isFutureMonth(DateTime date) {
    final now = DateTime.now();
    return date.year > now.year ||
        (date.year == now.year && date.month > now.month);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final settings = ref.read(settingsControllerProvider).valueOrNull;
    final amount = Money.tryParse(
      _amountCtrl.text,
      locale: settings?.localeCode,
    )!;
    final now = DateTime.now();
    final e = widget.existing;

    final entity = TransactionEntity(
      id: e?.id ?? DefaultDataSeeder.newId(),
      type: _type,
      name: _nameCtrl.text.trim(),
      amount: amount,
      occurredAt: _occurredAt,
      createdAt: e?.createdAt ?? now,
      updatedAt: now,
      categoryId: _type == TransactionType.income
          ? null
          : _categoryId ?? _resolvedCategoryId,
      incomeType: _type == TransactionType.income ? _incomeType : null,
      iconCodePoint: _icon,
      accountId: e?.accountId,
      paymentMethodId: e?.paymentMethodId,
      merchant: e?.merchant,
      notes: _notesCtrl.text.trim().isEmpty
          ? widget.defaultNote
          : _notesCtrl.text.trim(),
      tags: e?.tags ?? const [],
      linkedPaymentId: e?.linkedPaymentId,
      linkedLoanId: e?.linkedLoanId,
    );

    await ref.read(transactionRepositoryProvider).upsert(entity);
    Haptics.confirm();
    if (!mounted) return;
    setState(() {
      _saving = false;
      _saved = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    if (_saved) {
      final justSaved =
          widget.existing == null ? 'Saved. Nice one.' : 'Updated.';
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Insets.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SuccessCheck(
                onCompleted: () {
                  if (mounted) Navigator.of(context).pop();
                },
              ),
              const SizedBox(height: Insets.lg),
              Text(justSaved, style: text.titleMedium),
              const SizedBox(height: Insets.md),
            ],
          ),
        ),
      );
    }

    final settings = ref.watch(settingsControllerProvider).valueOrNull;
    final categoriesAsync = ref.watch(categoriesStreamProvider);
    final symbol = settings?.currencySymbol ?? Money.defaultCurrencySymbol;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Insets.lg,
          Insets.sm,
          Insets.lg,
          Insets.lg,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.existing == null ? 'Quick add' : 'Edit transaction',
                style: text.titleLarge,
              ),
              const SizedBox(height: Insets.md),
              _TypeSelector(
                selected: _type,
                onChanged: (t) => setState(() => _type = t),
              ),
              const SizedBox(height: Insets.lg),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: IconChoiceButton(
                      codePoint: _icon ?? kFallbackCategoryIcon.codePoint,
                      color: context.colors.accent,
                      suggested: !_iconTouched,
                      onChanged: (cp) => setState(() {
                        _icon = cp;
                        _iconTouched = true;
                      }),
                    ),
                  ),
                  const SizedBox(width: Insets.md),
                  Expanded(
                    child: TextFormField(
                      controller: _nameCtrl,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(labelText: 'Name'),
                      validator: (v) => Validators.name(v),
                      autofocus: true,
                      onChanged: _onNameChanged,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Insets.md),
              TextFormField(
                controller: _amountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Amount',
                  prefixText: '$symbol ',
                ),
                validator: (v) =>
                    Validators.amount(v, locale: settings?.localeCode),
              ),
              if (_type == TransactionType.income) ...[
                const SizedBox(height: Insets.md),
                DropdownButtonFormField<IncomeType>(
                  initialValue: _incomeType,
                  decoration: const InputDecoration(labelText: 'Income type'),
                  items: [
                    for (final t in IncomeType.values)
                      DropdownMenuItem(value: t, child: Text(t.label)),
                  ],
                  onChanged: (v) =>
                      setState(() => _incomeType = v ?? _incomeType),
                ),
              ],
              if (_type != TransactionType.income) ...[
                const SizedBox(height: Insets.md),
                categoriesAsync.when(
                  data: (cats) => DropdownButtonFormField<String>(
                    initialValue:
                        _categoryId ?? (cats.isNotEmpty ? cats.first.id : null),
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: [
                      for (final c in cats)
                        DropdownMenuItem(value: c.id, child: Text(c.name)),
                    ],
                    onChanged: (v) => setState(() => _categoryId = v),
                  ),
                  loading: () =>
                      const ShimmerBlock(height: 56, borderRadius: 6),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
              const SizedBox(height: Insets.md),
              _DateRow(
                occurredAt: _occurredAt,
                onTap: _pickDate,
                locale: settings?.localeCode,
              ),
              if (_isFutureMonth(_occurredAt))
                Padding(
                  padding: const EdgeInsets.only(top: Insets.xs),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 14,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(width: Insets.xs),
                      Expanded(
                        child: Text(
                          'This date is in a future month. It will not appear in the current month view.',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: Insets.md),
              TextFormField(
                controller: _notesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                ),
                maxLines: 2,
                validator: Validators.optionalNotes,
              ),
              const SizedBox(height: Insets.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Saving…' : 'Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeSelector extends StatelessWidget {
  const _TypeSelector({required this.selected, required this.onChanged});

  final TransactionType selected;
  final ValueChanged<TransactionType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Insets.sm,
      runSpacing: Insets.sm,
      children: [
        for (final t in TransactionType.values)
          ChoiceChip(
            label: Text(t.label),
            selected: t == selected,
            onSelected: (_) => onChanged(t),
          ),
      ],
    );
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.occurredAt,
    required this.onTap,
    this.locale,
  });

  final DateTime occurredAt;
  final VoidCallback onTap;
  final String? locale;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(Icons.calendar_today_outlined, size: 16, color: colors.accent),
      label: Text('Date: ${FriendlyDate.relative(occurredAt, locale: locale)}'),
    );
  }
}
