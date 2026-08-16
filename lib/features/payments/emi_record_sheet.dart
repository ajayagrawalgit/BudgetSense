import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/feature_providers.dart';
import '../../app/providers.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/friendly_date.dart';
import '../../core/utils/haptics.dart';
import '../../core/utils/money.dart';
import '../../core/validation/validators.dart';
import '../../data/seed/default_data.dart';
import '../../domain/entities/commitment_entities.dart';
import '../common/app_feedback.dart';
import '../settings/settings_controller.dart';

/// Records an EMI against [loan]: writes the loan-payment transaction, reduces
/// the outstanding principal, bumps total paid and rolls the schedule forward.
///
/// The single place an EMI is settled, so the Loans tab and the recurring
/// due list cannot drift into two subtly different behaviours. Like every
/// other money-writing path in the app, it only ever runs from an explicit
/// user tap. See docs/DESIGN.md "Nothing posts itself".
Future<Money> recordEmi(
  WidgetRef ref,
  LoanEntity loan, {
  Money? amount,
  DateTime? paidAt,
}) async {
  final result = ref.read(recurrenceServiceProvider).payLoan(
        loan,
        newTransactionId: DefaultDataSeeder.newId(),
        amount: amount,
        paidAt: paidAt ?? DateTime.now(),
      );
  await ref.read(transactionRepositoryProvider).upsert(result.transaction);
  await ref.read(loanRepositoryProvider).upsert(result.updated);
  ref.invalidate(lastLoanPaymentProvider(loan.id));
  Haptics.confirm();
  return result.transaction.amount;
}

/// The EMI settlement form: an optional custom amount, when it was paid, and
/// the button that commits it.
///
/// Shown as a sheet from both the Loans tab and (when the loan opts into
/// [LoanEntity.showInUpcoming]) the recurring due list, so "Record EMI" means
/// exactly the same thing wherever it is tapped.
class EmiRecordSheet extends ConsumerStatefulWidget {
  const EmiRecordSheet({required this.loan, super.key});

  final LoanEntity loan;

  static Future<void> show(BuildContext context, {required LoanEntity loan}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: EmiRecordSheet(loan: loan),
      ),
    );
  }

  @override
  ConsumerState<EmiRecordSheet> createState() => _EmiRecordSheetState();
}

class _EmiRecordSheetState extends ConsumerState<EmiRecordSheet> {
  final _amount = TextEditingController();
  DateTime _paidAt = DateTime.now();
  bool _recording = false;

  LoanEntity get loan => widget.loan;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _paidAt,
      firstDate: DateTime(2000),
      // Never let an EMI be dated into the future: it would land in a month
      // the user cannot yet see and quietly skew a future balance.
      lastDate: DateTime.now(),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_paidAt),
    );
    if (!mounted) return;
    setState(() {
      _paidAt = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? _paidAt.hour,
        time?.minute ?? _paidAt.minute,
      );
    });
  }

  Future<void> _submit(String? locale) async {
    // Parse the optional custom amount; blank means "use the EMI".
    Money? custom;
    final raw = _amount.text.trim();
    if (raw.isNotEmpty) {
      final err = Validators.amount(raw, locale: locale);
      if (err != null) {
        context.showMessage(err);
        return;
      }
      custom = Money.tryParse(raw, locale: locale);
    }

    setState(() => _recording = true);
    final paid = await recordEmi(
      ref,
      loan,
      amount: custom,
      paidAt: _paidAt,
    );
    if (!mounted) return;
    Navigator.of(context).pop();
    final settings = ref.read(settingsControllerProvider).valueOrNull;
    context.showMessage(
      'EMI of '
      '${paid.format(currencySymbol: settings?.currencySymbol ?? Money.defaultCurrencySymbol, locale: locale)}'
      ' recorded for ${loan.name}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final settings = ref.watch(settingsControllerProvider).valueOrNull;
    final symbol = settings?.currencySymbol ?? Money.defaultCurrencySymbol;
    final locale = settings?.localeCode;
    final paidLabel = '${FriendlyDate.short(_paidAt, locale: locale)} at '
        '${TimeOfDay.fromDateTime(_paidAt).format(context)}';

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          Insets.lg,
          Insets.sm,
          Insets.lg,
          Insets.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Record EMI', style: text.titleLarge),
            const SizedBox(height: Insets.xs),
            Text(
              '${loan.name} · outstanding '
              '${loan.outstandingPrincipal.format(currencySymbol: symbol, locale: locale)}',
              style: text.bodySmall,
            ),
            const SizedBox(height: Insets.md),
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Custom amount (optional)',
                hintText: 'Defaults to EMI '
                    '${loan.emi.format(currencySymbol: symbol, locale: locale)}',
                prefixText: '$symbol ',
              ),
            ),
            const SizedBox(height: Insets.sm),
            OutlinedButton.icon(
              onPressed: _recording ? null : _pickDateTime,
              icon: const Icon(Icons.schedule, size: 16),
              label: Text('Paid on $paidLabel'),
            ),
            const SizedBox(height: Insets.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _recording ? null : () => _submit(locale),
                icon: const Icon(Icons.check, size: 18),
                label: Text(_recording ? 'Recording…' : 'Record EMI'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
