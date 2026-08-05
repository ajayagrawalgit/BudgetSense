import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../app/feature_providers.dart';
import '../../app/providers.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/theme_resolver.dart';
import '../../core/utils/haptics.dart';
import '../../data/cloud/cloud_constants.dart';
import '../../domain/services/snapshot_service.dart';
import '../common/calm_widgets.dart';
import 'cloud_backup_section.dart';

/// Complete backup & restore. A backup captures EVERYTHING - every table plus
/// all settings, profile, theme, accent, font and app-icon - in the format the
/// user picks (JSON, CSV or XML). Restore auto-detects the format of any
/// BudgetSense export (including older DB-only backups) and puts it all back.
class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  SnapshotFormat _format = SnapshotFormat.json;
  bool _busy = false;
  String? _status;
  bool _ok = true;
  String? _savedPath;

  /// Resolves (creating it if missing) the fixed `BudgetSense_Backup` folder at
  /// the TOP LEVEL of shared storage, next to Documents/Downloads. Local
  /// backups always go here; the user is never asked to pick a location.
  Future<Directory> _backupDirectory() async {
    Directory base;
    if (Platform.isAndroid) {
      // Derive the shared-storage root (e.g. /storage/emulated/0) from the
      // app's external dir, then place the folder at that top level.
      final ext = await getExternalStorageDirectory();
      final root = _sharedStorageRoot(ext?.path);
      base = root != null
          ? Directory(root)
          : (ext ?? await getApplicationDocumentsDirectory());
    } else {
      base = await getApplicationDocumentsDirectory();
    }
    final dir = Directory('${base.path}/${CloudBackupConstants.folderName}');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Turns an app-specific external path like
  /// `/storage/emulated/0/Android/data/<pkg>/files` into the shared-storage
  /// root `/storage/emulated/0`. Returns null if the marker is missing.
  String? _sharedStorageRoot(String? appExternalPath) {
    if (appExternalPath == null) return null;
    final idx = appExternalPath.indexOf('/Android/');
    return idx > 0 ? appExternalPath.substring(0, idx) : null;
  }

  /// Ensures we may write to top-level shared storage. On Android 11+ this is
  /// the one-time "All files access" grant; on older versions the classic
  /// write permission. Returns true once writing is allowed. When it returns
  /// false it has already routed the user to the grant screen.
  static const _storageChannel =
      MethodChannel('com.budgetsense.budgetsense/storage');

  Future<bool> _ensureStoragePermission() async {
    if (!Platform.isAndroid) return true;
    final has =
        await _storageChannel.invokeMethod<bool>('hasAllFilesAccess') ?? false;
    if (has) return true;
    await _storageChannel.invokeMethod<void>('requestAllFilesAccess');
    return false;
  }

  Future<void> _backup() async {
    setState(() => _busy = true);
    if (!await _ensureStoragePermission()) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _ok = false;
        _savedPath = null;
        _status = 'BudgetSense needs "All files access" to save into the '
            '${CloudBackupConstants.folderName} folder in shared storage. '
            'Please allow it and tap backup again.';
      });
      return;
    }
    try {
      final export = await ref.read(snapshotServiceProvider).export(_format);
      final dir = await _backupDirectory();
      final file = File('${dir.path}/${export.fileName}');
      // Write, flush and close before reporting success so an interrupted
      // write never looks like a finished backup.
      await file.writeAsBytes(export.bytes, flush: true);
      if (!mounted) return;
      Haptics.confirm();
      setState(() {
        _busy = false;
        _ok = true;
        _savedPath = file.path;
        _status = 'Saved ${export.recordCount} records and '
            '${export.settingsFields} settings as ${export.format.label} to '
            'your ${CloudBackupConstants.folderName} folder.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _ok = false;
        _savedPath = null;
        _status = 'Backup failed: $e';
      });
    }
  }

  Future<void> _restore() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Restore from a backup?'),
        content: const Text(
          'Restore is safe and additive:\n\n'
          '\u2022 Your existing records are never deleted or overwritten.\n'
          '\u2022 New records from the backup are added alongside them.\n'
          '\u2022 Records you already restored before are skipped, so restoring '
          'twice never duplicates them.\n'
          '\u2022 Your current settings are kept; a backed-up setting is only '
          'filled in where you have not set one yourself.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    // Accept any file and detect the format from its content, so the user never
    // has to worry about extensions.
    final picked = await FilePicker.platform.pickFiles(withData: true);
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.first;
    final bytes = file.bytes ??
        (file.path != null ? await File(file.path!).readAsBytes() : null);
    if (bytes == null) {
      setState(() {
        _ok = false;
        _status = 'Could not read that file.';
      });
      return;
    }

    setState(() => _busy = true);
    try {
      final result = await ref.read(snapshotServiceProvider).importBytes(bytes);
      // Critical: the dashboard/expenses only show the *focused* month, which
      // defaults to today. If the restored data's newest activity isn't in the
      // current month, the app looks empty ("my data disappeared!"). Jump the
      // focus to the latest imported transaction so everything is visible at
      // once, and the data never appears to vanish.
      final latest =
          await ref.read(transactionRepositoryProvider).latestActiveDate();
      if (latest != null) {
        ref.read(focusedMonthProvider.notifier).state = latest;
      }
      // Force every data-backed provider to re-query so the restored records
      // show up instantly, sitting right alongside anything added by hand. No
      // app restart needed.
      refreshAllDataProviders(ref);
      if (!mounted) return;
      Haptics.confirm();
      final skipped = result.totalSkipped;
      final remapped = result.totalRemapped;
      final versioned = result.totalVersioned;
      final extras = <String>[
        if (skipped > 0) '$skipped already present (skipped)',
        if (remapped > 0) '$remapped id conflicts kept as new records',
        if (versioned > 0) '$versioned newer versions appended',
      ];
      setState(() {
        _busy = false;
        _ok = true;
        _status = 'Added ${result.totalRows} new records'
            '${result.preferencesImported.isEmpty ? '' : ' and filled '
                '${result.preferencesImported.length} unset preferences'} '
            'from ${result.format.label}. Nothing existing was changed.'
            '${extras.isEmpty ? '' : ' (${extras.join('; ')}.)'}'
            '${result.warnings.isEmpty ? '' : ' ${result.warnings.join(' ')}'}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _ok = false;
        _status = e is SnapshotException ? e.message : 'Restore failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = context.colors;
    return Scaffold(
      appBar: AppBar(title: const Text('Backup & restore')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Insets.lg),
          children: [
            CalmCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('A complete backup', style: text.titleSmall),
                  const SizedBox(height: Insets.xs),
                  Text(
                    'One file with everything: transactions, categories, '
                    'payments, loans, and all your settings, profile, theme and '
                    'icon. It is saved automatically into a '
                    '"${CloudBackupConstants.folderName}" folder at the top '
                    'level of your storage (next to Documents and Downloads), '
                    'so you never have to pick a location.',
                    style: text.bodyMedium,
                  ),
                  const SizedBox(height: Insets.lg),
                  Text('Format', style: text.titleSmall),
                  const SizedBox(height: Insets.sm),
                  Wrap(
                    spacing: Insets.sm,
                    children: [
                      for (final f in SnapshotFormat.values)
                        ChoiceChip(
                          label: Text(f.label),
                          selected: _format == f,
                          onSelected: (_) => setState(() => _format = f),
                        ),
                    ],
                  ),
                  const SizedBox(height: Insets.xs),
                  Text(
                    _format == SnapshotFormat.json
                        ? 'JSON is the recommended, most compact format.'
                        : _format == SnapshotFormat.csv
                            ? 'CSV opens in a spreadsheet; sections per table.'
                            : 'XML is a structured, widely-readable format.',
                    style: text.bodySmall?.copyWith(color: colors.textFaint),
                  ),
                  const SizedBox(height: Insets.lg),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _backup,
                      icon: const Icon(Icons.backup_outlined, size: 16),
                      label: Text('Create ${_format.label} backup'),
                    ),
                  ),
                  const SizedBox(height: Insets.sm),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _restore,
                      icon: const Icon(Icons.restore_outlined, size: 16),
                      label: const Text('Restore from file'),
                    ),
                  ),
                  const SizedBox(height: Insets.xs),
                  Text(
                    'Restore auto-detects JSON, CSV or XML.',
                    style: text.bodySmall?.copyWith(color: colors.textFaint),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Insets.lg),
            if (_busy) const Center(child: CircularProgressIndicator()),
            if (_status != null && !_busy)
              CalmCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _ok
                              ? Icons.check_circle_outline
                              : Icons.error_outline,
                          size: 18,
                          color: _ok ? colors.positive : colors.critical,
                        ),
                        const SizedBox(width: Insets.sm),
                        Expanded(child: Text(_status!, style: text.bodyMedium)),
                      ],
                    ),
                    if (_ok && _savedPath != null) ...[
                      const SizedBox(height: Insets.sm),
                      SelectableText(
                        _savedPath!,
                        style:
                            text.bodySmall?.copyWith(color: colors.textFaint),
                      ),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: Insets.lg),
            const CloudBackupSection(),
          ],
        ),
      ),
    );
  }
}
