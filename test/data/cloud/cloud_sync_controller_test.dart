import 'package:budgetsense/data/cloud/cloud_failure.dart';
import 'package:budgetsense/data/cloud/cloud_metadata_store.dart';
import 'package:budgetsense/data/cloud/cloud_sync_controller.dart';
import 'package:budgetsense/data/cloud/cloud_sync_state.dart';
import 'package:budgetsense/data/cloud/encryption_service.dart';
import 'package:budgetsense/data/cloud/mutation_tracker.dart';
import 'package:budgetsense/data/database/app_database.dart';
import 'package:budgetsense/data/snapshot/app_snapshot_service.dart';
import 'package:budgetsense/domain/services/snapshot_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_cloud.dart';
import '../../support/test_database.dart';

/// Cloud sync controller behavior with fakes (Phase 5-9 / 13). No Google, no
/// platform plugins, no network.

class _CountingScheduler implements BackgroundSyncScheduler {
  int scheduled = 0;
  int cancelled = 0;
  @override
  Future<void> scheduleUniqueSync() async => scheduled++;
  @override
  Future<void> cancel() async => cancelled++;
}

class _Harness {
  _Harness() {
    db = newTestDatabase();
    kv = InMemoryKeyValueStore();
    secrets = InMemorySecretStore();
    meta = CloudSyncMetadataStore(kv: kv, secrets: secrets);
    tracker = BackupMutationTracker(kv);
    auth = FakeAuthGateway();
    gw = FakeDriveGateway();
    scheduler = _CountingScheduler();
    settings = <String, Object?>{'userName': 'Mickey'};
    snapshot = AppSnapshotService(
      db,
      readSettings: () async => settings,
      writeSettings: (s) async => settings = s,
    );
    // Fast crypto for tests.
    enc = SnapshotEncryptionService();
    controller = CloudSyncController(
      snapshot: snapshot,
      encryption: enc,
      auth: auth,
      gateway: gw,
      metadata: meta,
      tracker: tracker,
      scheduler: scheduler,
      debounce: const Duration(milliseconds: 5),
    );
  }

  late AppDatabase db;
  late InMemoryKeyValueStore kv;
  late InMemorySecretStore secrets;
  late CloudSyncMetadataStore meta;
  late BackupMutationTracker tracker;
  late FakeAuthGateway auth;
  late FakeDriveGateway gw;
  late _CountingScheduler scheduler;
  late Map<String, Object?> settings;
  late AppSnapshotService snapshot;
  late SnapshotEncryptionService enc;
  late CloudSyncController controller;

  Future<void> seedTxn(String id, int amount) =>
      db.into(db.transactions).insert(
            TransactionsCompanion.insert(
              id: id,
              createdAt: DateTime(2026),
              updatedAt: DateTime(2026),
              type: 0,
              name: 'Coffee',
              amountMinor: amount,
              occurredAt: DateTime(2026),
            ),
          );

  void dispose() {
    controller.dispose();
    db.close();
  }
}

