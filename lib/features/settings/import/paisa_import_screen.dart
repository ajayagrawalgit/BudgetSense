import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/feature_providers.dart';
import '../../../app/providers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/theme_resolver.dart';
import '../../../domain/services/import_service.dart';
import '../../common/app_feedback.dart';
import '../../common/calm_widgets.dart';
import '../settings_controller.dart';
import '../settings_state.dart';

/// The end-to-end import flow for a single [ImportSource]: pick the export file,
/// preview exactly what will come in, confirm, then see a clear result. Built to
/// be forgiving. Nothing is written until the user confirms, and a bad file
/// produces a friendly message rather than a crash.
class PaisaImportScreen extends ConsumerStatefulWidget {
  const PaisaImportScreen({required this.source, super.key});

  final ImportSource source;

  @override
  ConsumerState<PaisaImportScreen> createState() => _PaisaImportScreenState();
}

enum _Stage { idle, inspecting, preview, importing, done }

class _PaisaImportScreenState extends ConsumerState<PaisaImportScreen> {
  _Stage _stage = _Stage.idle;
  List<int>? _bytes;
  String? _fileName;
  ImportPreview? _preview;
  ImportOutcome? _outcome;
  String? _error;
  bool _importProfile = true;

  ImportSource get _source => widget.source;

