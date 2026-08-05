import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'cloud_failure.dart';

/// Client-side backup encryption (Phase 3), used before any cloud upload.
///
/// Design:
///   * Authenticated encryption: AES-256-GCM (unique nonce per payload).
///   * A random 256-bit Data Encryption Key (DEK) encrypts the snapshot.
///   * The DEK is WRAPPED (encrypted) with a Key Encryption Key (KEK) derived
///     from the user's recovery passphrase via PBKDF2-HMAC-SHA256. The wrapped
///     DEK, salt, and KDF parameters live in the envelope, so restore after
///     reinstall or on another device needs only the passphrase.
///   * Critical envelope metadata (product, format version, backup id) is bound
///     as Additional Authenticated Data (AAD), so tampering with it fails
///     decryption.
///   * The DEK may be cached in secure storage for automatic future uploads;
///     the passphrase is never stored and never logged.
///
/// No cryptographic primitive is hand-rolled; everything uses the maintained
/// `cryptography` package. Proven by `test/data/cloud/encryption_service_test`.
class SnapshotEncryptionService {
  SnapshotEncryptionService({Random? random})
      : _random = random ?? Random.secure();

  final Random _random;
  final AesGcm _aes = AesGcm.with256bits();

  /// Envelope format version (independent of the snapshot format version).
  static const int envelopeVersion = 1;
  static const int _saltBytes = 16;
  static const int defaultIterations = 210000;

  /// Generate fresh key material for a brand-new backup: a random DEK wrapped
  /// under a KEK derived from [passphrase]. Cache the returned DEK (only) in
  /// secure storage for automatic uploads.
  Future<BackupKeyMaterial> deriveNewKeyMaterial(
    String passphrase, {
    int iterations = defaultIterations,
  }) async {
    _requirePassphrase(passphrase);
    final salt = _randomBytes(_saltBytes);
    final dek = _randomBytes(32);
    final wrap = await _wrapDek(dek, passphrase, salt, iterations);
    return BackupKeyMaterial(
      dek: dek,
      salt: salt,
      iterations: iterations,
      wrappedKey: wrap.cipherText,
      wrapNonce: wrap.nonce,
      wrapMac: wrap.mac.bytes,
    );
  }

  /// Re-wrap the existing DEK under a NEW passphrase (Phase 3: safe passphrase
  /// change). The DEK is unchanged, so previously encrypted payloads remain
  /// valid; only the wrap material (salt + wrapped key) changes.
  Future<BackupKeyMaterial> rewrapForNewPassphrase({
    required List<int> bytes,
    required String oldPassphrase,
    required String newPassphrase,
    int iterations = defaultIterations,
  }) async {
    _requirePassphrase(newPassphrase);
    final env = _EncEnvelope.parse(bytes);
    final dek = await _unwrapDek(env, oldPassphrase);
    final salt = _randomBytes(_saltBytes);
    final wrap = await _wrapDek(dek, newPassphrase, salt, iterations);
    return BackupKeyMaterial(
      dek: dek,
      salt: salt,
      iterations: iterations,
      wrappedKey: wrap.cipherText,
      wrapNonce: wrap.nonce,
      wrapMac: wrap.mac.bytes,
    );
  }

  /// Encrypt a plaintext snapshot [payload] into a self-describing envelope,
  /// using cached [key] material (no passphrase needed for routine uploads).
  Future<Uint8List> encrypt({
    required List<int> payload,
    required BackupKeyMaterial key,
    required String backupId,
    required int formatVersion,
  }) async {
    final aad = _aad(backupId, formatVersion);
    final secretKey = SecretKey(key.dek);
    final box = await _aes.encrypt(
      payload,
      secretKey: secretKey,
      nonce: _aes.newNonce(),
      aad: aad,
    );
    final env = _EncEnvelope(
      salt: key.salt,
      iterations: key.iterations,
      wrappedKey: key.wrappedKey,
      wrapNonce: key.wrapNonce,
      wrapMac: key.wrapMac,
      nonce: box.nonce,
      ciphertext: box.cipherText,
      mac: box.mac.bytes,
      backupId: backupId,
      formatVersion: formatVersion,
      createdAt: DateTime.now().toUtc(),
    );
    return env.toBytes();
  }

