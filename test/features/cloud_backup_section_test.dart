import 'package:budgetsense/app/cloud_providers.dart';
import 'package:budgetsense/core/theme/app_colors.dart';
import 'package:budgetsense/core/theme/app_theme.dart';
import 'package:budgetsense/data/cloud/cloud_metadata_store.dart';
import 'package:budgetsense/data/cloud/cloud_sync_controller.dart';
import 'package:budgetsense/data/cloud/encryption_service.dart';
import 'package:budgetsense/data/cloud/mutation_tracker.dart';
import 'package:budgetsense/data/database/app_database.dart';
import 'package:budgetsense/data/snapshot/app_snapshot_service.dart';
import 'package:budgetsense/features/settings/cloud_backup_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_cloud.dart';
import '../support/test_database.dart';

/// Widget tests for the Backup and Sync section (Phase 10/13).

CloudSyncController _controller(AppDatabase db) {
  final kv = InMemoryKeyValueStore();
  final meta = CloudSyncMetadataStore(kv: kv, secrets: InMemorySecretStore());
  final snapshot = AppSnapshotService(
    db,
    readSettings: () async => const {},
    writeSettings: (_) async {},
  );
  return CloudSyncController(
    snapshot: snapshot,
    encryption: SnapshotEncryptionService(),
    auth: FakeAuthGateway(),
    gateway: FakeDriveGateway(),
    metadata: meta,
    tracker: BackupMutationTracker(kv),
  );
}

Widget _host(CloudSyncController c) {
  final colors = AppColors.light(const Color(0xFFB07C5E));
  return ProviderScope(
    overrides: [cloudSyncControllerProvider.overrideWithValue(c)],
    child: MaterialApp(
      theme: AppThemeBuilder.build(colors, brightness: Brightness.light),
      home: const Scaffold(
        body: SingleChildScrollView(child: CloudBackupSection()),
      ),
    ),
  );
}

void main() {
  testWidgets('cloud backup toggle defaults to OFF', (tester) async {
    final db = newTestDatabase();
    addTearDown(db.close);
    final c = _controller(db);
    addTearDown(c.dispose);
    await tester.pumpWidget(_host(c));

    expect(find.text('Backup and Sync to Cloud'), findsOneWidget);
    final sw = tester.widget<Switch>(find.byType(Switch));
    expect(sw.value, isFalse);
    // Disabled: none of the action buttons are shown yet.
    expect(find.text('Back up now'), findsNothing);
    expect(find.text('Restore from Google Drive'), findsNothing);
  });

  testWidgets('turning the toggle on shows the explainer before any network',
      (tester) async {
    final db = newTestDatabase();
    addTearDown(db.close);
    final c = _controller(db);
    addTearDown(c.dispose);
    await tester.pumpWidget(_host(c));

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    // Explainer dialog appears; nothing authenticated yet.
    expect(find.text('Back up to Google Drive'), findsOneWidget);
    expect(find.textContaining('BudgetSense_Backup'), findsOneWidget);
  });
}
