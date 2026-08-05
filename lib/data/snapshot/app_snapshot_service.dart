import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../domain/services/snapshot_service.dart';
import '../../features/settings/settings_state.dart';
import '../database/app_database.dart';
import 'restore_engine.dart';
import 'snapshot_codecs.dart';
import 'snapshot_registry.dart';
import 'snapshot_tables.dart';

/// Concrete [SnapshotService]: reads the whole app (all included tables + the
/// settings/profile/theme/icon blob) as a JSON, CSV, or XML snapshot, and
/// restores it NON-DESTRUCTIVELY through the append-only [RestoreEngine].
///
/// Settings are read/written through injected callbacks so this stays decoupled
/// from Riverpod and SharedPreferences (the provider supplies them).
class AppSnapshotService implements SnapshotService {
  AppSnapshotService(
    this._db, {
    required this.readSettings,
    required this.writeSettings,
    this.appVersion = 'unknown',
    Uuid? uuid,
  })  : _uuid = uuid ?? const Uuid(),
        _engine = RestoreEngine(_db, uuid: uuid);

  final AppDatabase _db;
  final Future<Map<String, Object?>> Function() readSettings;
  final Future<void> Function(Map<String, Object?> settings) writeSettings;
  final String appVersion;
  final Uuid _uuid;
  final RestoreEngine _engine;

  static final Map<String, Object?> _settingDefaults =
      const SettingsState().toMap();

  @override
  Future<SnapshotExport> export(SnapshotFormat format) async {
    final settings = await readSettings();
    final tables = await readAllTables(_db);
    final snapshot = AppSnapshot(
      exportedAt: DateTime.now(),
      appVersion: appVersion,
      schemaVersion: _db.schemaVersion,
      backupId: _uuid.v4(),
      settings: settings,
      tables: tables,
    );
    final bytes = SnapshotCodecs.encode(snapshot, format);
    return SnapshotExport(
      bytes: bytes,
      fileName: 'budgetsense_snapshot_${_stamp()}.${format.ext}',
      mimeType: format.mimeType,
      format: format,
      settingsFields: settings.length,
      recordCount: snapshot.totalRows,
    );
  }

  @override
  Future<SnapshotImportResult> importBytes(
    List<int> bytes, {
    Set<String>? applySettingKeys,
  }) async {
    final snapshot = _decodeVerified(bytes);
    final format = SnapshotCodecs.detectFormat(bytes)!;

    final warnings = <String>[];
    for (final t in snapshot.tables.keys) {
      if (!kSnapshotTableOrder.contains(t) && snapshot.tables[t]!.isNotEmpty) {
        warnings.add('Skipped unknown section "$t" '
            '(${snapshot.tables[t]!.length} rows).');
      }
    }

    // Preflight builds a complete plan and throws on any critical failure
    // BEFORE a single row is written.
    final plan = await _engine.plan(snapshot);

    // Apply the collection portion atomically (append-only).
    final exec = await _engine.executeCollections(plan);

    // Non-destructive settings merge. Existing values win unless the local
    // value is uninitialized or the key was explicitly selected.
    final merge = await _mergeSettings(snapshot, applySettingKeys);

    return SnapshotImportResult(
      format: format,
      settingsApplied: merge.imported.isNotEmpty,
      tableRows: exec.inserted,
      warnings: warnings,
      inserted: exec.inserted,
      skipped: exec.skipped,
      remapped: exec.remapped,
      versioned: exec.versioned,
      fkRewrites: exec.fkRewrites,
      preferencesImported: merge.imported,
      preferencesPreserved: merge.preserved,
    );
  }