  /// Decrypt an envelope with the recovery [passphrase] (restore on a new
  /// device / after reinstall). Wrong passphrase or tampering throws a
  /// [CloudFailure] BEFORE any caller mutates local data.
  Future<Uint8List> decryptWithPassphrase(
    List<int> bytes,
    String passphrase,
  ) async {
    final env = _EncEnvelope.parse(bytes);
    final dek = await _unwrapDek(env, passphrase);
    return _decryptPayload(env, dek);
  }

  /// Decrypt using the cached DEK (routine local verification / same-device
  /// restore). Tampering throws a [CloudFailure].
  Future<Uint8List> decryptWithKey(
    List<int> bytes,
    BackupKeyMaterial key,
  ) async {
    final env = _EncEnvelope.parse(bytes);
    return _decryptPayload(env, key.dek);
  }

  /// Recover the full [BackupKeyMaterial] from an existing envelope using the
  /// recovery [passphrase]. Used by import-reconciliation so a device joining
  /// an existing cloud backup continues the SAME key lineage (the cached DEK
  /// then encrypts future uploads without re-prompting). Wrong passphrase
  /// throws [CloudFailure] before anything is cached.
  Future<BackupKeyMaterial> recoverKeyMaterial(
    List<int> bytes,
    String passphrase,
  ) async {
    final env = _EncEnvelope.parse(bytes);
    final dek = await _unwrapDek(env, passphrase);
    return BackupKeyMaterial(
      dek: dek,
      salt: env.salt,
      iterations: env.iterations,
      wrappedKey: env.wrappedKey,
      wrapNonce: env.wrapNonce,
      wrapMac: env.wrapMac,
    );
  }

  /// Read the (unauthenticated) envelope header for reconciliation UI without
  /// decrypting the payload. Only metadata, never contents.
  EncryptedEnvelopeHeader readHeader(List<int> bytes) {
    final env = _EncEnvelope.parse(bytes);
    return EncryptedEnvelopeHeader(
      backupId: env.backupId,
      formatVersion: env.formatVersion,
      createdAt: env.createdAt,
    );
  }

  // ---- internals -----------------------------------------------------------

  Future<SecretBox> _wrapDek(
    List<int> dek,
    String passphrase,
    List<int> salt,
    int iterations,
  ) async {
    final kek = await _deriveKek(passphrase, salt, iterations);
    return _aes.encrypt(dek, secretKey: kek, nonce: _aes.newNonce());
  }

  Future<List<int>> _unwrapDek(_EncEnvelope env, String passphrase) async {
    final kek = await _deriveKek(passphrase, env.salt, env.iterations);
    try {
      return await _aes.decrypt(
        SecretBox(env.wrappedKey, nonce: env.wrapNonce, mac: Mac(env.wrapMac)),
        secretKey: kek,
      );
    } on SecretBoxAuthenticationError {
      throw const CloudFailure(
        CloudFailureKind.incorrectPassphrase,
        'That recovery passphrase is not correct for this backup.',
      );
    }
  }

  Future<Uint8List> _decryptPayload(_EncEnvelope env, List<int> dek) async {
    try {
      final clear = await _aes.decrypt(
        SecretBox(env.ciphertext, nonce: env.nonce, mac: Mac(env.mac)),
        secretKey: SecretKey(dek),
        aad: _aad(env.backupId, env.formatVersion),
      );
      return Uint8List.fromList(clear);
    } on SecretBoxAuthenticationError {
      throw const CloudFailure(
        CloudFailureKind.downloadIntegrityMismatch,
        'This backup could not be verified. It may be corrupted or tampered '
        'with, so it was not restored.',
      );
    }
  }

  Future<SecretKey> _deriveKek(
    String passphrase,
    List<int> salt,
    int iterations,
  ) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: 256,
    );
    return pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(passphrase)),
      nonce: salt,
    );
  }

  List<int> _aad(String backupId, int formatVersion) =>
      utf8.encode('BudgetSense|$envelopeVersion|$backupId|$formatVersion');

  void _requirePassphrase(String passphrase) {
    if (passphrase.trim().length < 8) {
      throw const CloudFailure(
        CloudFailureKind.encryptionFailed,
        'Choose a recovery passphrase of at least 8 characters.',
      );
    }
  }

  Uint8List _randomBytes(int n) {
    final out = Uint8List(n);
    for (var i = 0; i < n; i++) {
      out[i] = _random.nextInt(256);
    }
    return out;
  }
}

/// Key material for a backup lifecycle. Cache only [dek] (plus salt/wrap for
/// re-upload) in secure storage; never persist the passphrase.
class BackupKeyMaterial {
  const BackupKeyMaterial({
    required this.dek,
    required this.salt,
    required this.iterations,
    required this.wrappedKey,
    required this.wrapNonce,
    required this.wrapMac,
  });

