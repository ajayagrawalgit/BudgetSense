import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

import '../cloud/cloud_stores.dart';
import 'apk_installer.dart';
import 'update_constants.dart';
import 'update_gateway.dart';
import 'update_manifest.dart';

enum UpdateStatus {
  idle,
  checking,
  upToDate,
  available,
  downloading,
  verifying,
  installing,
  error,
}

/// Immutable UI view of the update state.
class UpdateState {
  const UpdateState({
    this.status = UpdateStatus.idle,
    this.manifest,
    this.progress = 0,
    this.message,
  });

  final UpdateStatus status;
  final UpdateManifest? manifest;
  final double progress; // 0..1 during download
  final String? message;

  bool get hasUpdate =>
      manifest != null &&
      (status == UpdateStatus.available ||
          status == UpdateStatus.downloading ||
          status == UpdateStatus.verifying ||
          status == UpdateStatus.installing);

  UpdateState copyWith({
    UpdateStatus? status,
    UpdateManifest? manifest,
    double? progress,
    String? message,
    bool clearMessage = false,
  }) =>
      UpdateState(
        status: status ?? this.status,
        manifest: manifest ?? this.manifest,
        progress: progress ?? this.progress,
        message: clearMessage ? null : (message ?? this.message),
      );
}

/// Coordinates the whole "check -> offer -> download -> verify -> install" flow
/// for sideloaded (non-Play) builds. Never forces anything: the user always
/// chooses to update or dismiss.
class UpdateService extends ChangeNotifier {
  UpdateService({
    required UpdateGateway gateway,
    required ApkInstaller installer,
    required KeyValueStore store,
    required Future<int> Function() currentVersionCode,
    required Future<String> Function() downloadDirectory,
  })  : _gateway = gateway,
        _installer = installer,
        _store = store,
        _currentVersionCode = currentVersionCode,
        _downloadDir = downloadDirectory;

  final UpdateGateway _gateway;
  final ApkInstaller _installer;
  final KeyValueStore _store;
  final Future<int> Function() _currentVersionCode;
  final Future<String> Function() _downloadDir;

  UpdateState _state = const UpdateState();
  UpdateState get state => _state;

  void _set(UpdateState s) {
    _state = s;
    notifyListeners();
  }

  /// Quiet check for a newer version. Safe to call on launch: it never throws,
  /// does nothing when updates are not configured (the gateway returns null),
  /// and stays silent if the user already dismissed the newest version.
  Future<void> checkForUpdate({bool silent = true}) async {
    _set(_state.copyWith(status: UpdateStatus.checking, clearMessage: true));
    try {
      final manifest = await _gateway.fetchLatest();
      final current = await _currentVersionCode();
      if (manifest == null || !manifest.isNewerThan(current)) {
        _set(const UpdateState(status: UpdateStatus.upToDate));
        return;
      }
      if (silent && manifest.versionCode == _dismissedVersion) {
        // Respect the user's earlier "not now" for this exact version.
        _set(const UpdateState(status: UpdateStatus.idle));
        return;
      }
      _set(UpdateState(status: UpdateStatus.available, manifest: manifest));
    } catch (_) {
      // A failed check must never disrupt the app.
      _set(_state.copyWith(
        status: UpdateStatus.error,
        message: silent
            ? null
            : 'Could not check for updates right now. Please try again later.',
      ));
    }
  }

  /// The user chose "not now". Remember it so we do not nag for this version.
  Future<void> dismiss() async {
    final v = _state.manifest?.versionCode;
    if (v != null) await _store.setInt(UpdateConfig.dismissedVersionKey, v);
    _set(const UpdateState(status: UpdateStatus.idle));
  }

  int? get _dismissedVersion => _store.getInt(UpdateConfig.dismissedVersionKey);

  /// Download the APK, verify its SHA-256, and hand it to the OS installer.
  /// Aborts safely on any mismatch; never installs an unverified file.
  Future<void> downloadAndInstall() async {
    final manifest = _state.manifest;
    if (manifest == null) return;
    try {
      _set(_state.copyWith(
          status: UpdateStatus.downloading, progress: 0, clearMessage: true));
      final dir = await _downloadDir();
      final dest = '$dir/BudgetSense-${manifest.versionName}.apk';
      final file = await _gateway.downloadApk(
        manifest.apkUrl,
        dest,
        onProgress: (p) => _set(
            _state.copyWith(status: UpdateStatus.downloading, progress: p)),
      );

      _set(_state.copyWith(status: UpdateStatus.verifying));
      final ok = await _verifySha256(file, manifest.sha256);
      if (!ok) {
        await _safeDelete(file);
        _set(_state.copyWith(
          status: UpdateStatus.error,
          message: 'The downloaded update did not pass its safety check and '
              'was discarded. Your app was not changed.',
        ));
        return;
      }

      _set(_state.copyWith(status: UpdateStatus.installing));
      if (!await _installer.canInstall()) {
        final outcome = await _installer.install(file.path);
        // needsPermission routes the user to the OS setting; they retry after.
        _set(_state.copyWith(
          status: UpdateStatus.available,
          message: outcome == InstallOutcome.needsPermission
              ? 'Please allow BudgetSense to install updates, then tap Update '
                  'again.'
              : 'Could not start the installer. Please try again.',
        ));
        return;
      }
      final outcome = await _installer.install(file.path);
      if (outcome == InstallOutcome.failed) {
        _set(_state.copyWith(
          status: UpdateStatus.error,
          message: 'Could not start the installer. Please try again.',
        ));
      }
      // On success the OS install dialog takes over.
    } catch (_) {
      _set(_state.copyWith(
        status: UpdateStatus.error,
        message: 'The update could not be downloaded. Please try again later.',
      ));
    }
  }

  Future<bool> _verifySha256(File file, String expectedHex) async {
    final bytes = await file.readAsBytes();
    final hash = await Sha256().hash(bytes);
    final actual =
        hash.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return actual == expectedHex.toLowerCase();
  }

  Future<void> _safeDelete(File f) async {
    try {
      if (await f.exists()) await f.delete();
    } catch (_) {
      // Best effort; a leftover temp file is harmless.
    }
  }
}
