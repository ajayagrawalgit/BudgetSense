import 'dart:convert';

import 'encryption_service.dart';
import 'cloud_stores.dart';

/// Device- and account-specific cloud sync metadata (Phase 5).
///
/// This is deliberately stored SEPARATELY from the user snapshot: it describes
/// this device's link to a Google account and must never travel in a backup.
/// Encryption key material lives in the [SecretStore] (Keystore/Keychain);
/// everything else lives in the plain [KeyValueStore].
class CloudSyncMetadataStore {
  CloudSyncMetadataStore({
    required KeyValueStore kv,
    required SecretStore secrets,
  })  : _kv = kv,
        _secrets = secrets;

  final KeyValueStore _kv;
  final SecretStore _secrets;

  static const _kAccountId = 'accountId';
  static const _kEmail = 'email';
  static const _kFolderId = 'folderId';
  static const _kFileId = 'fileId';
  static const _kEnabled = 'enabled';
  static const _kBackupId = 'cloudBackupId';
  static const _kLastRemoteVersion = 'lastRemoteVersion';
  static const _kLastDigest = 'lastPayloadDigest';
  static const _kLastUploadedGen = 'lastUploadedGeneration';
  static const _kLastSyncAt = 'lastSyncAtMs';
  static const _kLastError = 'lastErrorCategory';
  static const _kKeyMaterial = 'budgetsense.cloud.keyMaterial';

  String? get accountId => _kv.getString(_kAccountId);
  String? get email => _kv.getString(_kEmail);
  String? get folderId => _kv.getString(_kFolderId);
  String? get fileId => _kv.getString(_kFileId);
  bool get enabled => _kv.getBool(_kEnabled) ?? false;
  String? get cloudBackupId => _kv.getString(_kBackupId);
  int? get lastRemoteVersion => _kv.getInt(_kLastRemoteVersion);
  String? get lastPayloadDigest => _kv.getString(_kLastDigest);
  int? get lastUploadedGeneration => _kv.getInt(_kLastUploadedGen);
  String? get lastErrorCategory => _kv.getString(_kLastError);

  DateTime? get lastSyncAt {
    final ms = _kv.getInt(_kLastSyncAt);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> setAccount(String id, String email) async {
    await _kv.setString(_kAccountId, id);
    await _kv.setString(_kEmail, email);
  }

  Future<void> setFolder(String id) => _kv.setString(_kFolderId, id);
  Future<void> setFile(String id) => _kv.setString(_kFileId, id);
  Future<void> setEnabled(bool value) => _kv.setBool(_kEnabled, value);
  Future<void> setCloudBackupId(String id) => _kv.setString(_kBackupId, id);

  Future<void> recordUpload({
    required int remoteVersion,
    required String payloadDigest,
    required int uploadedGeneration,
    required DateTime at,
  }) async {
    await _kv.setInt(_kLastRemoteVersion, remoteVersion);
    await _kv.setString(_kLastDigest, payloadDigest);
    await _kv.setInt(_kLastUploadedGen, uploadedGeneration);
    await _kv.setInt(_kLastSyncAt, at.millisecondsSinceEpoch);
    await _kv.remove(_kLastError);
  }

  Future<void> setLastError(String? category) async {
    if (category == null) {
      await _kv.remove(_kLastError);
    } else {
      await _kv.setString(_kLastError, category);
    }
  }

  /// Whether the cached ids belong to [accountId]. Guards against ever reusing
  /// folder/file ids that belong to a different Google account.
  bool isBoundTo(String accountId) => this.accountId == accountId;

  Future<BackupKeyMaterial?> readKeyMaterial() async {
    final raw = await _secrets.read(_kKeyMaterial);
    if (raw == null) return null;
    return BackupKeyMaterial.fromSecureJson(
      Map<String, Object?>.from(jsonDecode(raw) as Map),
    );
  }

  Future<void> writeKeyMaterial(BackupKeyMaterial key) =>
      _secrets.write(_kKeyMaterial, jsonEncode(key.toSecureJson()));

  /// Clears device link + cached ids. Called on disconnect. Does NOT delete the
  /// remote file (that is a separate, explicitly confirmed action).
  Future<void> clearLink({bool clearKeyMaterial = true}) async {
    for (final k in [
      _kAccountId,
      _kEmail,
      _kFolderId,
      _kFileId,
      _kEnabled,
      _kBackupId,
      _kLastRemoteVersion,
      _kLastDigest,
      _kLastUploadedGen,
      _kLastSyncAt,
      _kLastError,
    ]) {
      await _kv.remove(k);
    }
    if (clearKeyMaterial) await _secrets.delete(_kKeyMaterial);
  }
}