  final List<int> dek;
  final List<int> salt;
  final int iterations;
  final List<int> wrappedKey;
  final List<int> wrapNonce;
  final List<int> wrapMac;

  Map<String, Object?> toSecureJson() => {
        'dek': base64Encode(dek),
        'salt': base64Encode(salt),
        'iterations': iterations,
        'wrappedKey': base64Encode(wrappedKey),
        'wrapNonce': base64Encode(wrapNonce),
        'wrapMac': base64Encode(wrapMac),
      };

  factory BackupKeyMaterial.fromSecureJson(Map<String, Object?> m) =>
      BackupKeyMaterial(
        dek: base64Decode(m['dek']! as String),
        salt: base64Decode(m['salt']! as String),
        iterations: (m['iterations']! as num).toInt(),
        wrappedKey: base64Decode(m['wrappedKey']! as String),
        wrapNonce: base64Decode(m['wrapNonce']! as String),
        wrapMac: base64Decode(m['wrapMac']! as String),
      );
}

/// Non-secret header metadata for the reconciliation UI.
class EncryptedEnvelopeHeader {
  const EncryptedEnvelopeHeader({
    required this.backupId,
    required this.formatVersion,
    required this.createdAt,
  });
  final String backupId;
  final int formatVersion;
  final DateTime createdAt;
}

/// Internal wire format for an encrypted backup file (`.bsbak`).
class _EncEnvelope {
  _EncEnvelope({
    required this.salt,
    required this.iterations,
    required this.wrappedKey,
    required this.wrapNonce,
    required this.wrapMac,
    required this.nonce,
    required this.ciphertext,
    required this.mac,
    required this.backupId,
    required this.formatVersion,
    required this.createdAt,
  });

  final List<int> salt;
  final int iterations;
  final List<int> wrappedKey;
  final List<int> wrapNonce;
  final List<int> wrapMac;
  final List<int> nonce;
  final List<int> ciphertext;
  final List<int> mac;
  final String backupId;
  final int formatVersion;
  final DateTime createdAt;

  Uint8List toBytes() {
    final map = <String, Object?>{
      'bsbak': SnapshotEncryptionService.envelopeVersion,
      'product': 'BudgetSense',
      'cipher': 'AES-256-GCM',
      'kdf': 'PBKDF2-HMAC-SHA256',
      'iterations': iterations,
      'salt': base64Encode(salt),
      'wrappedKey': base64Encode(wrappedKey),
      'wrapNonce': base64Encode(wrapNonce),
      'wrapMac': base64Encode(wrapMac),
      'nonce': base64Encode(nonce),
      'ciphertext': base64Encode(ciphertext),
      'mac': base64Encode(mac),
      'backupId': backupId,
      'formatVersion': formatVersion,
      'createdAt': createdAt.toIso8601String(),
    };
    return Uint8List.fromList(utf8.encode(jsonEncode(map)));
  }

  static _EncEnvelope parse(List<int> bytes) {
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes));
    } catch (_) {
      throw const CloudFailure(
        CloudFailureKind.downloadIntegrityMismatch,
        'This backup file is not a valid BudgetSense encrypted backup.',
      );
    }
    if (decoded is! Map || decoded['product'] != 'BudgetSense') {
      throw const CloudFailure(
        CloudFailureKind.downloadIntegrityMismatch,
        'This backup file is not a valid BudgetSense encrypted backup.',
      );
    }
    final m = Map<String, Object?>.from(decoded);
    final v = (m['bsbak'] as num?)?.toInt() ?? 0;
    if (v > SnapshotEncryptionService.envelopeVersion) {
      throw const CloudFailure(
        CloudFailureKind.unsupportedVersion,
        'This backup was made by a newer version of BudgetSense. Update the '
        'app, then restore.',
      );
    }
    List<int> b(String k) => base64Decode(m[k]! as String);
    return _EncEnvelope(
      salt: b('salt'),
      iterations: (m['iterations']! as num).toInt(),
      wrappedKey: b('wrappedKey'),
      wrapNonce: b('wrapNonce'),
      wrapMac: b('wrapMac'),
      nonce: b('nonce'),
      ciphertext: b('ciphertext'),
      mac: b('mac'),
      backupId: '${m['backupId']}',
      formatVersion: (m['formatVersion'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse('${m['createdAt']}')?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }
}
