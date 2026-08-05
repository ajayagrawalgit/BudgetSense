/// Full-application snapshot: a complete, format-agnostic, forward-compatible
/// export of EVERYTHING the user owns - all settings and profile, the chosen
/// theme / accent / font / app-icon, and every row of all database tables.
///
/// This is distinct from:
///   * [ExportService] - a human transactions spreadsheet (CSV / XLSX), and
///   * the legacy DB-only JSON backup (LocalBackupService, versions 1-2).
///
/// A snapshot round-trips with zero loss across three formats (JSON, sectioned
/// CSV, XML) and is designed to remain importable even after the app schema or
/// settings grow: unknown fields are ignored, missing fields fall back to
/// database / settings defaults. JSON is the canonical lossless form; CSV and
/// XML carry the exact same model.
library;

/// The output/import formats a snapshot supports.
enum SnapshotFormat { json, csv, xml }

extension SnapshotFormatX on SnapshotFormat {
  String get label => switch (this) {
        SnapshotFormat.json => 'JSON',
        SnapshotFormat.csv => 'CSV',
        SnapshotFormat.xml => 'XML',
      };

  /// File extension without the dot.
  String get ext => switch (this) {
        SnapshotFormat.json => 'json',
        SnapshotFormat.csv => 'csv',
        SnapshotFormat.xml => 'xml',
      };

  String get mimeType => switch (this) {
        SnapshotFormat.json => 'application/json',
        SnapshotFormat.csv => 'text/csv',
        SnapshotFormat.xml => 'application/xml',
      };
}

/// The canonical in-memory representation shared by all three codecs.
///
/// [settings] is the raw `SettingsState.toMap()` blob (string-keyed, JSON
/// scalars). [tables] maps each database table name to its rows, where each row
/// is the Drift `toJson()` map (JSON scalars; DateTime as ISO-8601 strings).
class AppSnapshot {
  const AppSnapshot({
    required this.exportedAt,
    required this.appVersion,
    required this.schemaVersion,
    required this.settings,
    required this.tables,
    this.version = currentVersion,
    this.backupId = '',
  });

  /// Snapshot envelope version. Bump only for breaking envelope changes, never
  /// for additive settings/columns (those are handled tolerantly).
  ///   v3 -> first full snapshot (settings + profile + theme + icon + all tables)
  ///   v4 -> adds a stable `backupId` for import-provenance and non-destructive
  ///         restore. Backward compatible: older files get a deterministic id
  ///         derived from their contents.
  static const int currentVersion = 4;

  /// Marker written into every file so importers can positively identify a
  /// BudgetSense snapshot regardless of format.
  static const String appMarker = 'BudgetSense';

  final int version;
  final DateTime exportedAt;
  final String appVersion;
  final int schemaVersion;

  /// Stable unique id for THIS backup file, used by the import ledger to make
  /// restore idempotent and auditable. Never identifies the user.
  final String backupId;

  final Map<String, Object?> settings;
  final Map<String, List<Map<String, Object?>>> tables;

  int get totalRows =>
      tables.values.fold<int>(0, (sum, rows) => sum + rows.length);
}

/// Result of producing a snapshot file.
class SnapshotExport {
  const SnapshotExport({
    required this.bytes,
    required this.fileName,
    required this.mimeType,
    required this.format,
    required this.settingsFields,
    required this.recordCount,
  });

  final List<int> bytes;
  final String fileName;
  final String mimeType;
  final SnapshotFormat format;
  final int settingsFields;
  final int recordCount;
}

/// Result of importing a snapshot file.
class SnapshotImportResult {
  const SnapshotImportResult({
    required this.format,
    required this.settingsApplied,
    required this.tableRows,
    this.warnings = const [],
    this.inserted = const {},
    this.skipped = const {},
    this.remapped = const {},
    this.versioned = const {},
    this.fkRewrites = 0,
    this.preferencesImported = const [],
    this.preferencesPreserved = const [],
  });

  /// The detected format the file was read as.
  final SnapshotFormat format;

  /// Whether any settings/profile/theme values were merged in.
  final bool settingsApplied;

  /// New rows inserted per table (append-only; the total the user gained).
  final Map<String, int> tableRows;

  /// Non-fatal notes (e.g. an unrecognised table was skipped).
  final List<String> warnings;

  /// Detailed, append-only restore breakdown.
  final Map<String, int> inserted;
  final Map<String, int> skipped;
  final Map<String, int> remapped;
  final Map<String, int> versioned;
  final int fkRewrites;

  /// Setting keys whose backed-up value was applied (local was uninitialized or
  /// the user explicitly selected the key).
  final List<String> preferencesImported;

  /// Setting keys whose existing local value was preserved despite differing.
  final List<String> preferencesPreserved;

  int get totalRows => tableRows.values.fold<int>(0, (sum, n) => sum + n);
  int get totalSkipped => skipped.values.fold<int>(0, (sum, n) => sum + n);
  int get totalRemapped => remapped.values.fold<int>(0, (sum, n) => sum + n);
  int get totalVersioned => versioned.values.fold<int>(0, (sum, n) => sum + n);
}

/// Produces and restores full-application snapshots.
abstract interface class SnapshotService {
  /// Serialize the entire app to [format].
  Future<SnapshotExport> export(SnapshotFormat format);

  /// Detect the format of [bytes] and restore everything it contains,
  /// NON-DESTRUCTIVELY (append-only for collections; a preserving merge for
  /// settings). Existing local records are never updated or deleted.
  ///
  /// [applySettingKeys], when provided, is the exact set of preference keys the
  /// user chose to apply. When null, only uninitialized local settings are
  /// filled from the backup. Throws [SnapshotException] on any critical
  /// validation failure, having made zero mutations.
  Future<SnapshotImportResult> importBytes(
    List<int> bytes, {
    Set<String>? applySettingKeys,
  });

  /// Validate [bytes] and build a reviewable [RestorePreview] WITHOUT mutating
  /// anything. Throws [SnapshotException] on critical validation failure.
  Future<RestorePreview> preview(List<int> bytes);
}

/// A mutation-free summary of what a restore WOULD do, for the confirm screen.
class RestorePreview {
  const RestorePreview({
    required this.backupCreatedAt,
    required this.appVersion,
    required this.snapshotVersion,
    required this.recordCountsByType,
    required this.existingLocalCounts,
    required this.toInsert,
    required this.toSkip,
    required this.idConflicts,
    required this.versionConflicts,
    required this.preferenceKeysAvailable,
    required this.preferenceKeysWouldPreserve,
    required this.integrityValidated,
  });

  final DateTime backupCreatedAt;
  final String appVersion;
  final int snapshotVersion;
  final Map<String, int> recordCountsByType;
  final Map<String, int> existingLocalCounts;
  final int toInsert;
  final int toSkip;
  final int idConflicts;
  final int versionConflicts;
  final List<String> preferenceKeysAvailable;
  final List<String> preferenceKeysWouldPreserve;
  final bool integrityValidated;
}

/// Thrown when a file cannot be read as any supported snapshot format.
class SnapshotException implements Exception {
  const SnapshotException(this.message);
  final String message;
  @override
  String toString() => 'SnapshotException: $message';
}
