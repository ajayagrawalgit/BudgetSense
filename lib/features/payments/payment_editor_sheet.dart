import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/feature_providers.dart';
import '../../app/providers.dart';
import '../../core/constants/enums.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/friendly_date.dart';
import '../../core/utils/money.dart';
import '../../core/validation/validators.dart';
import '../../data/seed/default_data.dart';
import '../../domain/entities/commitment_entities.dart';
import '../settings/settings_controller.dart';

/// Add / edit a recurring payment or investment (Section 7). Reused for both
/// create and edit by passing an [existing] entity.
class PaymentEditorSheet extends ConsumerStatefulWidget {
  const PaymentEditorSheet({this.existing, super.key});

  final RecurringPaymentEntity? existing;

  static Future<void> show(
    BuildContext context, {
    RecurringPaymentEntity? existing,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: PaymentEditorSheet(existing: existing),
      ),
    );
  }

  @override
  ConsumerState<PaymentEditorSheet> createState() => _PaymentEditorSheetState();
}

class _PaymentEditorSheetState extends ConsumerState<PaymentEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _notesCtrl;

  late PaymentKind _kind;
  late Frequency _frequency;
  late DateTime _startDate;
  DateTime? _endDate;
  String? _categoryId;
  String? _accountId;
  late bool _autoAdd;
  late bool _reminder;
  late int _reminderDays;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _amountCtrl = TextEditingController(
      text: e == null ? '' : e.amount.major.toString(),
    );
    _notesCtrl = TextEditingController(text: e?.notes ?? '');
    _kind = e?.kind ?? PaymentKind.subscription;
    _frequency = e?.frequency ?? Frequency.monthly;
    _startDate = e?.startDate ?? DateTime.now();
    _endDate = e?.endDate;
    _categoryId = e?.categoryId;
    _accountId = e?.accountId;
    // Default ON: when the user marks this paid, record it as a real expense.
    // This only ever fires from an explicit "Mark paid" tap, never on a timer.
    _autoAdd = e?.autoAddTransaction ?? true;
    _reminder = e?.reminderEnabled ?? true;
    _reminderDays = e?.reminderDaysBefore ?? 1;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickStart() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _pickEnd() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate,
      firstDate: _startDate,
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _endDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final settings = ref.read(settingsControllerProvider).valueOrNull;
    final amount =
        Money.tryParse(_amountCtrl.text, locale: settings?.localeCode)!;
    final now = DateTime.now();
    final e = widget.existing;

    final entity = (e ??
            RecurringPaymentEntity(
              id: DefaultDataSeeder.newId(),
              name: '',
              amount: Money.zero,
              kind: _kind,
              frequency: _frequency,
              startDate: _startDate,
              nextDueDate: _startDate,
              createdAt: now,
              updatedAt: now,
            ))
        .copyWith(
      name: _nameCtrl.text.trim(),
      amount: amount,
      kind: _kind,
      frequency: _frequency,
      startDate: _startDate,
      endDate: _endDate,
      nextDueDate: e?.nextDueDate ?? _startDate,
      categoryId: _categoryId,
      accountId: _accountId,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      autoAddTransaction: _autoAdd,
      reminderEnabled: _reminder,
      reminderDaysBefore: _reminderDays,
      updatedAt: now,
    );

    await ref.read(recurringPaymentRepositoryProvider).upsert(entity);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final settings = ref.watch(settingsControllerProvider).valueOrNull;
    final symbol = settings?.currencySymbol ?? Money.defaultCurrencySymbol;
    final cats = ref.watch(categoriesStreamProvider).valueOrNull ?? const [];
    final accounts = ref.watch(accountsStreamProvider).valueOrNull ?? const [];

    return SafeArea(
      child: SingleChildScrollView(
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
                widget.existing == null ? 'New payment' : 'Edit payment',
                style: text.titleLarge,
              ),
              const SizedBox(height: Insets.md),
              TextFormField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) => Validators.name(v),
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
              const SizedBox(height: Insets.md),
              DropdownButtonFormField<PaymentKind>(
                initialValue: _kind,
                decoration: const InputDecoration(labelText: 'Type'),
                items: [
                  for (final k in PaymentKind.values)
                    DropdownMenuItem(value: k, child: Text(k.label)),
                ],
                onChanged: (v) => setState(() => _kind = v ?? _kind),
              ),
              const SizedBox(height: Insets.md),
              DropdownButtonFormField<Frequency>(
                initialValue: _frequency,
                decoration: const InputDecoration(labelText: 'Frequency'),
                items: [
                  for (final f in Frequency.values)
                    DropdownMenuItem(value: f, child: Text(f.label)),
                ],
                onChanged: (v) => setState(() => _frequency = v ?? _frequency),
              ),
              const SizedBox(height: Insets.md),
              if (cats.isNotEmpty)
                DropdownButtonFormField<String?>(
                  initialValue: _categoryId,
                  decoration: const InputDecoration(
                    labelText: 'Category (optional)',
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('None')),
                    for (final c in cats)
                      DropdownMenuItem(value: c.id, child: Text(c.name)),
                  ],
                  onChanged: (v) => setState(() => _categoryId = v),
                ),
              const SizedBox(height: Insets.md),
              if (accounts.isNotEmpty)
                DropdownButtonFormField<String?>(
                  initialValue: _accountId,
                  decoration: const InputDecoration(
                    labelText: 'Account (optional)',
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('None')),
                    for (final a in accounts)
                      DropdownMenuItem(value: a.id, child: Text(a.name)),
                  ],
                  onChanged: (v) => setState(() => _accountId = v),
                ),
              const SizedBox(height: Insets.md),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickStart,
                      icon: const Icon(Icons.calendar_today_outlined, size: 16),
                      label: Text(
                        'Start '
                        '${FriendlyDate.short(_startDate, locale: settings?.localeCode)}',
                      ),
                    ),
                  ),
                  const SizedBox(width: Insets.sm),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickEnd,
                      icon: const Icon(Icons.event_busy_outlined, size: 16),
                      label: Text(
                        _endDate == null
                            ? 'No end'
                            : FriendlyDate.short(
                                _endDate!,
                                locale: settings?.localeCode,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Insets.sm),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Record an expense when I mark it paid'),
                subtitle: const Text(
                  'Nothing is recorded until you mark this paid yourself.',
                ),
                value: _autoAdd,
                onChanged: (v) => setState(() => _autoAdd = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Remind me before it is due'),
                value: _reminder,
                onChanged: (v) => setState(() => _reminder = v),
              ),
              if (_reminder)
                Row(
                  children: [
                    const Text('Days before: '),
                    DropdownButton<int>(
                      value: _reminderDays,
                      items: [
                        for (final d in const [0, 1, 2, 3, 5, 7])
                          DropdownMenuItem(value: d, child: Text('$d')),
                      ],
                      onChanged: (v) =>
                          setState(() => _reminderDays = v ?? _reminderDays),
                    ),
                  ],
                ),
              const SizedBox(height: Insets.sm),
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
