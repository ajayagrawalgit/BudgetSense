/// Contracts and value types for importing data exported from *other* budgeting
/// apps into BudgetSense. Designed to grow: today it supports Paisa, but the
/// [ImportSource] enum and the preview/outcome shapes are source-agnostic so
/// new importers (e.g. Money Manager, Wallet) slot in without UI changes.
library;

/// A supported third-party app BudgetSense can import from.
enum ImportSource { paisa }

extension ImportSourceX on ImportSource {
  String get label => switch (this) {
        ImportSource.paisa => 'Paisa',
      };

  String get tagline => switch (this) {
        ImportSource.paisa =>
          'Expenses, income, categories, accounts & profile',
      };

  /// Guidance shown on the source's import screen: how to get the export file.
  String get howTo => switch (this) {
        ImportSource.paisa =>
          'In the Paisa app open Settings → Backup and export your data as a '
              'JSON file. Then pick that file below.',
      };

  bool get available => switch (this) {
        ImportSource.paisa => true,
      };
}

/// Lightweight profile details detected in an export, offered for import.
class ImportedProfile {
  const ImportedProfile({this.name, this.currencyCode, this.currencySymbol});

  final String? name;
  final String? currencyCode;
  final String? currencySymbol;

  bool get hasAnything =>
      (name != null && name!.trim().isNotEmpty) ||
      (currencyCode != null && currencyCode!.trim().isNotEmpty);
}

/// The result of inspecting an export file *without* writing anything, used to
/// show the user exactly what they're about to import before they commit.
class ImportPreview {
  const ImportPreview({
    required this.source,
    required this.categories,
    required this.accounts,
    required this.transactions,
    required this.incomeCount,
    required this.expenseCount,
    required this.transferCount,
    this.earliest,
    this.latest,
    this.profile,
    this.warnings = const [],
  });

  final ImportSource source;
  final int categories;
  final int accounts;
  final int transactions;
  final int incomeCount;
  final int expenseCount;
  final int transferCount;
  final DateTime? earliest;
  final DateTime? latest;
  final ImportedProfile? profile;
  final List<String> warnings;

  bool get isEmpty => categories == 0 && accounts == 0 && transactions == 0;
}

/// The result of actually performing an import.
class ImportOutcome {
  const ImportOutcome({
    required this.source,
    required this.categories,
    required this.accounts,
    required this.transactions,
    this.skippedTransfers = 0,
    this.failed = 0,
    this.warnings = const [],
    this.profile,
  });

  final ImportSource source;
  final int categories;
  final int accounts;
  final int transactions;
  final int skippedTransfers;
  final int failed;
  final List<String> warnings;
  final ImportedProfile? profile;

  int get totalRecords => categories + accounts + transactions;
}

/// Thrown when an export file can't be understood (wrong app, corrupt JSON,
/// unsupported version). Carries a human-friendly [message].
class ImportException implements Exception {
  const ImportException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Imports data exported from third-party budgeting apps. Implementations must
/// be idempotent (re-importing the same file updates rather than duplicates)
/// and must never partially corrupt existing data on failure.
abstract interface class DataImportService {
  /// Parse + validate [bytes] and summarise what would be imported. Does not
  /// write to the database. Throws [ImportException] on invalid input.
  Future<ImportPreview> inspect(ImportSource source, List<int> bytes);

  /// Import [bytes] into the database. When [importProfile] is true, detected
  /// profile details (name, currency) are returned in the outcome for the
  /// caller to persist to settings. Throws [ImportException] on invalid input.
  Future<ImportOutcome> import(
    ImportSource source,
    List<int> bytes, {
    bool importProfile = true,
  });
}
