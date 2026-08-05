import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/feature_providers.dart';
import '../../core/constants/enums.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/friendly_date.dart';
import '../../core/utils/money.dart';
import '../../core/validation/validators.dart';
import '../../data/seed/default_data.dart';
import '../../domain/entities/commitment_entities.dart';
import '../settings/settings_controller.dart';

/// Add / edit a loan (Section 9).
class LoanEditorSheet extends ConsumerStatefulWidget {
  const LoanEditorSheet({this.existing, super.key});

  final LoanEntity? existing;

  static Future<void> show(BuildContext context, {LoanEntity? existing}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: LoanEditorSheet(existing: existing),
      ),
    );
  }

  @override
  ConsumerState<LoanEditorSheet> createState() => _LoanEditorSheetState();
}

class _LoanEditorSheetState extends ConsumerState<LoanEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _lender;
  late final TextEditingController _principal;
  late final TextEditingController _outstanding;
  late final TextEditingController _emi;
  late final TextEditingController _rate;
  late final TextEditingController _notes;

  late Frequency _frequency;
  late DateTime _startDate;
  DateTime? _nextPaymentDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _lender = TextEditingController(text: e?.lender ?? '');
    _principal = TextEditingController(
      text: e == null ? '' : e.originalPrincipal.major.toString(),
    );
    _outstanding = TextEditingController(
      text: e == null ? '' : e.outstandingPrincipal.major.toString(),
    );
    _emi = TextEditingController(text: e == null ? '' : e.emi.major.toString());
    _rate = TextEditingController(
      text: e == null ? '' : e.interestRatePercent.toString(),
    );
    _notes = TextEditingController(text: e?.notes ?? '');
    _frequency = e?.frequency ?? Frequency.monthly;
    _startDate = e?.startDate ?? DateTime.now();
    _nextPaymentDate = e?.nextPaymentDate ?? _safeNextMonth(DateTime.now());
  }

  static DateTime _safeNextMonth(DateTime from) {
    final year = from.month == 12 ? from.year + 1 : from.year;
    final month = from.month == 12 ? 1 : from.month + 1;
    final maxDay = DateTime(year, month + 1, 0).day;
    final day = from.day > maxDay ? maxDay : from.day;
    return DateTime(year, month, day);
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _lender,
      _principal,
      _outstanding,
      _emi,
      _rate,
      _notes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final loc = ref.read(settingsControllerProvider).valueOrNull?.localeCode;
    final now = DateTime.now();
    final e = widget.existing;

    Money m(TextEditingController c) => Money.tryParse(c.text, locale: loc)!;
    final ratePercent = double.tryParse(_rate.text.trim()) ?? 0;

    final entity = (e ??
            LoanEntity(
              id: DefaultDataSeeder.newId(),
              name: '',
              originalPrincipal: Money.zero,
              outstandingPrincipal: Money.zero,
              emi: Money.zero,
              frequency: _frequency,
              startDate: _startDate,
              createdAt: now,
              updatedAt: now,
            ))
        .copyWith(
      name: _name.text.trim(),
      lender: _lender.text.trim().isEmpty ? null : _lender.text.trim(),
      originalPrincipal: m(_principal),
      outstandingPrincipal: m(_outstanding),
      emi: m(_emi),
      interestRateBps: (ratePercent * 100).round(),
      frequency: _frequency,
      startDate: _startDate,
      nextPaymentDate: _nextPaymentDate,
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      updatedAt: now,
    );

    await ref.read(loanRepositoryProvider).upsert(entity);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final settings = ref.watch(settingsControllerProvider).valueOrNull;
    final symbol = settings?.currencySymbol ?? '₹';
    final loc = settings?.localeCode;

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
                widget.existing == null ? 'New loan' : 'Edit loan',
                style: text.titleLarge,
              ),
              const SizedBox(height: Insets.md),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Loan name'),
                validator: (v) => Validators.name(v),
              ),
              const SizedBox(height: Insets.md),
              TextFormField(
                controller: _lender,
                decoration:
                    const InputDecoration(labelText: 'Lender (optional)'),
              ),
              const SizedBox(height: Insets.md),
              _moneyField(_principal, 'Original principal', symbol, loc),
              const SizedBox(height: Insets.md),
              _moneyField(_outstanding, 'Outstanding principal', symbol, loc),
              const SizedBox(height: Insets.md),
              _moneyField(_emi, 'EMI amount', symbol, loc),
              const SizedBox(height: Insets.md),
              TextFormField(
                controller: _rate,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Interest rate %',
                  suffixText: '%',
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? null : Validators.rate(v),
              ),
              const SizedBox(height: Insets.md),
              DropdownButtonFormField<Frequency>(
                initialValue: _frequency,
                decoration:
                    const InputDecoration(labelText: 'Payment frequency'),
                items: [
                  for (final f in Frequency.values)
                    DropdownMenuItem(value: f, child: Text(f.label)),
                ],
                onChanged: (v) => setState(() => _frequency = v ?? _frequency),
              ),
              const SizedBox(height: Insets.md),
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _nextPaymentDate ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    setState(() => _nextPaymentDate = picked);
                  }
                },
                icon: const Icon(Icons.event_outlined, size: 16),
                label: Text(
                  _nextPaymentDate == null
                      ? 'Next payment date'
                      : 'Next payment '
                          '${FriendlyDate.short(_nextPaymentDate!, locale: loc)}',
                ),
              ),
              const SizedBox(height: Insets.md),
              TextFormField(
                controller: _notes,
                decoration:
                    const InputDecoration(labelText: 'Notes (optional)'),
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

  Widget _moneyField(
    TextEditingController c,
    String label,
    String symbol,
    String? loc,
  ) {
    return TextFormField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label, prefixText: '$symbol '),
      validator: (v) => Validators.amount(v, locale: loc, allowZero: true),
    );
  }
}