  @override
  Future<RestorePreview> preview(List<int> bytes) async {
    final snapshot = _decodeVerified(bytes);
    final plan = await _engine.plan(snapshot);
    final local = await readSettings();
    final available = <String>[];
    final wouldPreserve = <String>[];
    for (final key in mergeableSettingKeys()) {
      if (!snapshot.settings.containsKey(key)) continue;
      final localVal =
          local.containsKey(key) ? local[key] : _settingDefaults[key];
      if (localVal == snapshot.settings[key]) continue;
      available.add(key);
      if (!_isUninitialized(localVal, _settingDefaults[key])) {
        wouldPreserve.add(key);
      }
    }
    return RestorePreview(
      backupCreatedAt: snapshot.exportedAt,
      appVersion: snapshot.appVersion,
      snapshotVersion: snapshot.version,
      recordCountsByType: {
        for (final t in kSnapshotTableOrder)
          t: (snapshot.tables[t] ?? const []).length,
      },
      existingLocalCounts: {
        for (final t in kSnapshotTableOrder)
          t: plan.existingLocalIds[t]!.length,
      },
      toInsert: plan.toInsert + plan.toRemap + plan.toVersion,
      toSkip: plan.toSkip,
      idConflicts: plan.toRemap,
      versionConflicts: plan.toVersion,
      preferenceKeysAvailable: available,
      preferenceKeysWouldPreserve: wouldPreserve,
      integrityValidated: true,
    );
  }

  AppSnapshot _decodeVerified(List<int> bytes) {
    final format = SnapshotCodecs.detectFormat(bytes);
    if (format == null) {
      throw const SnapshotException(
        'Unrecognised file. Choose a BudgetSense JSON, CSV, or XML export.',
      );
    }
    // JSON is the one format whose marker is not structural, so verify it is a
    // BudgetSense file before touching any data (keeps foreign files out).
    if (format == SnapshotFormat.json) {
      final raw = jsonDecode(utf8.decode(bytes));
      if (raw is! Map || !_isBudgetSenseJson(Map<String, Object?>.from(raw))) {
        throw const SnapshotException(
          'This does not look like a BudgetSense export. To import from Paisa, '
          'use Settings > Import instead.',
        );
      }
    }
    try {
      return SnapshotCodecs.decode(bytes, format);
    } on SnapshotException {
      rethrow;
    } catch (e) {
      throw SnapshotException('Could not read the ${format.label} file: $e');
    }
  }

  Future<_MergeResult> _mergeSettings(
    AppSnapshot snapshot,
    Set<String>? applyKeys,
  ) async {
    if (snapshot.settings.isEmpty) {
      return const _MergeResult([], []);
    }
    final local = await readSettings();
    final merged = <String, Object?>{...local};
    final imported = <String>[];
    final preserved = <String>[];

    for (final key in mergeableSettingKeys()) {
      if (!snapshot.settings.containsKey(key)) continue;
      final snapVal = snapshot.settings[key];
      final localVal =
          local.containsKey(key) ? local[key] : _settingDefaults[key];
      if (localVal == snapVal) continue; // same value, nothing to do

      final apply = applyKeys != null
          ? applyKeys.contains(key)
          : _isUninitialized(localVal, _settingDefaults[key]);
      if (apply) {
        merged[key] = snapVal;
        imported.add(key);
      } else {
        preserved.add(key);
      }
    }

    if (imported.isNotEmpty) {
      await writeSettings(merged);
    }
    return _MergeResult(imported, preserved);
  }

  bool _isUninitialized(Object? localVal, Object? defaultVal) {
    if (localVal == defaultVal) return true;
    if (localVal == null) return true;
    if (localVal is String && localVal.isEmpty) return true;
    return false;
  }

  bool _isBudgetSenseJson(Map<String, Object?> raw) {
    if (raw['app'] == AppSnapshot.appMarker) return true;
    if (raw.containsKey('settings') && raw.containsKey('data')) return true;
    // Legacy DB-only backup: an integer version plus at least one known table.
    final version = raw['version'];
    final hasKnownTable = kSnapshotTableOrder.any(raw.containsKey);
    return version is int && hasKnownTable;
  }

  String _stamp() {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${now.year}${two(now.month)}${two(now.day)}_'
        '${two(now.hour)}${two(now.minute)}';
  }
}

class _MergeResult {
  const _MergeResult(this.imported, this.preserved);
  final List<String> imported;
  final List<String> preserved;
}