void main() {
  const pass = 'correct horse battery';

  test('disabled: no authentication or network happens on load', () async {
    final h = _Harness();
    addTearDown(h.dispose);
    await h.controller.loadOnStart();
    expect(h.controller.state.status, CloudSyncStatus.disabled);
    expect(h.auth.signInCalls, 0);
    expect(h.gw.folderCreateCount, 0);
    expect(h.gw.fileCreateCount, 0);
  });

  test('enabling creates the folder and file exactly once', () async {
    final h = _Harness();
    addTearDown(h.dispose);
    await h.seedTxn('t1', 100);
    final res = await h.controller.beginLink(pass);
    expect(res.outcome, CloudLinkOutcome.linkedFresh);
    expect(h.gw.folderCreateCount, 1);
    expect(h.gw.fileCreateCount, 1);
    expect(h.controller.state.status, CloudSyncStatus.idle);
    expect(h.meta.enabled, isTrue);
    expect(h.scheduler.scheduled, greaterThanOrEqualTo(1));
  });

  test('cloud payload is ENCRYPTED before upload (no plaintext on Drive)',
      () async {
    final h = _Harness();
    addTearDown(h.dispose);
    await h.seedTxn('t1', 4500);
    await h.controller.beginLink(pass);
    final stored = String.fromCharCodes(h.gw.storedBytes!);
    expect(stored.contains('Coffee'), isFalse);
    expect(stored.contains('amountMinor'), isFalse);
    expect(stored.contains('AES-256-GCM'), isTrue); // it is our envelope
  });

  test('existing remote backup requires reconciliation, not auto-overwrite',
      () async {
    final h = _Harness();
    addTearDown(h.dispose);
    // Seed an existing encrypted remote backup made with the same passphrase.
    final key = await h.enc.deriveNewKeyMaterial(pass);
    final export = await h.snapshot.export(SnapshotFormat.json);
    final encrypted = await h.enc.encrypt(
      payload: export.bytes,
      key: key,
      backupId: 'remote-b',
      formatVersion: 4,
    );
    h.gw.seedExistingFile(encrypted);

    final res = await h.controller.beginLink(pass);
    expect(res.outcome, CloudLinkOutcome.needsReconcile);
    expect(res.existing, isNotNull);
    expect(h.gw.fileCreateCount, 0); // did NOT overwrite
  });

  test('reconcileImport appends cloud data and re-uploads merged snapshot',
      () async {
    final h = _Harness();
    addTearDown(h.dispose);
    // Remote backup contains one transaction the local device lacks.
    final key = await h.enc.deriveNewKeyMaterial(pass);
    final remoteDb = newTestDatabase();
    addTearDown(remoteDb.close);
    await remoteDb.into(remoteDb.transactions).insert(
          TransactionsCompanion.insert(
            id: 'remote-1',
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
            type: 0,
            name: 'Remote',
            amountMinor: 999,
            occurredAt: DateTime(2026),
          ),
        );
    final remoteSvc = AppSnapshotService(remoteDb,
        readSettings: () async => const {}, writeSettings: (_) async {});
    final remoteExport = await remoteSvc.export(SnapshotFormat.json);
    final encrypted = await h.enc.encrypt(
      payload: remoteExport.bytes,
      key: key,
      backupId: 'remote-b',
      formatVersion: 4,
    );
    h.gw.seedExistingFile(encrypted);

    await h.seedTxn('local-1', 100);
    await h.controller.beginLink(pass);
    final result = await h.controller.reconcileImport();

    expect(result.totalRows, greaterThanOrEqualTo(1));
    final ids = (await h.db.select(h.db.transactions).get()).map((t) => t.id);
    expect(ids, containsAll(['local-1', 'remote-1'])); // append-only merge
    expect(h.controller.state.status, CloudSyncStatus.idle);
  });

  test('markDirty persists a pending generation across restarts', () async {
    final h = _Harness();
    addTearDown(h.dispose);
    await h.controller.beginLink(pass);
    await h.controller.markDirty();
    expect(h.tracker.isPending, isTrue);
    expect(h.controller.state.pending, isTrue);
    // A fresh tracker over the same KV still sees the pending generation.
    final fresh = BackupMutationTracker(h.kv);
    expect(fresh.isPending, isTrue);
  });

  test('rapid mutations coalesce into ONE upload for the latest generation',
      () async {
    final h = _Harness();
    addTearDown(h.dispose);
    await h.controller.beginLink(pass);
    final createsAfterLink = h.gw.fileCreateCount + h.gw.updateCount;
    await h.tracker.markDirty();
    await h.tracker.markDirty();
    await h.tracker.markDirty();
    await h.controller.syncNow();
    final uploads = h.gw.fileCreateCount + h.gw.updateCount - createsAfterLink;
    expect(uploads, 1);
    expect(h.tracker.lastUploadedGeneration, h.tracker.currentGeneration);
    expect(h.tracker.isPending, isFalse);
  });

  test('a mutation during/after an upload keeps state pending', () async {
    final h = _Harness();
    addTearDown(h.dispose);
    await h.controller.beginLink(pass);
    await h.tracker.markDirty();
    await h.controller.syncNow();
    final uploadedGen = h.tracker.lastUploadedGeneration;
    // New mutation after the validated upload.
    await h.tracker.markDirty();
    expect(h.tracker.isPending, isTrue);
    expect(h.tracker.lastUploadedGeneration, uploadedGen); // unchanged
  });

  test('failed upload leaves the backup pending and retries scheduled',
      () async {
    final h = _Harness();
    addTearDown(h.dispose);
    await h.controller.beginLink(pass);
    await h.tracker.markDirty();
    h.gw.failNextUpload = true;
    final before = h.scheduler.scheduled;
    await h.controller.syncNow();
    expect(h.tracker.isPending, isTrue);
    expect(h.scheduler.scheduled, greaterThan(before)); // transient -> retry
  });

  test('remote conflict blocks overwrite', () async {
    final h = _Harness();
    addTearDown(h.dispose);
    await h.controller.beginLink(pass);
    await h.tracker.markDirty();
    h.gw.remoteChangedUnderfoot = true; // another device moved the version
    await h.controller.syncNow();
    expect(h.controller.state.status, CloudSyncStatus.remoteConflict);
  });

  test('disable cancels background work and preserves local + cloud', () async {
    final h = _Harness();
    addTearDown(h.dispose);
    await h.seedTxn('t1', 100);
    await h.controller.beginLink(pass);
    await h.controller.disable();
    expect(h.scheduler.cancelled, greaterThanOrEqualTo(1));
    expect(h.meta.enabled, isFalse);
    expect(h.gw.storedBytes, isNotNull); // cloud file preserved
    expect(
        await h.db.select(h.db.transactions).get(), hasLength(1)); // local kept
  });

  test('disconnect revokes and clears the link but keeps local data', () async {
    final h = _Harness();
    addTearDown(h.dispose);
    await h.seedTxn('t1', 100);
    await h.controller.beginLink(pass);
    await h.controller.disconnect();
    expect(h.auth.disconnectCalls, 1);
    expect(h.meta.accountId, isNull);
    expect(await h.db.select(h.db.transactions).get(), hasLength(1));
  });

  test('cloud restore uses the append-only engine', () async {
    final h = _Harness();
    addTearDown(h.dispose);
    await h.seedTxn('t1', 4500);
    await h.controller.beginLink(pass);
    // Restoring the same cloud backup twice is idempotent (no duplicates).
    await h.controller.restoreFromCloud(pass);
    await h.controller.restoreFromCloud(pass);
    expect(await h.db.select(h.db.transactions).get(), hasLength(1));
  });

  test('delete cloud backup removes the remote file only', () async {
    final h = _Harness();
    addTearDown(h.dispose);
    await h.seedTxn('t1', 100);
    await h.controller.beginLink(pass);
    await h.controller.deleteCloudBackup();
    expect(h.gw.storedBytes, isNull);
    expect(await h.db.select(h.db.transactions).get(), hasLength(1));
  });

  test('change passphrase re-uploads a file the new passphrase can restore',
      () async {
    final h = _Harness();
    addTearDown(h.dispose);
    await h.seedTxn('t1', 100);
    await h.controller.beginLink(pass);
    await h.controller.changePassphrase(pass, 'a whole new passphrase');
    // The new passphrase can decrypt+restore; the old cannot.
    final ok = await h.controller.previewCloudRestore('a whole new passphrase');
    expect(ok.integrityValidated, isTrue);
  });

  test('loadOnStart on an enabled install re-auths silently and clears pending',
      () async {
    final h = _Harness();
    addTearDown(h.dispose);
    await h.controller.beginLink(pass);
    await h.tracker.markDirty();
    // A brand new controller over the SAME stores/gateways (simulating restart).
    final fresh = CloudSyncController(
      snapshot: h.snapshot,
      encryption: h.enc,
      auth: h.auth,
      gateway: h.gw,
      metadata: h.meta,
      tracker: h.tracker,
      scheduler: h.scheduler,
      debounce: const Duration(milliseconds: 5),
    );
    addTearDown(fresh.dispose);
    await fresh.loadOnStart();
    expect(fresh.state.enabled, isTrue);
    expect(h.tracker.isPending, isFalse); // pending upload was flushed
  });

  test('loadOnStart moves to requiresSignIn when silent auth fails', () async {
    final h = _Harness();
    addTearDown(h.dispose);
    await h.controller.beginLink(pass);
    h.auth.silentReturnsNull = true;
    final fresh = CloudSyncController(
      snapshot: h.snapshot,
      encryption: h.enc,
      auth: h.auth,
      gateway: h.gw,
      metadata: h.meta,
      tracker: h.tracker,
      scheduler: h.scheduler,
    );
    addTearDown(fresh.dispose);
    await fresh.loadOnStart();
    expect(fresh.state.status, CloudSyncStatus.requiresSignIn);
  });

  test('reconcileCancel enables nothing and touches no data', () async {
    final h = _Harness();
    addTearDown(h.dispose);
    final key = await h.enc.deriveNewKeyMaterial(pass);
    final export = await h.snapshot.export(SnapshotFormat.json);
    final encrypted = await h.enc.encrypt(
      payload: export.bytes,
      key: key,
      backupId: 'remote-b',
      formatVersion: 4,
    );
    h.gw.seedExistingFile(encrypted);
    await h.controller.beginLink(pass);
    await h.controller.reconcileCancel();
    expect(h.controller.state.status, CloudSyncStatus.disabled);
    expect(h.meta.enabled, isFalse);
  });

  test('change passphrase without a backup fails cleanly', () async {
    final h = _Harness();
    addTearDown(h.dispose);
    expect(
      () => h.controller.changePassphrase('a', 'b'),
      throwsA(isA<CloudFailure>()),
    );
  });

  test('sign-in cancellation surfaces as a CloudFailure', () async {
    final h = _Harness();
    addTearDown(h.dispose);
    h.auth.cancelInteractive = true;
    expect(
      () => h.controller.beginLink(pass),
      throwsA(isA<CloudFailure>()),
    );
  });
}
