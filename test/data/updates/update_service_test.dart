import 'dart:io';

import 'package:budgetsense/data/updates/apk_installer.dart';
import 'package:budgetsense/data/updates/update_manifest.dart';
import 'package:budgetsense/data/updates/update_service.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_cloud.dart';
import '../../support/fake_updates.dart';

String _hex(List<int> b) =>
    b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

Future<String> _sha256Hex(List<int> bytes) async =>
    _hex((await Sha256().hash(bytes)).bytes);

UpdateService _service(
  FakeUpdateGateway gw,
  FakeApkInstaller inst,
  InMemoryKeyValueStore kv, {
  int current = 1,
  required String dir,
}) =>
    UpdateService(
      gateway: gw,
      installer: inst,
      store: kv,
      currentVersionCode: () async => current,
      downloadDirectory: () async => dir,
    );

void main() {
  group('UpdateManifest', () {
    final good = {
      'versionCode': 3,
      'versionName': '0.2.0',
      'apkUrl': 'https://example.com/app.apk',
      'sha256': 'a' * 64,
      'notes': 'nice',
    };

    test('parses a valid manifest', () {
      final m = UpdateManifest.fromJson(good);
      expect(m.versionCode, 3);
      expect(m.isNewerThan(2), isTrue);
      expect(m.isNewerThan(3), isFalse);
    });

    test('rejects bad version, url, and hash', () {
      expect(() => UpdateManifest.fromJson({...good, 'versionCode': 0}),
          throwsFormatException);
      expect(() => UpdateManifest.fromJson({...good, 'apkUrl': 'http://x'}),
          throwsFormatException);
      expect(() => UpdateManifest.fromJson({...good, 'sha256': 'xyz'}),
          throwsFormatException);
      expect(() => UpdateManifest.fromJson({...good, 'versionName': ''}),
          throwsFormatException);
    });
  });

  group('UpdateService', () {
    late Directory tmp;
    setUp(() async => tmp = await Directory.systemTemp.createTemp('bs_upd'));
    tearDown(() async {
      if (tmp.existsSync()) await tmp.delete(recursive: true);
    });

    UpdateManifest manifestFor(String sha, {int code = 3}) => UpdateManifest(
          versionCode: code,
          versionName: '0.2.0',
          apkUrl: 'https://example.com/app.apk',
          sha256: sha,
        );

    test('no newer version -> upToDate, nothing offered', () async {
      final gw = FakeUpdateGateway(manifest: manifestFor('a' * 64, code: 1));
      final s = _service(gw, FakeApkInstaller(), InMemoryKeyValueStore(),
          current: 1, dir: tmp.path);
      await s.checkForUpdate();
      expect(s.state.status, UpdateStatus.upToDate);
      expect(s.state.hasUpdate, isFalse);
    });

    test('newer version -> available', () async {
      final gw = FakeUpdateGateway(manifest: manifestFor('a' * 64));
      final s = _service(gw, FakeApkInstaller(), InMemoryKeyValueStore(),
          current: 1, dir: tmp.path);
      await s.checkForUpdate();
      expect(s.state.status, UpdateStatus.available);
      expect(s.state.manifest?.versionName, '0.2.0');
    });

    test('dismissed version stays silent on the next silent check', () async {
      final gw = FakeUpdateGateway(manifest: manifestFor('a' * 64));
      final kv = InMemoryKeyValueStore();
      final s = _service(gw, FakeApkInstaller(), kv, current: 1, dir: tmp.path);
      await s.checkForUpdate();
      await s.dismiss();
      expect(s.state.status, UpdateStatus.idle);
      // A fresh silent check does not resurface the same version.
      final s2 =
          _service(gw, FakeApkInstaller(), kv, current: 1, dir: tmp.path);
      await s2.checkForUpdate();
      expect(s2.state.hasUpdate, isFalse);
    });

    test('offline check never throws and never disrupts', () async {
      final gw = FakeUpdateGateway()..throwOnFetch = true;
      final s = _service(gw, FakeApkInstaller(), InMemoryKeyValueStore(),
          current: 1, dir: tmp.path);
      await s.checkForUpdate(); // silent
      expect(s.state.hasUpdate, isFalse);
      expect(s.state.message, isNull); // silent: no scary message
    });

    test('valid download verifies and launches the installer', () async {
      final bytes = [10, 20, 30, 40, 50];
      final sha = await _sha256Hex(bytes);
      final gw = FakeUpdateGateway(manifest: manifestFor(sha), apkBytes: bytes);
      final inst = FakeApkInstaller(allowed: true);
      final s = _service(gw, inst, InMemoryKeyValueStore(),
          current: 1, dir: tmp.path);
      await s.checkForUpdate();
      await s.downloadAndInstall();
      expect(inst.installCalls, 1);
      expect(inst.lastPath, contains('BudgetSense-0.2.0.apk'));
    });

    test('CORRUPT download fails the hash check and never installs', () async {
      // Manifest claims a hash that will not match the downloaded bytes.
      final gw = FakeUpdateGateway(
        manifest: manifestFor('b' * 64),
        apkBytes: [1, 2, 3],
      );
      final inst = FakeApkInstaller(allowed: true);
      final s = _service(gw, inst, InMemoryKeyValueStore(),
          current: 1, dir: tmp.path);
      await s.checkForUpdate();
      await s.downloadAndInstall();
      expect(inst.installCalls, 0); // never handed to the installer
      expect(s.state.status, UpdateStatus.error);
      // The unsafe file is discarded.
      expect(File('${tmp.path}/BudgetSense-0.2.0.apk').existsSync(), isFalse);
    });

    test('missing install permission routes the user and does not fail hard',
        () async {
      final bytes = [7, 7, 7];
      final sha = await _sha256Hex(bytes);
      final gw = FakeUpdateGateway(manifest: manifestFor(sha), apkBytes: bytes);
      final inst = FakeApkInstaller(
          allowed: false, outcome: InstallOutcome.needsPermission);
      final s = _service(gw, inst, InMemoryKeyValueStore(),
          current: 1, dir: tmp.path);
      await s.checkForUpdate();
      await s.downloadAndInstall();
      expect(s.state.message, contains('allow BudgetSense to install'));
    });
  });
}
