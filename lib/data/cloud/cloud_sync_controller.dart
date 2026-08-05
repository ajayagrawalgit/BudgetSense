import 'dart:async';
import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../domain/services/snapshot_service.dart';
import 'cloud_constants.dart';
import 'cloud_failure.dart';
import 'cloud_gateway.dart';
import 'cloud_metadata_store.dart';
import 'cloud_sync_state.dart';
import 'encryption_service.dart';
import 'mutation_tracker.dart';

/// Outcome of beginning the cloud link.
enum CloudLinkOutcome { linkedFresh, needsReconcile }

class CloudLinkResult {
  const CloudLinkResult(this.outcome, {this.existing});
  final CloudLinkOutcome outcome;
  final EncryptedEnvelopeHeader? existing;
}

/// The brain that ties the snapshot engine, encryption, gateways, metadata, and
/// mutation tracking together (Phases 5 to 9). Strictly opt-in: nothing here
/// authenticates or touches the network until [beginLink] runs from an explicit
/// user gesture.
class CloudSyncController extends ChangeNotifier {
  CloudSyncController({
    required SnapshotService snapshot,
    required SnapshotEncryptionService encryption,
    required CloudBackupAuthGateway auth,
    required CloudBackupGateway gateway,
    required CloudSyncMetadataStore metadata,
    required BackupMutationTracker tracker,
    BackgroundSyncScheduler scheduler = const NoopBackgroundSyncScheduler(),
    Uuid uuid = const Uuid(),
    Duration debounce = CloudBackupConstants.debounce,
    Future<void> Function(List<int> plaintextBackup)? onRestoreApplied,
  })  : _snapshot = snapshot,
        _enc = encryption,
        _auth = auth,
        _gw = gateway,
        _meta = metadata,
        _tracker = tracker,
        _scheduler = scheduler,
        _uuid = uuid,
        _debounce = debounce,
        _onRestoreApplied = onRestoreApplied;

  final SnapshotService _snapshot;
  final SnapshotEncryptionService _enc;
  final CloudBackupAuthGateway _auth;
  final CloudBackupGateway _gw;
  final CloudSyncMetadataStore _meta;
  final BackupMutationTracker _tracker;
  final BackgroundSyncScheduler _scheduler;
  final Uuid _uuid;
  final Duration _debounce;
  final Future<void> Function(List<int>)? _onRestoreApplied;

  CloudSyncState _state = const CloudSyncState();
  CloudSyncState get state => _state;

  Timer? _debounceTimer;
  bool _syncing = false;
  String? _pendingPassphrase; // in memory only, during linking

  void _set(CloudSyncState s) {
    _state = s;
    notifyListeners();
  }

  /// Restore prior state on app start. Best-effort silent re-auth; never
  /// interactive. Kicks a pending upload if enabled and something is waiting.
  Future<void> loadOnStart() async {
    if (!_meta.enabled) {
      _set(const CloudSyncState());
      return;
    }
    _set(CloudSyncState(
      status:
          _tracker.isPending ? CloudSyncStatus.pending : CloudSyncStatus.idle,
      email: _meta.email,
      lastSyncAt: _meta.lastSyncAt,
      pending: _tracker.isPending,
    ));
    try {
      final account = await _auth.signInSilently();
      if (account == null) {
        _set(_state.copyWith(status: CloudSyncStatus.requiresSignIn));
        return;
      }
      if (_tracker.isPending) await syncNow();
    } on CloudFailure catch (f) {
      _applyFailure(f);
    }
  }

  // ---- Linking / setup -----------------------------------------------------

  /// Step 1 of enabling: authenticate, ensure the folder + file, and detect an
  /// existing remote backup. Must be called from a user gesture.
  Future<CloudLinkResult> beginLink(String passphrase) async {
    _set(const CloudSyncState(status: CloudSyncStatus.linking));
    _pendingPassphrase = passphrase;
    final account = await _auth.signIn();
    await _meta.setAccount(account.id, account.email);
    final folder = await _gw.ensureFolder();
    await _meta.setFolder(folder.id);

    final existing = await _gw.findBackupFile(folder.id);
    if (existing == null) {
      await _finishFreshLink(account, passphrase);
      return const CloudLinkResult(CloudLinkOutcome.linkedFresh);
    }
    await _meta.setFile(existing.id);
    // Peek the header so reconciliation UI can show its age (no decrypt).
    final bytes = await _gw.downloadBackupFile(existing.id);
    final header = _enc.readHeader(bytes);
    _set(_state.copyWith(
        status: CloudSyncStatus.remoteConflict, email: account.email));
    return CloudLinkResult(CloudLinkOutcome.needsReconcile, existing: header);
  }

