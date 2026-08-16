import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:budgetsense/app/feature_providers.dart';
import 'package:budgetsense/app/providers.dart';
import 'package:budgetsense/core/theme/app_colors.dart';
import 'package:budgetsense/core/theme/app_theme.dart';
import 'package:budgetsense/data/database/app_database.dart';
import 'package:budgetsense/domain/services/import_service.dart';
import 'package:budgetsense/features/settings/import/paisa_import_screen.dart';
import 'package:budgetsense/features/settings/settings_controller.dart';
import 'package:budgetsense/features/settings/settings_state.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/test_database.dart';

/// Behavioural tests for the end-to-end import flow of a single source.
///
/// Two things are stood in for: the OS file dialog (platform glue that cannot
/// run in a test) and the Paisa parser (already covered against a real database
/// by `test/data/paisa_import_test.dart`). What is left is exactly what this
/// screen owns: what the reader is shown before committing, what is asked
/// before personal details are touched, what happens to the answer, and what
/// the reader is told when something goes wrong.

// ---- Test doubles ---------------------------------------------------------

typedef _Inspect = Future<ImportPreview> Function(List<int> bytes);
typedef _Import = Future<ImportOutcome> Function(
  List<int> bytes, {
  required bool importProfile,
});

typedef _InspectCall = ({ImportSource source, List<int> bytes});
typedef _ImportCall = ({
  ImportSource source,
  List<int> bytes,
  bool importProfile,
});

/// A [DataImportService] that records exactly what the screen asked of it, so
/// tests can assert on the arguments (which file, and whether consent for the
/// profile was actually passed through) rather than merely that it was called.
class _FakeImportService implements DataImportService {
  _FakeImportService({required this.onInspect, required this.onImport});

  final _Inspect onInspect;
  final _Import onImport;

  final List<_InspectCall> inspectCalls = <_InspectCall>[];
  final List<_ImportCall> importCalls = <_ImportCall>[];

  @override
  Future<ImportPreview> inspect(ImportSource source, List<int> bytes) {
    inspectCalls.add((source: source, bytes: bytes));
    return onInspect(bytes);
  }

  @override
  Future<ImportOutcome> import(
    ImportSource source,
    List<int> bytes, {
    bool importProfile = true,
  }) {
    importCalls.add(
      (source: source, bytes: bytes, importProfile: importProfile),
    );
    return onImport(bytes, importProfile: importProfile);
  }
}

_Inspect _previews(ImportPreview preview) => (_) async => preview;

_Inspect _inspectFails(Object error) => (_) async => throw error;

/// Returns [outcome], but hands the profile back only when the screen asked
/// for it. That mirrors the real importer, which surfaces no profile at all
/// under `importProfile: false`, so the caller cannot accidentally apply one.
_Import _imports(ImportOutcome outcome) =>
    (_, {required bool importProfile}) async => ImportOutcome(
          source: outcome.source,
          categories: outcome.categories,
          accounts: outcome.accounts,
          transactions: outcome.transactions,
          skippedTransfers: outcome.skippedTransfers,
          failed: outcome.failed,
          warnings: outcome.warnings,
          profile: importProfile ? outcome.profile : null,
        );

/// For flows where writing anything would itself be the bug.
_Import _neverImports() => (_, {required bool importProfile}) async =>
    throw StateError('nothing may be imported in this flow');

typedef _PickRequest = ({
  FileType type,
  List<String>? allowedExtensions,
  bool withData,
});

/// Stands in for the OS file dialog and records what was asked of it. Results
/// are consumed in order, so a test can hand over a different file the second
/// time round; the last entry repeats.
class _StubFilePicker extends FilePicker {
  _StubFilePicker(this._results);

  final List<FilePickerResult?> _results;
  final List<_PickRequest> requests = <_PickRequest>[];
  int _picks = 0;

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
    requests.add(
      (type: type, allowedExtensions: allowedExtensions, withData: withData),
    );
    final result = _results[_picks.clamp(0, _results.length - 1)];
    _picks++;
    return result;
  }
}

