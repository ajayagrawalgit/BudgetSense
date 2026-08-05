import 'package:budgetsense/data/cloud/cloud_metadata_store.dart';
import 'package:budgetsense/data/cloud/cloud_stores.dart';
import 'package:budgetsense/data/cloud/encryption_service.dart';
import 'package:budgetsense/data/cloud/mutation_tracker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_cloud.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PrefsKeyValueStore', () {
    test('reads and writes strings, ints, bools with the prefix', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = PrefsKeyValueStore(prefs);
      expect(store.getString('a'), isNull);
      await store.setString('a', 'hi');
      await store.setInt('b', 7);
      await store.setBool('c', true);
      expect(store.getString('a'), 'hi');
      expect(store.getInt('b'), 7);
      expect(store.getBool('c'), isTrue);
      await store.remove('a');
      expect(store.getString('a'), isNull);
    });
  });
  group('BackupMutationTracker', () {
    test('starts clean, marks dirty, and clears on validated upload', () async {
      final kv = InMemoryKeyValueStore();
      final t = BackupMutationTracker(kv);
      expect(t.isPending, isFalse);

      final g1 = await t.markDirty();
      final g2 = await t.markDirty();
      expect(g2, g1 + 1);
      expect(t.isPending, isTrue);

      // Uploading an OLDER generation does not clear a newer pending one.
      await t.markUploaded(g1);
      expect(t.isPending, isTrue);

      await t.markUploaded(g2);
      expect(t.isPending, isFalse);
    });

    test('pending survives a fresh tracker over the same store', () async {
      final kv = InMemoryKeyValueStore();
      await BackupMutationTracker(kv).markDirty();
      expect(BackupMutationTracker(kv).isPending, isTrue);
    });

    test('markUploaded never regresses the uploaded generation', () async {
      final kv = InMemoryKeyValueStore();
      final t = BackupMutationTracker(kv);
      await t.markDirty();
      await t.markDirty();
      await t.markUploaded(2);
      await t.markUploaded(1); // stale, ignored
      expect(t.lastUploadedGeneration, 2);
    });
  });

  group('CloudSyncMetadataStore', () {
    test('records account, folder, file, upload, and clears link', () async {
      final kv = InMemoryKeyValueStore();
      final secrets = InMemorySecretStore();
      final m = CloudSyncMetadataStore(kv: kv, secrets: secrets);
      expect(m.enabled, isFalse);

      await m.setAccount('acc-1', 'me@x.co');
      await m.setFolder('folder-1');
      await m.setFile('file-1');
      await m.setEnabled(true);
      await m.setCloudBackupId('bk-1');
      expect(m.isBoundTo('acc-1'), isTrue);
      expect(m.isBoundTo('acc-2'), isFalse);

      await m.recordUpload(
        remoteVersion: 3,
        payloadDigest: 'd',
        uploadedGeneration: 5,
        at: DateTime(2026, 1, 2),
      );
      expect(m.lastRemoteVersion, 3);
      expect(m.lastUploadedGeneration, 5);
      expect(m.lastSyncAt, DateTime(2026, 1, 2));

      await m.clearLink();
      expect(m.accountId, isNull);
      expect(m.folderId, isNull);
      expect(m.enabled, isFalse);
    });

    test('key material round-trips through the secret store', () async {
      final kv = InMemoryKeyValueStore();
      final secrets = InMemorySecretStore();
      final m = CloudSyncMetadataStore(kv: kv, secrets: secrets);
      final key = await SnapshotEncryptionService()
          .deriveNewKeyMaterial('correct horse', iterations: 1000);
      await m.writeKeyMaterial(key);
      final read = await m.readKeyMaterial();
      expect(read, isNotNull);
      expect(read!.dek, key.dek);
      // clearLink wipes secret material too.
      await m.clearLink();
      expect(await m.readKeyMaterial(), isNull);
    });
  });
}
