import 'package:drift/drift.dart';

import 'connection.dart';
import 'tables.dart';

part 'app_database.g.dart';

/// The central Drift database. All local persistence flows through here.
///
/// Schema migrations are versioned via [schemaVersion] + [migration]; bump the
/// version and add an upgrade step whenever tables change (Section 16).
@DriftDatabase(
  tables: [
    Categories,
    Accounts,
    PaymentMethods,
    Transactions,
    RecurringPayments,
    Loans,
    CustomFields,
    CustomFieldValues,
    Thresholds,
    NotificationPreferences,
    ExportRecords,
    ImportLedger,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(openConnection());

  /// Test constructor allowing an in-memory / custom executor.
  AppDatabase.forTesting(super.executor);

  /// Bump this whenever the schema changes, and add a matching `if (from < N)`
  /// step in [migration]. History:
  ///   v1 -> initial schema
  ///   v2 -> performance indexes on hot filter columns (occurredAt, categoryId,
  ///         archivedAt, nextDueDate, nextPaymentDate, owner/field ids)
  ///   v3 -> transactions.iconCodePoint (nullable) for per-expense icons
  ///   v4 -> import_ledger table (device-local restore provenance; enables the
  ///         non-destructive, idempotent, append-only restore engine)
  ///   v5 -> loans.showInUpcoming (opt-in: surface a loan's EMI in the
  ///         recurring due/Upcoming lists). Defaults false, so every existing
  ///         loan keeps its current behaviour until the user opts in.
  ///
  /// At-rest encryption: the local SQLite file is currently NOT encrypted at
  /// the application layer (no SQLCipher). Confidentiality relies on the OS:
  /// the file lives in the app's private sandbox and, on modern Android/iOS,
  /// benefits from full-disk / file-based encryption tied to the device lock.
  /// See SECURITY.md for the full threat model and the SQLCipher upgrade
  /// path. Do not claim this data is encrypted by the app.
  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          // Fresh installs get the full current schema, including the indexes
          // declared via @TableIndex annotations in tables.dart.
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          // Stepwise, forward-only migrations. Each step is idempotent so a
          // partially-applied or re-run upgrade can never corrupt data.
          if (from < 2) {
            await _createPerformanceIndexes();
          }
          if (from < 3) {
            // Per-expense icon. Nullable, so existing rows keep NULL and fall
            // back to their category icon - no data touched.
            await m.addColumn(transactions, transactions.iconCodePoint);
          }
          if (from < 4) {
            // Device-local restore provenance. New empty table; touches no
            // existing user data. Enables the non-destructive restore engine.
            await m.createTable(importLedger);
          }
          if (from < 5) {
            // Opt-in EMI surfacing. Defaults to false, so every loan that
            // already exists keeps showing only on the Loans tab.
            await m.addColumn(loans, loans.showInUpcoming);
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON;');
        },
      );

  /// Creates the v2 performance indexes. `IF NOT EXISTS` keeps this safe to run
  /// on databases where [MigrationStrategy.onCreate] already made them.
  Future<void> _createPerformanceIndexes() async {
    const statements = <String>[
      'CREATE INDEX IF NOT EXISTS idx_txn_occurred ON transactions (occurred_at);',
      'CREATE INDEX IF NOT EXISTS idx_txn_category ON transactions (category_id);',
      'CREATE INDEX IF NOT EXISTS idx_txn_archived ON transactions (archived_at);',
      'CREATE INDEX IF NOT EXISTS idx_recpay_next_due ON recurring_payments (next_due_date);',
      'CREATE INDEX IF NOT EXISTS idx_recpay_archived ON recurring_payments (archived_at);',
      'CREATE INDEX IF NOT EXISTS idx_loan_next_payment ON loans (next_payment_date);',
      'CREATE INDEX IF NOT EXISTS idx_loan_archived ON loans (archived_at);',
      'CREATE INDEX IF NOT EXISTS idx_cfv_owner ON custom_field_values (owner_id);',
      'CREATE INDEX IF NOT EXISTS idx_cfv_field ON custom_field_values (field_id);',
    ];
    for (final sql in statements) {
      await customStatement(sql);
    }
  }

  /// Deletes all user data (Section 18: data deletion). Order respects FKs.
  Future<void> wipeAllData() async {
    await transaction(() async {
      await delete(customFieldValues).go();
      await delete(transactions).go();
      await delete(recurringPayments).go();
      await delete(loans).go();
      await delete(customFields).go();
      await delete(thresholds).go();
      await delete(notificationPreferences).go();
      await delete(exportRecords).go();
      // Provenance is meaningless once the data it references is gone.
      await delete(importLedger).go();
      await delete(categories).go();
      await delete(accounts).go();
      await delete(paymentMethods).go();
    });
  }
}
