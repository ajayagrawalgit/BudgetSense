import 'dart:io';

import 'package:budgetsense/app/cloud_providers.dart';
import 'package:budgetsense/app/feature_providers.dart';
import 'package:budgetsense/app/providers.dart';
import 'package:budgetsense/core/theme/app_colors.dart';
import 'package:budgetsense/core/theme/app_theme.dart';
import 'package:budgetsense/data/cloud/cloud_constants.dart';
import 'package:budgetsense/data/cloud/cloud_metadata_store.dart';
import 'package:budgetsense/data/cloud/cloud_sync_controller.dart';
import 'package:budgetsense/data/cloud/encryption_service.dart';
import 'package:budgetsense/data/cloud/mutation_tracker.dart';
import 'package:budgetsense/data/database/app_database.dart';
import 'package:budgetsense/data/snapshot/app_snapshot_service.dart';
import 'package:budgetsense/data/snapshot/snapshot_codecs.dart';
import 'package:budgetsense/domain/services/snapshot_service.dart';
import 'package:budgetsense/features/settings/backup_screen.dart';
import 'package:budgetsense/features/settings/settings_state.dart';
import 'package:drift/drift.dart' show Value;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_cloud.dart';
import '../../support/test_database.dart';

/// Behavioural tests for the Backup and restore screen.
///
/// The promises this screen makes to the user are: the file it writes really can
/// be restored later, and a restore never happens behind their back. Both are
/// checked end to end here: the exported file is read back off disk and pushed
/// through the snapshot service into an empty database, and the restore flow is
/// inspected before and after the confirmation dialog.

/// Wraps the real snapshot service so a test can see exactly what the screen
/// asked it to do, without changing what it does.
class _RecordingSnapshotService implements SnapshotService {
  _RecordingSnapshotService(this._inner);

  final SnapshotService _inner;

  final List<SnapshotExport> exports = [];
  int importCalls = 0;
  int previewCalls = 0;

  @override
  Future<SnapshotExport> export(SnapshotFormat format) async {
    final export = await _inner.export(format);
    exports.add(export);
    return export;
  }

  @override
  Future<SnapshotImportResult> importBytes(
    List<int> bytes, {
    Set<String>? applySettingKeys,
  }) {
    importCalls++;
    return _inner.importBytes(bytes, applySettingKeys: applySettingKeys);
  }

  @override
  Future<RestorePreview> preview(List<int> bytes) {
    previewCalls++;
    return _inner.preview(bytes);
  }
}

/// A file picker that never opens a real dialog and counts how often it was
/// asked, so a test can prove the screen did not go looking for a file before
/// the user agreed to a restore.
class _FakeFilePicker extends FilePicker {
  _FakeFilePicker({this.pickedBytes, this.pickedName = 'backup.json'});

  final List<int>? pickedBytes;
  final String pickedName;