_StubFilePicker _installFilePicker(List<FilePickerResult?> results) {
  final picker = _StubFilePicker(results);
  FilePicker.platform = picker;
  return picker;
}

/// Bytes that look like a Paisa export and carry a marker, so a test can tell
/// which file the screen actually handed to the importer.
List<int> _paisaBytes(String marker) =>
    utf8.encode('{"backupVersion":8,"marker":"$marker"}');

FilePickerResult _file(String name, List<int> bytes) => FilePickerResult([
      PlatformFile(
        name: name,
        size: bytes.length,
        bytes: Uint8List.fromList(bytes),
      ),
    ]);

/// A pick the system could not actually deliver: no bytes, and no path to fall
/// back on. Happens with cloud files that fail to materialise.
FilePickerResult _unreadableFile(String name) =>
    FilePickerResult([PlatformFile(name: name, size: 12)]);

// ---- Fixtures -------------------------------------------------------------

ImportPreview _preview({
  int transactions = 42,
  int incomeCount = 12,
  int expenseCount = 30,
  int categories = 9,
  int accounts = 4,
  ImportedProfile? profile,
  List<String> warnings = const [],
}) =>
    ImportPreview(
      source: ImportSource.paisa,
      categories: categories,
      accounts: accounts,
      transactions: transactions,
      incomeCount: incomeCount,
      expenseCount: expenseCount,
      transferCount: 2,
      earliest: DateTime(2023, 1, 5, 8, 30),
      latest: DateTime(2024, 2, 10, 13),
      profile: profile,
      warnings: warnings,
    );

ImportOutcome _outcome({
  int transactions = 40,
  int categories = 9,
  int accounts = 4,
  int skippedTransfers = 2,
  List<String> warnings = const [],
  ImportedProfile? profile,
}) =>
    ImportOutcome(
      source: ImportSource.paisa,
      categories: categories,
      accounts: accounts,
      transactions: transactions,
      skippedTransfers: skippedTransfers,
      warnings: warnings,
      profile: profile,
    );

/// The profile of somebody who has already finished onboarding: a name they
/// typed and a currency they chose. Importing over this needs consent.
const _existingProfile = SettingsState(
  onboardingComplete: true,
  userName: 'Vinita',
  currencyCode: 'INR',
  currencySymbol: '₹',
);

/// The profile detected inside the backup file, which differs from the one the
/// reader already has.
const _backupProfile = ImportedProfile(
  name: 'Someone Else',
  currencyCode: 'USD',
  currencySymbol: r'$',
);

/// Persists [state] before the screen boots, the way a returning user's own
/// settings would already be on disk.
void _seedSettings([SettingsState state = const SettingsState()]) {
  SharedPreferences.setMockInitialValues({
    'budgetsense.settings.v1': jsonEncode(state.toMap()),
  });
}

// ---- Harness --------------------------------------------------------------

/// Drops one known, pre-existing framework warning so it cannot drown out a
/// real failure. `CalmCard` paints its own background over the nearest
/// `Material`, so Flutter reports (in debug builds only) that the ink splash of
/// any `ListTile` inside it will be invisible. That is cosmetic, it is true of
/// every screen that puts a tile inside a card, and it is not what these tests
/// are about. Every other error still fails the test, and the test binding
/// reinstalls its own handler when the test ends. Same treatment as
/// `notification_settings_screen_test.dart` and `backup_screen_test.dart`.
void _ignoreCardedListTileInkWarning() {
  final reportToTest = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exceptionAsString().contains('ink splashes may be invisible')) {
      return;
    }
    reportToTest?.call(details);
  };
}