  Future<void> _pickFile() async {
    setState(() => _error = null);
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.first;
    final bytes = file.bytes ??
        (file.path != null ? await File(file.path!).readAsBytes() : null);
    if (bytes == null) {
      setState(() => _error = "Couldn't read that file. Please try again.");
      return;
    }

    setState(() {
      _stage = _Stage.inspecting;
      _bytes = bytes;
      _fileName = file.name;
      _preview = null;
      _outcome = null;
    });

    try {
      final preview =
          await ref.read(dataImportServiceProvider).inspect(_source, bytes);
      if (!mounted) return;
      setState(() {
        _preview = preview;
        _importProfile = preview.profile?.hasAnything ?? false;
        _stage = _Stage.preview;
      });
    } on ImportException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _stage = _Stage.idle;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Something went wrong reading the file: $e';
        _stage = _Stage.idle;
      });
    }
  }

  Future<void> _runImport() async {
    final bytes = _bytes;
    final preview = _preview;
    if (bytes == null || preview == null) return;

    // Decide whether to bring in profile / personal information. The financial
    // data (transactions, categories, accounts) is always imported; profile is
    // separate and never touched without explicit consent.
    var importProfile =
        _importProfile && (preview.profile?.hasAnything ?? false);
    if (importProfile) {
      final current = ref.read(settingsControllerProvider).valueOrNull ??
          const SettingsState();
      final changes = _profileChanges(preview.profile!, current);
      // Only ask (and only ever overwrite) when the user already has a profile
      // set up and importing would actually change something. On a brand-new,
      // empty profile there is nothing to overwrite, so we just fill it in.
      if (current.onboardingComplete && changes.isNotEmpty) {
        final consent = await _confirmProfileImport(changes);
        if (!mounted) return;
        // Anything other than an explicit "yes" means: import the data only,
        // and leave the existing profile completely untouched.
        importProfile = consent;
      }
    }

    setState(() {
      _stage = _Stage.importing;
      _error = null;
    });

    try {
      final outcome = await ref.read(dataImportServiceProvider).import(
            _source,
            bytes,
            importProfile: importProfile,
          );

      // Apply detected profile to settings (never clobber a name the user
      // already set; currency follows the import when present).
      final profile = outcome.profile;
      if (profile != null) {
        await ref.read(settingsControllerProvider.notifier).save((c) {
          final name = (c.userName.trim().isEmpty &&
                  (profile.name?.trim().isNotEmpty ?? false))
              ? profile.name!.trim()
              : c.userName;
          return c.copyWith(
            userName: name,
            currencyCode: profile.currencyCode ?? c.currencyCode,
            currencySymbol: profile.currencySymbol ?? c.currencySymbol,
          );
        });
      }

      // Jump the dashboard to the most recent imported month so the freshly
      // imported history is visible immediately.
      if (preview.latest != null) {
        ref.read(focusedMonthProvider.notifier).state = preview.latest!;
      }
      // Re-query all data-backed providers so the imported records appear at
      // once, without an app restart.
      refreshAllDataProviders(ref);

      if (!mounted) return;
      setState(() {
        _outcome = outcome;
        _stage = _Stage.done;
      });
    } on ImportException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _stage = _Stage.preview;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Import failed: $e';
        _stage = _Stage.preview;
      });
    }
  }

  /// Human-readable list of what importing the profile would change relative to
  /// the user's current settings. Empty means importing profile is a no-op.
  List<String> _profileChanges(ImportedProfile profile, SettingsState current) {
    final changes = <String>[];
    final name = profile.name?.trim() ?? '';
    if (name.isNotEmpty && current.userName.trim().isEmpty) {
      changes.add('Set your name to “$name”');
    }
    final code = profile.currencyCode?.trim() ?? '';
    if (code.isNotEmpty && code != current.currencyCode) {
      changes.add('Change currency from ${current.currencyCode} to $code');
    }
    return changes;
  }

  /// Explicit, one-time confirmation before any personal/profile information is
  /// written. Returns true only if the user actively agrees.
  Future<bool> _confirmProfileImport(List<String> changes) {
    return context.confirm(
      barrierDismissible: false,
      title: 'Import profile details too?',
      cancelLabel: 'No, keep mine',
      confirmLabel: 'Yes, import profile',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'You already have a profile set up. Do you also want to bring '
            'over the personal details from this backup?',
          ),
          const SizedBox(height: Insets.md),
          for (final c in changes)
            Padding(
              padding: const EdgeInsets.only(bottom: Insets.xs),
              child: Text('• $c'),
            ),
          const SizedBox(height: Insets.md),
          Text(
            'Your transactions, categories and accounts will be imported '
            'either way, nothing is ever deleted or overwritten.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Import from ${_source.label}')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Insets.lg),
          children: [
            if (_stage != _Stage.done) _howToCard(),
            if (_error != null) ...[
              const SizedBox(height: Insets.lg),
              _errorCard(_error!),
            ],
            if (_stage == _Stage.idle || _stage == _Stage.inspecting) ...[
              const SizedBox(height: Insets.lg),
              _pickCard(),
            ],
            if (_stage == _Stage.preview && _preview != null) ...[
              const SizedBox(height: Insets.lg),
              _previewCard(_preview!),
            ],
            if (_stage == _Stage.importing) ...[
              const SizedBox(height: Insets.xl),
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: Insets.md),
              Center(
                child: Text(
                  'Importing your data…',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
            if (_stage == _Stage.done && _outcome != null)
              _resultCard(_outcome!),
          ],
        ),
      ),
    );
  }

  Widget _howToCard() {
    final text = Theme.of(context).textTheme;
    return CalmCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: context.colors.accent),
          const SizedBox(width: Insets.md),
          Expanded(child: Text(_source.howTo, style: text.bodyMedium)),
        ],
      ),
    );
  }

  Widget _pickCard() {
    final busy = _stage == _Stage.inspecting;
    return CalmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (busy) ...[
            const Center(child: CircularProgressIndicator()),
            const SizedBox(height: Insets.md),
            Center(
              child: Text(
                'Reading ${_fileName ?? 'file'}…',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ] else
            FilledButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.upload_file_outlined, size: 18),
              label: Text('Choose ${_source.label} backup file'),
            ),
        ],
      ),
    );
  }

  Widget _previewCard(ImportPreview p) {
    final text = Theme.of(context).textTheme;
    final df = DateFormat('MMM d, y');
    final range = (p.earliest != null && p.latest != null)
        ? '${df.format(p.earliest!)} to ${df.format(p.latest!)}'
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CalmCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ready to import', style: text.titleMedium),
              if (_fileName != null) ...[
                const SizedBox(height: Insets.xxs),
                Text(
                  _fileName!,
                  style:
                      text.bodySmall?.copyWith(color: context.colors.textFaint),
                ),
              ],
              const SizedBox(height: Insets.md),
              _statRow(
                Icons.receipt_long_outlined,
                'Transactions',
                '${p.transactions}',
              ),
              _statRow(Icons.trending_up, 'Income entries', '${p.incomeCount}'),
              _statRow(
                Icons.trending_down,
                'Expense entries',
                '${p.expenseCount}',
              ),
              _statRow(
                  Icons.category_outlined, 'Categories', '${p.categories}'),
              _statRow(
                Icons.account_balance_wallet_outlined,
                'Accounts',
                '${p.accounts}',
              ),
              if (range != null)
                _statRow(Icons.date_range_outlined, 'Date range', range),
            ],
          ),
        ),
        if (p.profile?.hasAnything ?? false) ...[
          const SizedBox(height: Insets.md),
          CalmCard(
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Also import your profile'),
              subtitle: Text(
                [
                  if (p.profile?.name?.trim().isNotEmpty ?? false)
                    'Name: ${p.profile!.name}',
                  if (p.profile?.currencyCode?.trim().isNotEmpty ?? false)
                    'Currency: ${p.profile!.currencyCode}',
                ].join('  ·  '),
              ),
              value: _importProfile,
              onChanged: (v) => setState(() => _importProfile = v),
            ),
          ),
        ],
        if (p.warnings.isNotEmpty) ...[
          const SizedBox(height: Insets.md),
          _warningsCard(p.warnings),
        ],
        const SizedBox(height: Insets.lg),
        FilledButton.icon(
          onPressed: p.isEmpty ? null : _runImport,
          icon: const Icon(Icons.download_done_outlined, size: 18),
          label: Text(
            p.isEmpty
                ? 'Nothing to import'
                : 'Import ${p.transactions} transactions',
          ),
        ),
        const SizedBox(height: Insets.sm),
        OutlinedButton(
          onPressed: _pickFile,
          child: const Text('Choose a different file'),
        ),
      ],
    );
  }

  Widget _resultCard(ImportOutcome o) {
    final text = Theme.of(context).textTheme;
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CalmCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    color: colors.positive,
                    size: 24,
                  ),
                  const SizedBox(width: Insets.sm),
                  Text('Import complete', style: text.titleMedium),
                ],
              ),
              const SizedBox(height: Insets.md),
              _statRow(
                Icons.receipt_long_outlined,
                'Transactions imported',
                '${o.transactions}',
              ),
              _statRow(
                Icons.category_outlined,
                'Categories imported',
                '${o.categories}',
              ),
              _statRow(
                Icons.account_balance_wallet_outlined,
                'Accounts imported',
                '${o.accounts}',
              ),
              if (o.skippedTransfers > 0)
                _statRow(
                  Icons.swap_horiz,
                  'Transfers skipped',
                  '${o.skippedTransfers}',
                ),
              if (o.profile != null)
                _statRow(Icons.person_outline, 'Profile', 'Imported'),
            ],
          ),
        ),
        if (o.warnings.isNotEmpty) ...[
          const SizedBox(height: Insets.md),
          _warningsCard(o.warnings),
        ],
        const SizedBox(height: Insets.lg),
        FilledButton(
          onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
          child: const Text('Done'),
        ),
      ],
    );
  }

  Widget _statRow(IconData icon, String label, String value) {
    final text = Theme.of(context).textTheme;
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Insets.xs),
      child: Row(
        children: [
          Icon(icon, size: 18, color: colors.accent),
          const SizedBox(width: Insets.md),
          Expanded(child: Text(label, style: text.bodyMedium)),
          Text(value, style: text.titleSmall),
        ],
      ),
    );
  }

  Widget _warningsCard(List<String> warnings) {
    final text = Theme.of(context).textTheme;
    final colors = context.colors;
    return CalmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: colors.warning),
              const SizedBox(width: Insets.sm),
              Text('Heads up', style: text.titleSmall),
            ],
          ),
          const SizedBox(height: Insets.sm),
          for (final w in warnings)
            Padding(
              padding: const EdgeInsets.only(bottom: Insets.xs),
              child: Text('• $w', style: text.bodySmall),
            ),
        ],
      ),
    );
  }

  Widget _errorCard(String message) {
    final text = Theme.of(context).textTheme;
    final colors = context.colors;
    return CalmCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 18, color: colors.critical),
          const SizedBox(width: Insets.md),
          Expanded(child: Text(message, style: text.bodyMedium)),
        ],
      ),
    );
  }
}