  Future<void> _finishFreshLink(CloudAccount account, String passphrase) async {
    final backupId = _uuid.v4();
    await _meta.setCloudBackupId(backupId);
    final key = await _enc.deriveNewKeyMaterial(passphrase);
    await _meta.writeKeyMaterial(key);
    await _meta.setEnabled(true);
    await _uploadCurrent(key, backupId, create: true);
    _pendingPassphrase = null;
    await _scheduler.scheduleUniqueSync();
    _refreshEnabledState();
  }

  /// Reconcile option 1: import the existing cloud backup into this device
  /// (append-only), then continue the SAME cloud file lineage.
  Future<SnapshotImportResult> reconcileImport() async {
    final pass = _requirePendingPass();
    final fileId = _meta.fileId!;
    final bytes = await _gw.downloadBackupFile(fileId);
    // Recover the key lineage (validates the passphrase before any local write).
    final key = await _enc.recoverKeyMaterial(bytes, pass);
    final plain = await _enc.decryptWithKey(bytes, key);
    final result = await _snapshot.importBytes(plain);
    if (_onRestoreApplied != null) await _onRestoreApplied(plain);

    final header = _enc.readHeader(bytes);
    await _meta.setCloudBackupId(header.backupId);
    await _meta.writeKeyMaterial(key);
    await _meta.setEnabled(true);
    // Upload the merged local state back, same file + key.
    await _uploadCurrent(key, header.backupId, create: false);
    _pendingPassphrase = null;
    await _scheduler.scheduleUniqueSync();
    _refreshEnabledState();
    return result;
  }

  /// Reconcile option 2: make THIS device the source, replacing the cloud file
  /// content (a prior revision is retained by Drive). Local data untouched.
  Future<void> reconcileOverwrite() async {
    final pass = _requirePendingPass();
    final backupId = _uuid.v4();
    await _meta.setCloudBackupId(backupId);
    final key = await _enc.deriveNewKeyMaterial(pass);
    await _meta.writeKeyMaterial(key);
    await _meta.setEnabled(true);
    await _uploadCurrent(key, backupId, create: false);
    _pendingPassphrase = null;
    await _scheduler.scheduleUniqueSync();
    _refreshEnabledState();
  }

  /// Reconcile option 3: cancel. No local or remote change; not enabled.
  Future<void> reconcileCancel() async {
    _pendingPassphrase = null;
    await _auth.signOut();
    await _meta.clearLink();
    _set(const CloudSyncState());
  }

  // ---- Foreground sync -----------------------------------------------------