  int pickCalls = 0;
  bool? askedForData;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    dynamic Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = true,
    int compressionQuality = 30,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async {
    pickCalls++;
    askedForData = withData;
    final bytes = pickedBytes;
    if (bytes == null) return null;
    return FilePickerResult([
      PlatformFile(
        name: pickedName,
        size: bytes.length,
        bytes: Uint8List.fromList(bytes),
      ),
    ]);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Where the app believes the user's documents live. Local backups land in a
  /// `BudgetSense_Backup` folder inside it.
  late Directory documents;

  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  /// A settings blob with a few deliberately non-default values, so a restore
  /// that quietly dropped the settings half of the snapshot would be caught.
  Map<String, Object?> exportedSettings() => const SettingsState(
        userName: 'Ajay',
        themeVariant: AppThemeVariant.dark,
        numberFormatCompact: true,
      ).toMap();

  /// Two records the user would notice going missing.
  Future<void> seedRecords(
    AppDatabase db, {
    DateTime? spentAt,
  }) async {
    final stamp = DateTime.utc(2026, 5, 20, 10, 30);
    await db.into(db.categories).insert(
          CategoriesCompanion.insert(
            id: 'cat-1',
            createdAt: stamp,
            updatedAt: stamp,
            name: 'Groceries',
            colorValue: 0xFF7E97A6,
            iconCodePoint: 0xe000,
          ),
        );
    await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            id: 'txn-1',
            createdAt: stamp,
            updatedAt: stamp,
            type: 0,
            name: 'Chai',
            amountMinor: 2500,
            occurredAt: spentAt ?? DateTime(2026, 5, 20, 8, 0),
            categoryId: const Value('cat-1'),
          ),
        );
  }

  _RecordingSnapshotService recordingService(AppDatabase db) =>
      _RecordingSnapshotService(
        AppSnapshotService(
          db,
          appVersion: 'test',
          readSettings: () async => exportedSettings(),
          writeSettings: (_) async {},
        ),
      );

  CloudSyncController cloudController(AppDatabase db) {
    final kv = InMemoryKeyValueStore();
    return CloudSyncController(
      snapshot: AppSnapshotService(
        db,
        readSettings: () async => const {},
        writeSettings: (_) async {},
      ),
      encryption: SnapshotEncryptionService(),
      auth: FakeAuthGateway(),
      gateway: FakeDriveGateway(),
      metadata: CloudSyncMetadataStore(kv: kv, secrets: InMemorySecretStore()),
      tracker: BackupMutationTracker(kv),
    );
  }

  /// Drops one known, pre-existing framework warning so it cannot drown out a
  /// real failure. `CalmCard` paints its own background over the nearest
  /// `Material`, so Flutter reports (in debug builds only) that the ink splash
  /// of any `ListTile` inside it will be invisible. That is cosmetic and is not
  /// what these tests are about. Every other error still fails the test, and the
  /// test binding reinstalls its own handler when the test ends.
  void ignoreCardedListTileInkWarning() {
    final reportToTest = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details
          .exceptionAsString()
          .contains('ink splashes may be invisible')) {
        return;
      }
      reportToTest?.call(details);
    };
  }

  Future<void> pumpScreen(
    WidgetTester tester, {
    required AppDatabase db,
    required SnapshotService snapshots,
  }) async {
    ignoreCardedListTileInkWarning();
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final cloud = cloudController(db);
    // Registered before the widget is pumped, so at teardown (LIFO) the screen
    // is torn down first and its drift subscriptions are cancelled before the
    // controller goes away.
    addTearDown(cloud.dispose);
    final colors = AppColors.light(const Color(0xFFB07C5E));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          snapshotServiceProvider.overrideWithValue(snapshots),
          cloudSyncControllerProvider.overrideWithValue(cloud),
        ],
        child: MaterialApp(
          theme: AppThemeBuilder.build(colors, brightness: Brightness.light),
          home: const BackupScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  /// Lets the screen's real disk work finish. The widget tree runs on fake
  /// async while a file write only completes on the real event loop, so the two
  /// have to take turns: `pump` hands the widget its continuations, `runAsync`
  /// lets the pending disk operation actually run.
  Future<void> settleDiskWork(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.pump();
      await tester.runAsync<void>(() async {
        await pumpEventQueue(times: 5);
      });
    }
    await tester.pump();
  }

  /// Every file the app wrote into the backup folder.
  List<File> writtenBackups() {
    final dir = Directory(
      '${documents.path}/${CloudBackupConstants.folderName}',
    );
    if (!dir.existsSync()) return const [];
    return dir.listSync().whereType<File>().toList();
  }

  setUp(() {
    documents = Directory.systemTemp.createTempSync('budgetsense_backup_test');
    addTearDown(() {
      if (documents.existsSync()) documents.deleteSync(recursive: true);
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
      if (call.method == 'getApplicationDocumentsDirectory') {
        return documents.path;
      }
      return null;
    });
    // Haptics fire when a backup lands; answer the channel so the feedback call
    // is not a missing plugin.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            SystemChannels.platform, (call) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      ..setMockMethodCallHandler(pathProviderChannel, null)
      ..setMockMethodCallHandler(SystemChannels.platform, null);
  });

  group('creating a backup', () {
    for (final format in SnapshotFormat.values) {
      testWidgets(
          'the ${format.label} file it saves really restores into an empty app',
          (tester) async {
        final db = newTestDatabase();
        await seedRecords(db);
        final snapshots = recordingService(db);
        await pumpScreen(tester, db: db, snapshots: snapshots);

        await tap(tester, find.widgetWithText(ChoiceChip, format.label));
        // The button names the format the user picked, so there is no doubt
        // about what is about to be written.
        expect(find.text('Create ${format.label} backup'), findsOneWidget);

        await tester.tap(find.text('Create ${format.label} backup'));
        await settleDiskWork(tester);

        // The screen reports success rather than still spinning.
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(
          find.textContaining('Saved 2 records and'),
          findsOneWidget,
          reason: 'the category and the transaction were both captured',
        );
        expect(
          find.textContaining('as ${format.label} to your '
              '${CloudBackupConstants.folderName} folder'),
          findsOneWidget,
        );

        // Exactly one file, in the fixed folder, and the path the user is shown
        // is the file that actually exists.
        final saved = writtenBackups();
        expect(saved, hasLength(1));
        expect(saved.single.path, endsWith('.${format.ext}'));
        expect(
          tester.widget<SelectableText>(find.byType(SelectableText)).data,
          saved.single.path,
        );

        // The real test: read the bytes back off disk and restore them into a
        // brand new, empty app.
        final bytes = saved.single.readAsBytesSync();
        expect(bytes, isNotEmpty);
        expect(SnapshotCodecs.detectFormat(bytes), format);

        final restoreDb = newTestDatabase();
        Map<String, Object?>? restoredSettings;
        final result = await AppSnapshotService(
          restoreDb,
          readSettings: () async => const SettingsState().toMap(),
          writeSettings: (s) async => restoredSettings = s,
        ).importBytes(bytes);

        expect(result.format, format);
        expect(result.totalRows, 2);
        final transactions =
            await restoreDb.select(restoreDb.transactions).get();
        expect(transactions.single.name, 'Chai');
        expect(transactions.single.amountMinor, 2500);
        expect(transactions.single.categoryId, 'cat-1');
        final categories = await restoreDb.select(restoreDb.categories).get();
        expect(categories.single.name, 'Groceries');
        // "A complete backup" includes the settings, not just the rows.
        expect(restoredSettings?['userName'], 'Ajay');
        expect(restoredSettings?['themeVariant'], 'dark');
        expect(restoredSettings?['numberFormatCompact'], true);

        await closeTestDatabase(tester, db);
        await closeTestDatabase(tester, restoreDb);
      });
    }

    testWidgets('a second backup is written alongside the first, never over it',
        (tester) async {
      final db = newTestDatabase();
      await seedRecords(db);
      final snapshots = recordingService(db);
      await pumpScreen(tester, db: db, snapshots: snapshots);

      await tester.tap(find.text('Create JSON backup'));
      await settleDiskWork(tester);
      await tap(tester, find.widgetWithText(ChoiceChip, 'XML'));
      await tester.tap(find.text('Create XML backup'));
      await settleDiskWork(tester);

      final saved = writtenBackups().map((f) => f.path).toList();
      expect(saved, hasLength(2));
      expect(saved.where((p) => p.endsWith('.json')), hasLength(1));
      expect(saved.where((p) => p.endsWith('.xml')), hasLength(1));
      // Both formats were asked of the snapshot service, in the order chosen.
      expect(
        snapshots.exports.map((e) => e.format),
        [SnapshotFormat.json, SnapshotFormat.xml],
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await closeTestDatabase(tester, db);
    });
  });

  group('restoring from a file', () {
    /// A backup file holding one transaction the screen's database has never
    /// seen, dated in a month nobody is looking at.
    Future<List<int>> foreignBackup() async {
      final source = newTestDatabase();
      await seedRecords(source, spentAt: DateTime(2026, 2, 14, 19, 30));
      final export = await AppSnapshotService(
        source,
        appVersion: 'test',
        readSettings: () async => exportedSettings(),
        writeSettings: (_) async {},
      ).export(SnapshotFormat.json);
      // Nothing ever watched this database, so it closes without needing a
      // pump to drain drift's stream-cancellation timer.
      await source.close();
      return export.bytes;
    }

    testWidgets('it asks before reading anything, and a cancel changes nothing',
        (tester) async {
      final db = newTestDatabase();
      await seedRecords(db);
      final before = await db.select(db.transactions).get();

      final picker = _FakeFilePicker(pickedBytes: await foreignBackup());
      FilePicker.platform = picker;
      final snapshots = recordingService(db);
      await pumpScreen(tester, db: db, snapshots: snapshots);

      await tap(tester, find.text('Restore from file'));

      // The question is on screen and the promises it makes are spelled out.
      expect(find.text('Restore from a backup?'), findsOneWidget);
      expect(
        find.textContaining(
            'existing records are never deleted or overwritten'),
        findsOneWidget,
      );
      // Nothing has been opened or read at this point. This is the whole point
      // of the dialog: no file is touched until the user says yes.
      expect(picker.pickCalls, 0);
      expect(snapshots.importCalls, 0);

      await tap(tester, find.text('Cancel'));

      expect(picker.pickCalls, 0);
      expect(snapshots.importCalls, 0);
      // The database is byte-for-byte what it was, and the screen makes no
      // claim about a restore that never ran.
      final after = await db.select(db.transactions).get();
      expect(after, equals(before));
      expect(await db.select(db.categories).get(), hasLength(1));
      expect(find.textContaining('Added'), findsNothing);
      expect(find.byIcon(Icons.check_circle_outline), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await closeTestDatabase(tester, db);
    });

    testWidgets(
        'confirming adds the backed-up records and brings them into '
        'view', (tester) async {
      final db = newTestDatabase();
      final picker = _FakeFilePicker(pickedBytes: await foreignBackup());
      FilePicker.platform = picker;
      final snapshots = recordingService(db);
      await pumpScreen(tester, db: db, snapshots: snapshots);

      await tap(tester, find.text('Restore from file'));
      await tap(tester, find.text('Restore'));
      await settleDiskWork(tester);

      expect(picker.pickCalls, 1);
      expect(picker.askedForData, isTrue,
          reason: 'the bytes are needed, not just a path');
      expect(snapshots.importCalls, 1);

      expect(find.textContaining('Added 2 new records'), findsOneWidget);
      expect(
          find.textContaining('Nothing existing was changed'), findsOneWidget);

      final transactions = await db.select(db.transactions).get();
      expect(transactions.single.name, 'Chai');
      expect(transactions.single.amountMinor, 2500);

      // The restored month is put in focus, otherwise the dashboard would look
      // empty and the data would appear to have vanished.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(BackupScreen)),
        listen: false,
      );
      expect(
          container.read(focusedMonthProvider), DateTime(2026, 2, 14, 19, 30));

      await tester.pumpWidget(const SizedBox.shrink());
      await closeTestDatabase(tester, db);
    });

    testWidgets('restoring the same file twice never duplicates a record',
        (tester) async {
      final db = newTestDatabase();
      final picker = _FakeFilePicker(pickedBytes: await foreignBackup());
      FilePicker.platform = picker;
      final snapshots = recordingService(db);
      await pumpScreen(tester, db: db, snapshots: snapshots);

      await tap(tester, find.text('Restore from file'));
      await tap(tester, find.text('Restore'));
      await settleDiskWork(tester);
      await tap(tester, find.text('Restore from file'));
      await tap(tester, find.text('Restore'));
      await settleDiskWork(tester);

      expect(snapshots.importCalls, 2);
      // The second pass adds nothing and says so, exactly as the dialog
      // promised.
      expect(find.textContaining('Added 0 new records'), findsOneWidget);
      expect(
          find.textContaining('2 already present (skipped)'), findsOneWidget);
      expect(await db.select(db.transactions).get(), hasLength(1));
      expect(await db.select(db.categories).get(), hasLength(1));

      await tester.pumpWidget(const SizedBox.shrink());
      await closeTestDatabase(tester, db);
    });

    testWidgets('backing out of the file picker leaves the screen untouched',
        (tester) async {
      final db = newTestDatabase();
      await seedRecords(db);
      final picker = _FakeFilePicker();
      FilePicker.platform = picker;
      final snapshots = recordingService(db);
      await pumpScreen(tester, db: db, snapshots: snapshots);

      await tap(tester, find.text('Restore from file'));
      await tap(tester, find.text('Restore'));
      await settleDiskWork(tester);

      // The user agreed, then closed the picker without choosing a file.
      expect(picker.pickCalls, 1);
      expect(snapshots.importCalls, 0);
      expect(await db.select(db.transactions).get(), hasLength(1));
      expect(find.textContaining('Added'), findsNothing);
      expect(find.textContaining('Could not read'), findsNothing);
      // And the screen is usable again rather than stuck on the spinner.
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Restore from file'),
            )
            .onPressed,
        isNotNull,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await closeTestDatabase(tester, db);
    });

    testWidgets('a file that is not a backup is refused, and says why',
        (tester) async {
      final db = newTestDatabase();
      await seedRecords(db);
      final picker = _FakeFilePicker(
        pickedBytes: 'just some notes I keep'.codeUnits,
        pickedName: 'notes.txt',
      );
      FilePicker.platform = picker;
      final snapshots = recordingService(db);
      await pumpScreen(tester, db: db, snapshots: snapshots);

      await tap(tester, find.text('Restore from file'));
      await tap(tester, find.text('Restore'));
      await settleDiskWork(tester);

      expect(snapshots.importCalls, 1);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.textContaining('Added'), findsNothing);
      // The user's own data is still there after a failed restore.
      expect(await db.select(db.transactions).get(), hasLength(1));
      expect(await db.select(db.categories).get(), hasLength(1));

      await tester.pumpWidget(const SizedBox.shrink());
      await closeTestDatabase(tester, db);
    });
  });
}
