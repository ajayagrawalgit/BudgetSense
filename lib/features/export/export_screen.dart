import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/feature_providers.dart';
import '../../app/providers.dart';
import '../../core/constants/enums.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_log.dart';
import '../../core/utils/financial_calendar.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../domain/services/export_service.dart';
import '../common/calm_widgets.dart';
import '../settings/settings_controller.dart';

/// Export & data portability (Section 15). Pick a format and scope, preview the
/// included records, generate the file, and hand it to the native share sheet.
class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  ExportFormat _format = ExportFormat.csv;
  ExportScope _scope = ExportScope.month;
  bool _busy = false;
  List<TransactionEntity>? _preview;

  Future<List<TransactionEntity>> _gather() async {
    final repo = ref.read(transactionRepositoryProvider);
    if (_scope == ExportScope.month) {
      final cal = ref.read(financialCalendarProvider);
      final month = ref.read(focusedMonthProvider);
      final range = cal.monthRangeFor(month);
      return repo.getInRange(range);
    }
    // Everything else pulls a wide range and lets ExportSchema scope-filter.
    final wide = DateRange(DateTime(2000), DateTime(2100));
    final all = await repo.getInRange(wide);
    return ExportSchema.applyScope(all, _scope);
  }

  Future<void> _loadPreview() async {
    setState(() => _busy = true);
    try {
      final rows = await _gather();
      if (!mounted) return;
      setState(() {
        _preview = rows;
        _busy = false;
      });
    } catch (e, s) {
      AppLog.error('Export preview failed', error: e, stackTrace: s);
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Couldn't build the preview. Give it another go?"),
        ),
      );
    }
  }

  Future<void> _generateAndShare() async {
    setState(() => _busy = true);
    try {
      final rows = _preview ?? await _gather();
      final cats = ref.read(categoriesStreamProvider).valueOrNull ?? const [];
      final nameById = {for (final c in cats) c.id: c.name};
      final settings = ref.read(settingsControllerProvider).valueOrNull;
      final service = ref.read(exportServiceProvider);

      final result = await service.export(
        rows,
        format: _format,
        scope: _scope,
        categoryName: (id) => nameById[id] ?? '',
        currencySymbol: settings?.currencySymbol ?? '₹',
        locale: settings?.localeCode,
      );

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${result.fileName}');
      await file.writeAsBytes(result.bytes);

      if (!mounted) return;
      setState(() => _busy = false);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: result.mimeType)],
        subject: 'BudgetSense export',
      );
    } catch (e, s) {
      AppLog.error('Export failed', error: e, stackTrace: s);
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("That export didn't go through. Give it another go?"),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Export')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Insets.lg),
          children: [
            CalmCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Format', style: text.titleSmall),
                  const SizedBox(height: Insets.sm),
                  Wrap(
                    spacing: Insets.sm,
                    children: [
                      for (final f in ExportFormat.values)
                        ChoiceChip(
                          label: Text(f == ExportFormat.csv ? 'CSV' : 'Excel'),
                          selected: _format == f,
                          onSelected: (_) => setState(() => _format = f),
                        ),
                    ],
                  ),
                  const Divider(height: Insets.xl),
                  Text('Include', style: text.titleSmall),
                  const SizedBox(height: Insets.sm),
                  Wrap(
                    spacing: Insets.sm,
                    runSpacing: Insets.sm,
                    children: [
                      for (final s in ExportScope.values)
                        if (s != ExportScope.range)
                          ChoiceChip(
                            label: Text(_scopeLabel(s)),
                            selected: _scope == s,
                            onSelected: (_) {
                              setState(() {
                                _scope = s;
                                _preview = null;
                              });
                            },
                          ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: Insets.lg),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _loadPreview,
                    icon: const Icon(Icons.visibility_outlined, size: 16),
                    label: const Text('Preview'),
                  ),
                ),
                const SizedBox(width: Insets.sm),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _generateAndShare,
                    icon: const Icon(Icons.ios_share, size: 16),
                    label: const Text('Export'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Insets.lg),
            if (_busy) const Center(child: CircularProgressIndicator()),
            if (_preview != null && !_busy)
              CalmCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Preview: ${_preview!.length} records',
                      style: text.titleSmall,
                    ),
                    const Divider(height: Insets.lg),
                    if (_preview!.isEmpty)
                      Text(
                        'Nothing to export for this scope.',
                        style: text.bodyMedium,
                      )
                    else
                      for (final t in _preview!.take(20))
                        Padding(
                          padding: const EdgeInsets.only(bottom: Insets.xs),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(t.name, style: text.bodyMedium),
                              ),
                              Text(t.type.label, style: text.labelSmall),
                            ],
                          ),
                        ),
                    if ((_preview?.length ?? 0) > 20)
                      Padding(
                        padding: const EdgeInsets.only(top: Insets.xs),
                        child: Text(
                          '…and ${_preview!.length - 20} more',
                          style: text.bodySmall,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _scopeLabel(ExportScope s) => switch (s) {
        ExportScope.all => 'All data',
        ExportScope.month => 'This month',
        ExportScope.range => 'Date range',
        ExportScope.expensesOnly => 'Expenses',
        ExportScope.incomeOnly => 'Income',
        ExportScope.investmentsOnly => 'Investments',
      };
}