  /// Record a committed mutation and schedule a debounced, coalesced upload.
  Future<void> markDirty() async {
    if (!_meta.enabled) return;
    await _tracker.markDirty();
    _set(_state.copyWith(status: CloudSyncStatus.pending, pending: true));
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, () => unawaited(syncNow()));
  }

  /// Upload the current snapshot if pending. Never overlaps; if new mutations
  /// arrive mid-upload, the generation stays pending and another sync runs.
  Future<void> syncNow() async {
    if (!_meta.enabled || _syncing) return;
    final key = await _meta.readKeyMaterial();
    final backupId = _meta.cloudBackupId;
    if (key == null || backupId == null) {
      _set(_state.copyWith(status: CloudSyncStatus.requiresSignIn));
      return;
    }
    _syncing = true;
    _set(_state.copyWith(status: CloudSyncStatus.syncing));
    try {
      await _uploadCurrent(key, backupId, create: _meta.fileId == null);
      _refreshEnabledState();
    } on CloudFailure catch (f) {
      _applyFailure(f);
    } finally {
      _syncing = false;
    }
  }

  Future<void> _uploadCurrent(
    BackupKeyMaterial key,
    String backupId, {
    required bool create,
  }) async {
    final generation = _tracker.currentGeneration;
    final export = await _snapshot.export(SnapshotFormat.json);
    final encrypted = await _enc.encrypt(
      payload: export.bytes,
      key: key,
      backupId: backupId,
      formatVersion: AppSnapshot.currentVersion,
    );
    final digest = await _sha256(encrypted);

    final RemoteBackupFile remote;
    if (create || _meta.fileId == null) {
      remote = await _gw.createBackupFile(
        folderId: _meta.folderId!,
        bytes: encrypted,
        payloadDigest: digest,
        generation: generation,
        formatVersion: AppSnapshot.currentVersion,
      );
      await _meta.setFile(remote.id);
    } else {
      remote = await _gw.updateBackupFile(
        fileId: _meta.fileId!,
        bytes: encrypted,
        payloadDigest: digest,
        generation: generation,
        formatVersion: AppSnapshot.currentVersion,
        expectedVersion: _meta.lastRemoteVersion,
      );
    }

    // Validate the remote reflects exactly what we uploaded before trusting it.
    if (remote.payloadDigest != null && remote.payloadDigest != digest) {
      throw const CloudFailure(
        CloudFailureKind.uploadIntegrityMismatch,
        'The uploaded backup could not be verified on Google Drive. Your '
        'previous backup was kept; BudgetSense will try again.',
      );
    }
    await _meta.recordUpload(
      remoteVersion: remote.version,
      payloadDigest: digest,
      uploadedGeneration: generation,
      at: DateTime.now(),
    );
    await _tracker.markUploaded(generation);
  }

  // ---- Manual restore from Drive -------------------------------------------

  /// Preview a restore from the current cloud file (mutation-free).
  Future<RestorePreview> previewCloudRestore(String passphrase) async {
    final bytes = await _gw.downloadBackupFile(_meta.fileId!);
    final plain = await _enc.decryptWithPassphrase(bytes, passphrase);
    return _snapshot.preview(plain);
  }

  /// Apply an append-only restore from the current cloud file.
  Future<SnapshotImportResult> restoreFromCloud(
    String passphrase, {
    Set<String>? applySettingKeys,
  }) async {
    final bytes = await _gw.downloadBackupFile(_meta.fileId!);
    final plain = await _enc.decryptWithPassphrase(bytes, passphrase);
    final result =
        await _snapshot.importBytes(plain, applySettingKeys: applySettingKeys);
    if (_onRestoreApplied != null) await _onRestoreApplied(plain);
    return result;
  }

  // ---- Passphrase / disable / delete ---------------------------------------

  /// Change the recovery passphrase safely: re-wrap the DEK and re-upload the
  /// latest validated snapshot. The encryption key itself is never reset.
  Future<void> changePassphrase(String oldPass, String newPass) async {
    final fileId = _meta.fileId;
    final backupId = _meta.cloudBackupId;
    if (fileId == null || backupId == null) {
      throw const CloudFailure(
        CloudFailureKind.fileMissing,
        'There is no cloud backup to update yet.',
      );
    }
    final bytes = await _gw.downloadBackupFile(fileId);
    final rewrapped = await _enc.rewrapForNewPassphrase(
      bytes: bytes,
      oldPassphrase: oldPass,
      newPassphrase: newPass,
    );
    await _meta.writeKeyMaterial(rewrapped);
    await _uploadCurrent(rewrapped, backupId, create: false);
    _refreshEnabledState();
  }

  /// Turn off automatic backup. Preserves local data AND the cloud file. Cancels
  /// background work. Does not disconnect the account.
  Future<void> disable() async {
    await _scheduler.cancel();
    await _meta.setEnabled(false);
    _debounceTimer?.cancel();
    _set(const CloudSyncState());
  }

  /// Fully disconnect the Google account. Preserves local data and the cloud
  /// file by default (delete is separate).
  Future<void> disconnect() async {
    await _scheduler.cancel();
    await _auth.disconnect();
    await _meta.clearLink();
    await _tracker.reset();
    _debounceTimer?.cancel();
    _set(const CloudSyncState());
  }

  /// Explicitly, destructively delete the cloud backup file. Local data stays.
  Future<void> deleteCloudBackup() async {
    final fileId = _meta.fileId;
    if (fileId != null) await _gw.deleteBackupFile(fileId);
  }

  // ---- Helpers -------------------------------------------------------------

  void _refreshEnabledState() {
    _set(CloudSyncState(
      status:
          _tracker.isPending ? CloudSyncStatus.pending : CloudSyncStatus.idle,
      email: _meta.email,
      lastSyncAt: _meta.lastSyncAt,
      pending: _tracker.isPending,
    ));
  }

  void _applyFailure(CloudFailure f) {
    unawaited(_meta.setLastError(f.kind.name));
    final status = switch (f.kind) {
      CloudFailureKind.remoteConflict => CloudSyncStatus.remoteConflict,
      CloudFailureKind.authRequired ||
      CloudFailureKind.authorizationRevoked ||
      CloudFailureKind.insufficientScope ||
      CloudFailureKind.wrongAccount =>
        CloudSyncStatus.requiresSignIn,
      _ => f.isTransient ? CloudSyncStatus.pending : CloudSyncStatus.error,
    };
    _set(_state.copyWith(
      status: status,
      pending: _tracker.isPending,
      lastError: f,
    ));
    if (f.isTransient) unawaited(_scheduler.scheduleUniqueSync());
  }

  String _requirePendingPass() {
    final p = _pendingPassphrase;
    if (p == null) {
      throw const CloudFailure(
        CloudFailureKind.unknown,
        'The setup session expired. Please start again.',
      );
    }
    return p;
  }

  Future<String> _sha256(List<int> bytes) async {
    final hash = await Sha256().hash(bytes);
    return base64Encode(hash.bytes);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}
