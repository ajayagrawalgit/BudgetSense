import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/cloud_providers.dart';
import '../../app/feature_providers.dart';
import '../../app/providers.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/theme_resolver.dart';
import '../../core/utils/friendly_date.dart';
import '../../data/cloud/cloud_failure.dart';
import '../../data/cloud/cloud_sync_controller.dart';
import '../../data/cloud/cloud_sync_state.dart';
import '../../domain/services/snapshot_service.dart';
import '../common/app_feedback.dart';
import '../common/calm_widgets.dart';

/// Backup and Sync to Cloud settings (Phase 10). Strictly opt-in; the toggle
/// defaults to OFF and nothing authenticates or touches the network until the
/// user turns it on and completes setup.
class CloudBackupSection extends ConsumerStatefulWidget {
  const CloudBackupSection({super.key});

  @override
  ConsumerState<CloudBackupSection> createState() => _CloudBackupSectionState();
}

class _CloudBackupSectionState extends ConsumerState<CloudBackupSection> {
  bool _busy = false;

  CloudSyncController get _c => ref.read(cloudSyncControllerProvider);

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } on CloudFailure catch (f) {
      _snack(f.userMessage);
    } catch (_) {
      _snack('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    context.showMessage(msg);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) {
        final state = _c.state;
        return CalmCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Backup and Sync to Cloud',
                        style: text.titleSmall),
                  ),
                  Semantics(
                    label: 'Backup and Sync to Cloud',
                    toggled: state.enabled,
                    child: Switch(
                      value: state.enabled,
                      onChanged: _busy ? null : (v) => _onToggle(v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Insets.xs),
              Text(
                'Off by default. BudgetSense stays fully offline until you turn '
                'this on. When enabled, an encrypted backup is kept in your own '
                'Google Drive so you can restore after reinstalling or on a new '
                'device.',
                style: text.bodyMedium,
              ),
              if (state.enabled) ...[
                const SizedBox(height: Insets.md),
                _statusRow(context, state),
                const SizedBox(height: Insets.md),
                _actions(context, state),
              ],
              if (_busy) ...[
                const SizedBox(height: Insets.md),
                const Center(child: CircularProgressIndicator()),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _statusRow(BuildContext context, CloudSyncState state) {
    final text = Theme.of(context).textTheme;
    final colors = context.colors;
    final (icon, label, color) = switch (state.status) {
      CloudSyncStatus.syncing => (
          Icons.sync,
          'Backing up...',
          colors.textFaint
        ),
      CloudSyncStatus.pending => (
          Icons.cloud_upload_outlined,
          'Waiting to back up',
          colors.textFaint
        ),
      CloudSyncStatus.remoteConflict => (
          Icons.warning_amber_outlined,
          'Needs attention: backup changed on another device',
          colors.critical
        ),
      CloudSyncStatus.requiresSignIn => (
          Icons.login,
          'Requires sign-in',
          colors.critical
        ),
      CloudSyncStatus.error => (
          Icons.error_outline,
          state.lastError?.userMessage ?? 'Something needs attention',
          colors.critical
        ),
      _ => (Icons.check_circle_outline, 'Backed up', colors.positive),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (state.email != null)
          Semantics(
            label: 'Linked Google account ${state.email}',
            child: Row(
              children: [
                Icon(Icons.account_circle_outlined,
                    size: 16, color: colors.textFaint),
                const SizedBox(width: Insets.xs),
                Expanded(
                  child: Text(state.email!,
                      style: text.bodySmall?.copyWith(color: colors.textFaint)),
                ),
              ],
            ),
          ),
        const SizedBox(height: Insets.xs),
        Semantics(
          label: label,
          child: Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: Insets.xs),
              Expanded(child: Text(label, style: text.bodyMedium)),
            ],
          ),
        ),
        if (state.lastSyncAt != null) ...[
          const SizedBox(height: Insets.xs),
          Text(
            'Last backup: ${FriendlyDate.relative(state.lastSyncAt!)}',
            style: text.bodySmall?.copyWith(color: colors.textFaint),
          ),
        ],
      ],
    );
  }

  Widget _actions(BuildContext context, CloudSyncState state) {
    return Wrap(
      spacing: Insets.sm,
      runSpacing: Insets.xs,
      children: [
        OutlinedButton.icon(
          onPressed: _busy ? null : () => _run(() => _c.syncNow()),
          icon: const Icon(Icons.backup_outlined, size: 16),
          label: const Text('Back up now'),
        ),
        OutlinedButton.icon(
          onPressed: _busy ? null : _restoreFromCloud,
          icon: const Icon(Icons.cloud_download_outlined, size: 16),
          label: const Text('Restore from Google Drive'),
        ),
        OutlinedButton.icon(
          onPressed: _busy ? null : _changePassphrase,
          icon: const Icon(Icons.password_outlined, size: 16),
          label: const Text('Change recovery passphrase'),
        ),
        OutlinedButton.icon(
          onPressed: _busy ? null : () => _run(() => _c.disconnect()),
          icon: const Icon(Icons.link_off_outlined, size: 16),
          label: const Text('Disconnect Google Drive'),
        ),
        OutlinedButton.icon(
          onPressed: _busy ? null : _deleteCloudBackup,
          style: OutlinedButton.styleFrom(
              foregroundColor: context.colors.critical),
          icon: const Icon(Icons.delete_outline, size: 16),
          label: const Text('Delete cloud backup'),
        ),
      ],
    );
  }

  // ---- Flows ---------------------------------------------------------------

  Future<void> _onToggle(bool value) async {
    if (!value) {
      final ok = await context.confirm(
        title: 'Turn off cloud backup?',
        message: 'Your local data and your existing cloud backup are both '
            'kept. Automatic backups will simply stop until you turn this back '
            'on.',
        confirmLabel: 'Turn off',
      );
      if (ok) await _run(() => _c.disable());
      return;
    }
    // Explain, then collect a recovery passphrase, then link.
    final proceed = await context.confirm(
      title: 'Back up to Google Drive',
      message: 'BudgetSense will keep one encrypted backup file in a folder '
          'named "BudgetSense_Backup" in your Google Drive. Everything is '
          'encrypted on this device before upload. You will set a recovery '
          'passphrase, which is required to restore after reinstalling or on a '
          'new device. Local use keeps working with or without cloud backup.',
      confirmLabel: 'Continue',
    );
    if (!proceed) return;
    final passphrase = await _askNewPassphrase();
    if (passphrase == null) return;

    await _run(() async {
      final result = await _c.beginLink(passphrase);
      if (!mounted) return;
      if (result.outcome == CloudLinkOutcome.needsReconcile) {
        await _reconcile(result);
      } else {
        _snack('Cloud backup is on. Your data is safely backed up.');
      }
    });
  }

  Future<void> _reconcile(CloudLinkResult link) async {
    final created = link.existing?.createdAt;
    final when =
        created == null ? 'unknown date' : FriendlyDate.relative(created);
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Insets.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('A cloud backup already exists',
                  style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: Insets.xs),
              Text('There is already a BudgetSense backup in this Google '
                  'account (from $when). Choose what to do. Nothing is '
                  'overwritten without your say-so.'),
              const SizedBox(height: Insets.md),
              ListTile(
                leading: const Icon(Icons.cloud_download_outlined),
                title: const Text('Import cloud backup into this device'),
                subtitle: const Text(
                    'Adds the cloud records to this device (nothing is deleted '
                    'or overwritten), then keeps backing up.'),
                onTap: () => Navigator.pop(ctx, 'import'),
              ),
              ListTile(
                leading: const Icon(Icons.cloud_upload_outlined),
                title: const Text('Use this device as the cloud backup'),
                subtitle: const Text(
                    'Replaces the cloud backup file with this device\u2019s '
                    'data. Your local records are untouched; a previous version '
                    'is kept recoverable.'),
                onTap: () => Navigator.pop(ctx, 'overwrite'),
              ),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('Cancel'),
                subtitle:
                    const Text('Do not enable backup or change anything.'),
                onTap: () => Navigator.pop(ctx, 'cancel'),
              ),
            ],
          ),
        ),
      ),
    );
    switch (choice) {
      case 'import':
        await _run(() async {
          final result = await _c.reconcileImport();
          refreshAllDataProviders(ref);
          _showRestoreResult(result);
        });
      case 'overwrite':
        // The sheet is gone by now; if this section left the screen with it we
        // cannot ask, so treat that exactly like declining and change nothing.
        if (!mounted) {
          await _c.reconcileCancel();
          return;
        }
        final ok = await context.confirm(
          title: 'Replace the cloud backup?',
          message:
              'This replaces the cloud backup file with this device\u2019s '
              'data. Your local records are not changed and a previous version '
              'stays recoverable.',
          confirmLabel: 'Replace',
        );
        if (ok) {
          await _run(() => _c.reconcileOverwrite());
        } else {
          await _c.reconcileCancel();
        }
      default:
        await _c.reconcileCancel();
    }
  }

  Future<void> _restoreFromCloud() async {
    final pass = await _askPassphrase('Enter your recovery passphrase');
    if (pass == null) return;
    await _run(() async {
      final preview = await _c.previewCloudRestore(pass);
      if (!mounted) return;
      final ok = await _showRestorePreview(preview);
      if (!ok) return;
      final result = await _c.restoreFromCloud(pass);
      refreshAllDataProviders(ref);
      final latest =
          await ref.read(transactionRepositoryProvider).latestActiveDate();
      if (latest != null) {
        ref.read(focusedMonthProvider.notifier).state = latest;
      }
      _showRestoreResult(result);
    });
  }

  Future<void> _changePassphrase() async {
    final oldP = await _askPassphrase('Current recovery passphrase');
    if (oldP == null) return;
    final newP = await _askNewPassphrase(title: 'New recovery passphrase');
    if (newP == null) return;
    await _run(() async {
      await _c.changePassphrase(oldP, newP);
      _snack('Recovery passphrase changed.');
    });
  }

  Future<void> _deleteCloudBackup() async {
    final ok = await context.confirm(
      title: 'Delete cloud backup?',
      message: 'This permanently deletes the backup file in Google Drive. Your '
          'local data on this device is NOT affected. This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    await _run(() async {
      await _c.deleteCloudBackup();
      _snack('Cloud backup deleted. Local data is untouched.');
    });
  }

  // ---- Dialog helpers ------------------------------------------------------

  void _showRestoreResult(SnapshotImportResult r) {
    final parts = <String>[
      'Added ${r.totalRows} new records',
      if (r.totalSkipped > 0) '${r.totalSkipped} already present (skipped)',
      if (r.totalRemapped > 0) '${r.totalRemapped} conflicts kept as new',
      if (r.totalVersioned > 0) '${r.totalVersioned} newer versions appended',
    ];
    _snack('${parts.join('; ')}. Nothing existing was changed.');
  }

  Future<bool> _showRestorePreview(RestorePreview p) {
    return context.confirm(
      title: 'Restore from cloud?',
      confirmLabel: 'Restore',
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Backup created ${FriendlyDate.relative(p.backupCreatedAt)} '
                '(app v${p.appVersion}).'),
            const SizedBox(height: Insets.sm),
            Text('New records to add: ${p.toInsert}'),
            Text('Already present (skip): ${p.toSkip}'),
            if (p.idConflicts > 0)
              Text('ID conflicts kept separately: ${p.idConflicts}'),
            const SizedBox(height: Insets.sm),
            const Text(
              'Existing data will not be deleted or overwritten. New '
              'records are added. Previously imported records are '
              'skipped. Your current settings stay unless you choose to '
              'apply a backed-up one.',
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _askPassphrase(String title) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Recovery passphrase'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  Future<String?> _askNewPassphrase({
    String title = 'Set a recovery passphrase',
  }) async {
    final p1 = TextEditingController();
    final p2 = TextEditingController();
    final formKey = GlobalKey<FormState>();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'You need this passphrase to restore after reinstalling or on '
                'a new device. BudgetSense cannot recover it for you, so keep '
                'it safe.',
              ),
              const SizedBox(height: Insets.sm),
              TextFormField(
                controller: p1,
                obscureText: true,
                decoration:
                    const InputDecoration(labelText: 'Recovery passphrase'),
                validator: (v) => (v ?? '').trim().length < 8
                    ? 'Use at least 8 characters'
                    : null,
              ),
              TextFormField(
                controller: p2,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Confirm'),
                validator: (v) =>
                    v != p1.text ? 'Passphrases do not match' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(ctx, p1.text);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
