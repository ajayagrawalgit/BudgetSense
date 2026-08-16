import 'dart:convert';

import 'package:budgetsense/data/cloud/cloud_failure.dart';
import 'package:budgetsense/data/cloud/encryption_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Security regression tests for parsing an UNTRUSTED encrypted backup file.
///
/// A `.bsbak` can arrive from Google Drive or from the file picker, so the
/// envelope parser is an attacker-reachable surface. These tests pin two
/// properties: a hostile file cannot force unbounded key derivation, and a
/// malformed file fails as a typed CloudFailure rather than crashing the
/// restore with a raw cast error.
void main() {
  final service = SnapshotEncryptionService();

  /// A structurally valid envelope whose fields can be individually corrupted.
  Map<String, Object?> envelope({Object? iterations = 210000}) => {
        'bsbak': 1,
        'product': 'BudgetSense',
        'cipher': 'AES-256-GCM',
        'kdf': 'PBKDF2-HMAC-SHA256',
        'iterations': iterations,
        'salt': base64Encode(List<int>.filled(16, 1)),
        'wrappedKey': base64Encode(List<int>.filled(32, 2)),
        'wrapNonce': base64Encode(List<int>.filled(12, 3)),
        'wrapMac': base64Encode(List<int>.filled(16, 4)),
        'nonce': base64Encode(List<int>.filled(12, 5)),
        'ciphertext': base64Encode(List<int>.filled(32, 6)),
        'mac': base64Encode(List<int>.filled(16, 7)),
        'backupId': 'test-backup',
        'formatVersion': 3,
        'createdAt': DateTime.utc(2026).toIso8601String(),
      };

  List<int> bytesOf(Map<String, Object?> m) => utf8.encode(jsonEncode(m));

  group('PBKDF2 iteration bounds', () {
    test('rejects an iteration count high enough to hang the app', () async {
      // Without a ceiling this derivation would run effectively forever on the
      // restore path, before the user has any chance to cancel.
      await expectLater(
        service.decryptWithPassphrase(
          bytesOf(envelope(iterations: 2000000000)),
          'correct horse battery staple',
        ),
        throwsA(isA<CloudFailure>()),
      );
    });

    test('rejects a downgraded iteration count', () async {
      // A trivially low count would make the wrapped key cheap to brute force.
      await expectLater(
        service.decryptWithPassphrase(
          bytesOf(envelope(iterations: 1)),
          'correct horse battery staple',
        ),
        throwsA(isA<CloudFailure>()),
      );
    });

    test('rejects a missing or non-numeric iteration count', () async {
      for (final bad in <Object?>[null, 'many']) {
        await expectLater(
          service.decryptWithPassphrase(
            bytesOf(envelope(iterations: bad)),
            'correct horse battery staple',
          ),
          throwsA(isA<CloudFailure>()),
        );
      }
    });
  });

  group('malformed envelope handling', () {
    test('a missing field fails as CloudFailure, not a raw cast error',
        () async {
      final broken = envelope()..remove('salt');
      await expectLater(
        service.decryptWithPassphrase(bytesOf(broken), 'passphrase123'),
        throwsA(isA<CloudFailure>()),
      );
    });

    test('a non-string field fails as CloudFailure', () async {
      final broken = envelope()..['ciphertext'] = 12345;
      await expectLater(
        service.decryptWithPassphrase(bytesOf(broken), 'passphrase123'),
        throwsA(isA<CloudFailure>()),
      );
    });

    test('invalid base64 fails as CloudFailure', () async {
      final broken = envelope()..['nonce'] = 'not!valid!base64!';
      await expectLater(
        service.decryptWithPassphrase(bytesOf(broken), 'passphrase123'),
        throwsA(isA<CloudFailure>()),
      );
    });

    test('a foreign file is rejected outright', () async {
      await expectLater(
        service.decryptWithPassphrase(
          utf8.encode('{"product":"SomethingElse"}'),
          'passphrase123',
        ),
        throwsA(isA<CloudFailure>()),
      );
    });
  });

  group('round trip still works', () {
    test('a genuine backup encrypts and decrypts with the right passphrase',
        () async {
      // Proves the hardening did not break the real path. A low-but-accepted
      // iteration count keeps the test fast.
      const passphrase = 'correct horse battery staple';
      final key = await service.deriveNewKeyMaterial(
        passphrase,
        iterations: SnapshotEncryptionService.minAcceptedIterations,
      );
      final payload = utf8.encode('{"transactions":[]}');
      final sealed = await service.encrypt(
        payload: payload,
        key: key,
        backupId: 'round-trip',
        formatVersion: 3,
      );

      final opened = await service.decryptWithPassphrase(sealed, passphrase);
      expect(utf8.decode(opened), '{"transactions":[]}');
    });

    test('the wrong passphrase is rejected', () async {
      const passphrase = 'correct horse battery staple';
      final key = await service.deriveNewKeyMaterial(
        passphrase,
        iterations: SnapshotEncryptionService.minAcceptedIterations,
      );
      final sealed = await service.encrypt(
        payload: utf8.encode('secret'),
        key: key,
        backupId: 'round-trip',
        formatVersion: 3,
      );

      await expectLater(
        service.decryptWithPassphrase(sealed, 'wrong passphrase entirely'),
        throwsA(isA<CloudFailure>()),
      );
    });
  });
}