Future<ProviderContainer> _pumpImportScreen(
  WidgetTester tester, {
  required _FakeImportService service,
  required AppDatabase db,
}) async {
  _ignoreCardedListTileInkWarning();
  // A tall surface so the whole preview (stats, profile switch, warnings and
  // both buttons) is laid out and reachable, the way it is on a real phone.
  tester.view.physicalSize = const Size(1000, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        dataImportServiceProvider.overrideWithValue(service),
      ],
      child: MaterialApp(
        theme: AppThemeBuilder.build(
          AppColors.light(const Color(0xFFB07C5E)),
          brightness: Brightness.light,
        ),
        home: Consumer(
          builder: (context, ref, _) {
            // The real app gates its router on settings having loaded, so this
            // screen never runs against a half-read profile. Mirror that here
            // instead of racing the asynchronous preferences read.
            if (!ref.watch(settingsControllerProvider).hasValue) {
              return const Scaffold(body: SizedBox.shrink());
            }
            return const PaisaImportScreen(source: ImportSource.paisa);
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(
    tester.element(find.byType(PaisaImportScreen)),
    listen: false,
  );
}

Future<void> _tapChooseFile(WidgetTester tester) async {
  await tester.tap(find.text('Choose Paisa backup file'));
  await tester.pumpAndSettle();
}

Future<void> _tapImport(WidgetTester tester, {int transactions = 42}) async {
  await tester.tap(find.text('Import $transactions transactions'));
  await tester.pumpAndSettle();
}

/// The number the screen shows against a labelled row. Reading the value out of
/// the label's own row proves the counts are paired with the right labels, not
/// merely present somewhere on screen.
String _statValue(WidgetTester tester, String label) {
  final row =
      find.ancestor(of: find.text(label), matching: find.byType(Row)).first;
  final texts = tester.widgetList<Text>(
    find.descendant(of: row, matching: find.byType(Text)),
  );
  return texts.last.data!;
}

/// Reads the profile back through a brand new controller, so an assertion
/// proves what the reader would still see after a restart rather than what
/// happens to be in the copy the screen already held in memory.
Future<SettingsState> _persistedSettings() {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  return container.read(settingsControllerProvider.future);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the preview reports what is really in the chosen file',
      (tester) async {
    _seedSettings();
    final db = newTestDatabase();
    closeTestDatabaseOnTearDown(tester, db);
    final bytes = _paisaBytes('first');
    final picker = _installFilePicker([_file('paisa-2024.json', bytes)]);
    final service = _FakeImportService(
      onInspect: _previews(_preview()),
      onImport: _neverImports(),
    );

    await _pumpImportScreen(tester, service: service, db: db);
    await _tapChooseFile(tester);

    // The reader was asked for a JSON export with its bytes attached: without
    // the bytes there would be nothing to parse offline.
    expect(picker.requests.single.type, FileType.custom);
    expect(picker.requests.single.allowedExtensions, ['json']);
    expect(picker.requests.single.withData, isTrue);
    expect(service.inspectCalls.single.source, ImportSource.paisa);
    expect(service.inspectCalls.single.bytes, bytes);

    // Every number the reader is about to act on comes from that file.
    expect(find.text('Ready to import'), findsOneWidget);
    expect(find.text('paisa-2024.json'), findsOneWidget);
    expect(_statValue(tester, 'Transactions'), '42');
    expect(_statValue(tester, 'Income entries'), '12');
    expect(_statValue(tester, 'Expense entries'), '30');
    expect(_statValue(tester, 'Categories'), '9');
    expect(_statValue(tester, 'Accounts'), '4');
    expect(_statValue(tester, 'Date range'), 'Jan 5, 2023 to Feb 10, 2024');
    expect(find.text('Import 42 transactions'), findsOneWidget);

    // Inspecting is a read: nothing has been written yet.
    expect(service.importCalls, isEmpty);
  });

  testWidgets('warnings about the file are surfaced before anything is written',
      (tester) async {
    _seedSettings();
    final db = newTestDatabase();
    closeTestDatabaseOnTearDown(tester, db);
    _installFilePicker([_file('paisa.json', _paisaBytes('first'))]);
    final service = _FakeImportService(
      onInspect: _previews(
        _preview(
          warnings: [
            '4 transfers will be skipped',
            '2 categories share the name Food',
          ],
        ),
      ),
      onImport: _neverImports(),
    );

    await _pumpImportScreen(tester, service: service, db: db);
    await _tapChooseFile(tester);

    expect(find.text('Heads up'), findsOneWidget);
    expect(find.text('• 4 transfers will be skipped'), findsOneWidget);
    expect(find.text('• 2 categories share the name Food'), findsOneWidget);
  });

  testWidgets('a file that is not a Paisa backup says so and invites a retry',
      (tester) async {
    _seedSettings();
    final db = newTestDatabase();
    closeTestDatabaseOnTearDown(tester, db);
    _installFilePicker([_file('holiday-photos.json', _paisaBytes('first'))]);
    final service = _FakeImportService(
      onInspect: _inspectFails(
        const ImportException("That doesn't look like a Paisa backup."),
      ),
      onImport: _neverImports(),
    );

    await _pumpImportScreen(tester, service: service, db: db);
    await _tapChooseFile(tester);

    expect(find.text("That doesn't look like a Paisa backup."), findsOneWidget);
    expect(find.text('Ready to import'), findsNothing);
    // Back to the start, so the reader can pick the right file.
    expect(find.text('Choose Paisa backup file'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(service.importCalls, isEmpty);
  });

  testWidgets('an unexpected parser failure explains itself instead of hanging',
      (tester) async {
    _seedSettings();
    final db = newTestDatabase();
    closeTestDatabaseOnTearDown(tester, db);
    _installFilePicker([_file('paisa.json', _paisaBytes('first'))]);
    final service = _FakeImportService(
      onInspect:
          _inspectFails(const FormatException('Unexpected end of input')),
      onImport: _neverImports(),
    );

    await _pumpImportScreen(tester, service: service, db: db);
    await _tapChooseFile(tester);

    expect(
      find.textContaining('Something went wrong reading the file'),
      findsOneWidget,
    );
    // Not left spinning on "Reading paisa.json".
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Choose Paisa backup file'), findsOneWidget);
  });

  testWidgets('an export with nothing in it cannot be imported',
      (tester) async {
    _seedSettings();
    final db = newTestDatabase();
    closeTestDatabaseOnTearDown(tester, db);
    _installFilePicker([_file('empty.json', _paisaBytes('first'))]);
    final service = _FakeImportService(
      onInspect: _previews(
        const ImportPreview(
          source: ImportSource.paisa,
          categories: 0,
          accounts: 0,
          transactions: 0,
          incomeCount: 0,
          expenseCount: 0,
          transferCount: 0,
        ),
      ),
      onImport: _neverImports(),
    );

    await _pumpImportScreen(tester, service: service, db: db);
    await _tapChooseFile(tester);

    expect(find.text('Nothing to import'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Nothing to import'),
          )
          .onPressed,
      isNull,
    );
    // No dates in the file, so no invented range is shown.
    expect(find.text('Date range'), findsNothing);

    await tester.tap(find.text('Nothing to import'));
    await tester.pumpAndSettle();
    expect(service.importCalls, isEmpty);
  });

  testWidgets('the result reports the rows that really landed', (tester) async {
    _seedSettings();
    final db = newTestDatabase();
    closeTestDatabaseOnTearDown(tester, db);
    final bytes = _paisaBytes('first');
    _installFilePicker([_file('paisa.json', bytes)]);
    final service = _FakeImportService(
      onInspect: _previews(_preview()),
      onImport: _imports(
        _outcome(warnings: ['1 transaction had no date and was skipped']),
      ),
    );

    final container = await _pumpImportScreen(tester, service: service, db: db);
    await _tapChooseFile(tester);
    await _tapImport(tester);

    expect(
      service.importCalls.single.bytes,
      bytes,
      reason: 'the file previewed must be the file imported',
    );
    expect(find.text('Import complete'), findsOneWidget);

    // 42 were offered, 40 landed and 2 transfers were skipped. The reader is
    // told what happened, not what was estimated.
    expect(_statValue(tester, 'Transactions imported'), '40');
    expect(_statValue(tester, 'Categories imported'), '9');
    expect(_statValue(tester, 'Accounts imported'), '4');
    expect(_statValue(tester, 'Transfers skipped'), '2');
    expect(
      find.text('• 1 transaction had no date and was skipped'),
      findsOneWidget,
    );

    // The flow is over: the same import cannot be fired a second time.
    expect(find.text('Import 42 transactions'), findsNothing);
    expect(find.text('Done'), findsOneWidget);

    // And the dashboard now points at the newest imported month, so the history
    // that just arrived is what the reader sees next.
    expect(container.read(focusedMonthProvider), DateTime(2024, 2, 10, 13));
  });

  testWidgets('a brand new profile is filled in without asking',
      (tester) async {
    _seedSettings(); // Nothing onboarded yet: nothing to overwrite.
    final db = newTestDatabase();
    closeTestDatabaseOnTearDown(tester, db);
    _installFilePicker([_file('paisa.json', _paisaBytes('first'))]);
    const detected = ImportedProfile(
      name: 'Vini',
      currencyCode: 'USD',
      currencySymbol: r'$',
    );
    final service = _FakeImportService(
      onInspect: _previews(_preview(profile: detected)),
      onImport: _imports(_outcome(profile: detected)),
    );

    await _pumpImportScreen(tester, service: service, db: db);
    await _tapChooseFile(tester);

    // The reader can see exactly which personal details are on offer.
    expect(find.text('Also import your profile'), findsOneWidget);
    expect(find.text('Name: Vini  ·  Currency: USD'), findsOneWidget);
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isTrue,
    );

    await _tapImport(tester);

    expect(find.text('Import profile details too?'), findsNothing);
    expect(service.importCalls.single.importProfile, isTrue);
    final settings = await _persistedSettings();
    expect(settings.userName, 'Vini');
    expect(settings.currencyCode, 'USD');
    expect(settings.currencySymbol, r'$');
    expect(_statValue(tester, 'Profile'), 'Imported');
  });

  testWidgets('declining the profile question imports the records only',
      (tester) async {
    _seedSettings(_existingProfile);
    final db = newTestDatabase();
    closeTestDatabaseOnTearDown(tester, db);
    _installFilePicker([_file('paisa.json', _paisaBytes('first'))]);
    final service = _FakeImportService(
      onInspect: _previews(_preview(profile: _backupProfile)),
      onImport: _imports(_outcome(profile: _backupProfile)),
    );

    await _pumpImportScreen(tester, service: service, db: db);
    await _tapChooseFile(tester);
    await _tapImport(tester);

    // Somebody who already has a profile is asked first, and told exactly what
    // would change.
    expect(find.text('Import profile details too?'), findsOneWidget);
    expect(find.text('• Change currency from INR to USD'), findsOneWidget);
    // Their own name is never up for replacement, so it is not listed.
    expect(find.textContaining('Set your name'), findsNothing);

    await tester.tap(find.text('No, keep mine'));
    await tester.pumpAndSettle();

    expect(service.importCalls.single.importProfile, isFalse);
    // The money data still came across in full ...
    expect(find.text('Import complete'), findsOneWidget);
    expect(_statValue(tester, 'Transactions imported'), '40');
    // ... but not one field of the existing profile was touched.
    final settings = await _persistedSettings();
    expect(settings.userName, 'Vinita');
    expect(settings.currencyCode, 'INR');
    expect(settings.currencySymbol, '₹');
    expect(find.text('Profile'), findsNothing);
  });

  testWidgets('accepting the profile question imports the records and profile',
      (tester) async {
    _seedSettings(_existingProfile);
    final db = newTestDatabase();
    closeTestDatabaseOnTearDown(tester, db);
    _installFilePicker([_file('paisa.json', _paisaBytes('first'))]);
    final service = _FakeImportService(
      onInspect: _previews(_preview(profile: _backupProfile)),
      onImport: _imports(_outcome(profile: _backupProfile)),
    );

    await _pumpImportScreen(tester, service: service, db: db);
    await _tapChooseFile(tester);
    await _tapImport(tester);

    await tester.tap(find.text('Yes, import profile'));
    await tester.pumpAndSettle();

    expect(service.importCalls.single.importProfile, isTrue);
    expect(_statValue(tester, 'Transactions imported'), '40');
    expect(_statValue(tester, 'Profile'), 'Imported');
    final settings = await _persistedSettings();
    expect(settings.currencyCode, 'USD');
    expect(settings.currencySymbol, r'$');
    // Even on a yes, a name the reader typed themselves is kept.
    expect(settings.userName, 'Vinita');
  });

  testWidgets('turning the profile switch off skips the question entirely',
      (tester) async {
    _seedSettings(_existingProfile);
    final db = newTestDatabase();
    closeTestDatabaseOnTearDown(tester, db);
    _installFilePicker([_file('paisa.json', _paisaBytes('first'))]);
    final service = _FakeImportService(
      onInspect: _previews(_preview(profile: _backupProfile)),
      onImport: _imports(_outcome(profile: _backupProfile)),
    );

    await _pumpImportScreen(tester, service: service, db: db);
    await _tapChooseFile(tester);

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isFalse,
    );

    await _tapImport(tester);

    // Already said no, so being asked again would be nagging.
    expect(find.text('Import profile details too?'), findsNothing);
    expect(service.importCalls.single.importProfile, isFalse);
    expect(_statValue(tester, 'Transactions imported'), '40');
    final settings = await _persistedSettings();
    expect(settings.currencyCode, 'INR');
    expect(settings.userName, 'Vinita');
  });

  testWidgets('no question when the backup profile matches the current one',
      (tester) async {
    _seedSettings(_existingProfile);
    final db = newTestDatabase();
    closeTestDatabaseOnTearDown(tester, db);
    _installFilePicker([_file('paisa.json', _paisaBytes('first'))]);
    const same = ImportedProfile(
      name: 'Vinita',
      currencyCode: 'INR',
      currencySymbol: '₹',
    );
    final service = _FakeImportService(
      onInspect: _previews(_preview(profile: same)),
      onImport: _imports(_outcome(profile: same)),
    );

    await _pumpImportScreen(tester, service: service, db: db);
    await _tapChooseFile(tester);
    await _tapImport(tester);

    // Nothing would change, so there is nothing to interrupt the reader about.
    expect(find.text('Import profile details too?'), findsNothing);
    expect(find.text('Import complete'), findsOneWidget);
    final settings = await _persistedSettings();
    expect(settings.userName, 'Vinita');
    expect(settings.currencyCode, 'INR');
  });

  testWidgets('a failed import says why and lets the reader try again',
      (tester) async {
    _seedSettings();
    final db = newTestDatabase();
    closeTestDatabaseOnTearDown(tester, db);
    _installFilePicker([_file('paisa.json', _paisaBytes('first'))]);
    var attempts = 0;
    final service = _FakeImportService(
      onInspect: _previews(_preview()),
      onImport: (_, {required bool importProfile}) async {
        attempts++;
        if (attempts == 1) {
          throw const ImportException('That backup file is damaged.');
        }
        return _outcome();
      },
    );

    await _pumpImportScreen(tester, service: service, db: db);
    await _tapChooseFile(tester);
    await _tapImport(tester);

    expect(find.text('That backup file is damaged.'), findsOneWidget);
    expect(find.text('Import complete'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    // The preview is still there, so a retry costs no re-picking.
    expect(find.text('Import 42 transactions'), findsOneWidget);

    await _tapImport(tester);

    expect(find.text('Import complete'), findsOneWidget);
    expect(_statValue(tester, 'Transactions imported'), '40');
    // A stale failure must not sit next to a successful result.
    expect(find.text('That backup file is damaged.'), findsNothing);
  });

  testWidgets('a running import is visible and cannot be started twice',
      (tester) async {
    _seedSettings();
    final db = newTestDatabase();
    closeTestDatabaseOnTearDown(tester, db);
    _installFilePicker([_file('paisa.json', _paisaBytes('first'))]);
    final gate = Completer<ImportOutcome>();
    final service = _FakeImportService(
      onInspect: _previews(_preview()),
      onImport: (_, {required bool importProfile}) => gate.future,
    );

    await _pumpImportScreen(tester, service: service, db: db);
    await _tapChooseFile(tester);
    await tester.tap(find.text('Import 42 transactions'));
    await tester.pump();

    expect(find.textContaining('Importing your data'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    // The button that started it is gone, so an impatient second tap cannot
    // import the same file twice.
    expect(find.text('Import 42 transactions'), findsNothing);

    gate.complete(_outcome());
    await tester.pumpAndSettle();

    expect(service.importCalls, hasLength(1));
    expect(find.text('Import complete'), findsOneWidget);
  });

  testWidgets('picking a different file replaces the preview', (tester) async {
    _seedSettings();
    final db = newTestDatabase();
    closeTestDatabaseOnTearDown(tester, db);
    final first = _paisaBytes('first');
    final second = _paisaBytes('second');
    _installFilePicker([_file('old.json', first), _file('new.json', second)]);
    final service = _FakeImportService(
      onInspect: (bytes) async => utf8.decode(bytes).contains('second')
          ? _preview(transactions: 7, incomeCount: 2, expenseCount: 5)
          : _preview(),
      onImport: _neverImports(),
    );

    await _pumpImportScreen(tester, service: service, db: db);
    await _tapChooseFile(tester);
    expect(find.text('Import 42 transactions'), findsOneWidget);

    await tester.tap(find.text('Choose a different file'));
    await tester.pumpAndSettle();

    // The second file is what is now on offer: no stale counts, no stale name,
    // so the reader cannot import the file they just replaced.
    expect(service.inspectCalls, hasLength(2));
    expect(service.inspectCalls.last.bytes, second);
    expect(find.text('new.json'), findsOneWidget);
    expect(find.text('old.json'), findsNothing);
    expect(_statValue(tester, 'Transactions'), '7');
    expect(find.text('Import 42 transactions'), findsNothing);
    expect(find.text('Import 7 transactions'), findsOneWidget);
  });

  testWidgets('cancelling the file dialog leaves the screen ready to retry',
      (tester) async {
    _seedSettings();
    final db = newTestDatabase();
    closeTestDatabaseOnTearDown(tester, db);
    _installFilePicker([null]);
    final service = _FakeImportService(
      onInspect: _previews(_preview()),
      onImport: _neverImports(),
    );

    await _pumpImportScreen(tester, service: service, db: db);
    await _tapChooseFile(tester);

    // Backing out of the dialog is not an error and is not a stuck spinner.
    expect(service.inspectCalls, isEmpty);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Ready to import'), findsNothing);
    expect(find.text('Choose Paisa backup file'), findsOneWidget);
  });

  testWidgets('a file the system will not hand over reports a plain error',
      (tester) async {
    _seedSettings();
    final db = newTestDatabase();
    closeTestDatabaseOnTearDown(tester, db);
    _installFilePicker([_unreadableFile('paisa.json')]);
    final service = _FakeImportService(
      onInspect: _previews(_preview()),
      onImport: _neverImports(),
    );

    await _pumpImportScreen(tester, service: service, db: db);
    await _tapChooseFile(tester);

    expect(
      find.text("Couldn't read that file. Please try again."),
      findsOneWidget,
    );
    expect(service.inspectCalls, isEmpty);
    expect(find.text('Choose Paisa backup file'), findsOneWidget);
  });
}
