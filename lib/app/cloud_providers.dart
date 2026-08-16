import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/cloud/cloud_gateway.dart';
import '../data/cloud/cloud_metadata_store.dart';
import '../data/cloud/cloud_sync_controller.dart';
import '../data/cloud/cloud_sync_state.dart';
import '../data/cloud/cloud_stores.dart';
import '../data/cloud/encryption_service.dart';
import '../data/cloud/google_drive_gateway.dart';
import '../data/cloud/mutation_tracker.dart';
import '../data/snapshot/snapshot_registry.dart';
import 'feature_providers.dart';
import 'providers.dart';

/// Cloud backup provider graph (Phases 5 to 9).
///
/// Nothing here authenticates or touches the network until the user opts in via
/// the controller's `beginLink`. The controller is created lazily and, once the
/// container is alive, subscribes to database writes so every committed
/// user-data mutation marks the backup pending (Phase 7) - with zero cost while
/// cloud backup is disabled (markDirty returns immediately when off).

/// Resolved SharedPreferences, overridden in `main()` after it is loaded.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (_) => throw StateError('sharedPreferencesProvider must be overridden'),
);

final cloudKeyValueStoreProvider = Provider<KeyValueStore>(
  (ref) => PrefsKeyValueStore(ref.watch(sharedPreferencesProvider)),
);

final secretStoreProvider =
    Provider<SecretStore>((_) => FlutterSecureSecretStore());

final cloudMetadataStoreProvider = Provider<CloudSyncMetadataStore>(
  (ref) => CloudSyncMetadataStore(
    kv: ref.watch(cloudKeyValueStoreProvider),
    secrets: ref.watch(secretStoreProvider),
  ),
);

final mutationTrackerProvider = Provider<BackupMutationTracker>(
  (ref) => BackupMutationTracker(ref.watch(cloudKeyValueStoreProvider)),
);

final encryptionServiceProvider =
    Provider<SnapshotEncryptionService>((_) => SnapshotEncryptionService());

/// OAuth client ids. The Web client id is PUBLIC (not a secret), so it is baked
/// in as the default and can still be overridden at build time:
///   --dart-define=GOOGLE_SERVER_CLIENT_ID=xxxx.apps.googleusercontent.com
/// A client SECRET is never embedded. See docs/backup/GOOGLE_DRIVE_SETUP.md.
const String _serverClientId = String.fromEnvironment(
  'GOOGLE_SERVER_CLIENT_ID',
  defaultValue:
      '402518914819-s6ln0i73pg034ggs6km93ou8lng5mlsf.apps.googleusercontent.com',
);
const String _oauthClientId = String.fromEnvironment('GOOGLE_OAUTH_CLIENT_ID');

final cloudAuthGatewayProvider = Provider<GoogleDriveAuthGateway>(
  (_) => GoogleDriveAuthGateway(
    serverClientId: _serverClientId.isEmpty ? null : _serverClientId,
    clientId: _oauthClientId.isEmpty ? null : _oauthClientId,
  ),
);

final cloudBackupGatewayProvider = Provider<CloudBackupGateway>(
  (ref) => GoogleDriveBackupGateway(ref.watch(cloudAuthGatewayProvider)),
);

final backgroundSyncSchedulerProvider = Provider<BackgroundSyncScheduler>(
  // Default: no-op. Foreground sync (debounced, plus retry on app
  // start/resume, manual "Back up now", and after reauth) is fully functional.
  // True OS-scheduled background upload requires adding a Flutter-3.44-compatible
  // WorkManager plugin and wiring the reference implementation in
  // docs/backup/reference/background/. See CLOUD_SYNC_ARCHITECTURE.md.
  (_) => const NoopBackgroundSyncScheduler(),
);

/// The cloud sync controller. Listeners (the settings UI) rebuild via
/// [ListenableBuilder].
final cloudSyncControllerProvider = Provider<CloudSyncController>((ref) {
  final controller = CloudSyncController(
    snapshot: ref.watch(snapshotServiceProvider),
    encryption: ref.watch(encryptionServiceProvider),
    auth: ref.watch(cloudAuthGatewayProvider),
    gateway: ref.watch(cloudBackupGatewayProvider),
    metadata: ref.watch(cloudMetadataStoreProvider),
    tracker: ref.watch(mutationTrackerProvider),
    scheduler: ref.watch(backgroundSyncSchedulerProvider),
  );

  // Phase 7: connect mutation tracking at the centralized persistence boundary.
  // Any write to an included table marks the backup pending. This cannot be
  // bypassed by any UI code path. Excluded tables (import_ledger) are ignored.
  final db = ref.watch(databaseProvider);
  final included = kTablePolicies.entries
      .where((e) => e.value == TablePolicy.included)
      .map((e) => e.key)
      .toSet();
  final sub = db.tableUpdates().listen((updates) {
    final touchesUserData = updates.any((u) => included.contains(u.table));
    if (touchesUserData) controller.markDirty();
  });

  ref.onDispose(() {
    sub.cancel();
    controller.dispose();
  });
  return controller;
});
