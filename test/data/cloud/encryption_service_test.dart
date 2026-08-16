import 'dart:convert';
import 'dart:typed_data';

import 'package:budgetsense/data/cloud/cloud_failure.dart';
import 'package:budgetsense/data/cloud/encryption_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Encryption / integrity tests (Phase 3/13). Real AES-256-GCM + PBKDF2.
void main() {
  // The lowest iteration count the envelope format accepts. Tests used to run
  // at 1000 for speed, but the parser now enforces a floor so a hostile backup
  // cannot downgrade the KDF, and the write path matches it. The real floor is
  // fast enough here (the whole file runs in a few seconds), so the tests
  // exercise the same bounds production does rather than a weakened value.
  const iters = SnapshotEncryptionService.minAcceptedIterations;
  final svc = SnapshotEncryptionService();
  final payload =
      Uint8List.fromList(utf8.encode('{"secret":"₹ Café expenses"}'));

  Future<Uint8List> encrypt(String pass, {String backupId = 'b1'}) async {
    final key = await svc.deriveNewKeyMaterial(pass, iterations: iters);
    return svc.encrypt(
      payload: payload,
      key: key,
      backupId: backupId,
      formatVersion: 4,
    );
  }

  test('round-trips with the correct passphrase', () async {
    final bytes = await encrypt('correct horse');
    final clear = await svc.decryptWithPassphrase(bytes, 'correct horse');
    expect(clear, equals(payload));
  });

  test('never stores plaintext: payload does not appear in the ciphertext',
      () async {
    final bytes = await encrypt('correct horse');
    final asText = utf8.decode(bytes);
    expect(asText.contains('Café'), isFalse);
    expect(asText.contains('secret'), isFalse);
    // It IS a self-describing envelope though.
    expect(asText.contains('AES-256-GCM'), isTrue);
  });

  test('wrong passphrase fails BEFORE returning any plaintext', () async {
    final bytes = await encrypt('correct horse');
    await expectLater(
      svc.decryptWithPassphrase(bytes, 'wrong horse'),
      throwsA(
        isA<CloudFailure>().having(
          (e) => e.kind,
          'kind',
          CloudFailureKind.incorrectPassphrase,
        ),
      ),
    );
  });

  test('tampered ciphertext is rejected (auth tag fails)', () async {
    final bytes = await encrypt('correct horse');
    final map =
        Map<String, Object?>.from(jsonDecode(utf8.decode(bytes)) as Map);
    final ct = base64Decode(map['ciphertext']! as String);
    ct[0] = ct[0] ^ 0xFF; // flip a byte
    map['ciphertext'] = base64Encode(ct);
    final tampered = utf8.encode(jsonEncode(map));
    await expectLater(
      svc.decryptWithPassphrase(tampered, 'correct horse'),
      throwsA(
        isA<CloudFailure>().having(
          (e) => e.kind,
          'kind',
          CloudFailureKind.downloadIntegrityMismatch,
        ),
      ),
    );
  });

  test('tampered authenticated metadata (backupId) is rejected', () async {
    final bytes = await encrypt('correct horse', backupId: 'original');
    final map =
        Map<String, Object?>.from(jsonDecode(utf8.decode(bytes)) as Map);
    map['backupId'] = 'swapped'; // authenticated as AAD -> must fail
    final tampered = utf8.encode(jsonEncode(map));
    await expectLater(
      svc.decryptWithPassphrase(tampered, 'correct horse'),
      throwsA(isA<CloudFailure>()),
    );
  });

  test('each encryption uses a unique nonce', () async {
    final key =
        await svc.deriveNewKeyMaterial('correct horse', iterations: iters);
    final a = await svc.encrypt(
        payload: payload, key: key, backupId: 'b', formatVersion: 4);
    final b = await svc.encrypt(
        payload: payload, key: key, backupId: 'b', formatVersion: 4);
    final na = jsonDecode(utf8.decode(a))['nonce'];
    final nb = jsonDecode(utf8.decode(b))['nonce'];
    expect(na, isNot(equals(nb)));
  });

  test('cached DEK decrypts without the passphrase', () async {
    final key =
        await svc.deriveNewKeyMaterial('correct horse', iterations: iters);
    final bytes = await svc.encrypt(
        payload: payload, key: key, backupId: 'b', formatVersion: 4);
    final clear = await svc.decryptWithKey(bytes, key);
    expect(clear, equals(payload));
  });

  test(
      'passphrase change: old ciphertext still decrypts with the NEW passphrase',
      () async {
    final key = await svc.deriveNewKeyMaterial('old pass', iterations: iters);
    final bytes = await svc.encrypt(
        payload: payload, key: key, backupId: 'b', formatVersion: 4);
    final rewrapped = await svc.rewrapForNewPassphrase(
      bytes: bytes,
      oldPassphrase: 'old pass',
      newPassphrase: 'brand new pass',
      iterations: iters,
    );
    // Re-encrypt latest snapshot under the new wrap.
    final reup = await svc.encrypt(
        payload: payload, key: rewrapped, backupId: 'b', formatVersion: 4);
    final clear = await svc.decryptWithPassphrase(reup, 'brand new pass');
    expect(clear, equals(payload));
    // Old passphrase no longer works on the new file.
    await expectLater(
      svc.decryptWithPassphrase(reup, 'old pass'),
      throwsA(isA<CloudFailure>()),
    );
  });

  test('short passphrase is refused', () async {
    await expectLater(
      svc.deriveNewKeyMaterial('short', iterations: iters),
      throwsA(isA<CloudFailure>()),
    );
  });

  test('key material survives a secure-storage JSON round-trip', () async {
    final key =
        await svc.deriveNewKeyMaterial('correct horse', iterations: iters);
    final restored = BackupKeyMaterial.fromSecureJson(key.toSecureJson());
    final bytes = await svc.encrypt(
        payload: payload, key: restored, backupId: 'b', formatVersion: 4);
    expect(await svc.decryptWithKey(bytes, key), equals(payload));
  });
}
