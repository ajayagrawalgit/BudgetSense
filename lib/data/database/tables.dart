import 'package:drift/drift.dart';

/// Drift table definitions for BudgetSense's local, offline-first store.
///
/// Conventions:
///  * Every user record has a text UUID [id], created/updated timestamps, an
///    optional archived timestamp, and a [syncStatus] int placeholder so cloud
///    sync can be added later without a migration rewrite (Section 21).
///  * Money is stored as INTEGER minor units - never as a floating-point
///    column - to keep financial math exact.

/// Reusable column set. Drift mixes these into each table.
mixin _AuditColumns on Table {
  TextColumn get id => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get archivedAt => dateTime().nullable()();
  IntColumn get syncStatus => integer().withDefault(const Constant(0))();
}

class Categories extends Table with _AuditColumns {
  TextColumn get name => text().withLength(min: 1, max: 120)();
  IntColumn get colorValue => integer()();
  IntColumn get iconCodePoint => integer()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();

  /// LEGACY, inert. Kept only so old backups still import; NO app logic reads
  /// or writes this. Categories are fully dynamic and carry no fixed
  /// classification - do not reintroduce a bucket concept here.
  TextColumn get semanticBucket => text().withDefault(const Constant(''))();

  @override
  Set<Column> get primaryKey => {id};
}

class Accounts extends Table with _AuditColumns {
  TextColumn get name => text().withLength(min: 1, max: 120)();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

class PaymentMethods extends Table with _AuditColumns {
  TextColumn get name => text().withLength(min: 1, max: 120)();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(name: 'idx_txn_occurred', columns: {#occurredAt})
@TableIndex(name: 'idx_txn_category', columns: {#categoryId})
@TableIndex(name: 'idx_txn_archived', columns: {#archivedAt})
class Transactions extends Table with _AuditColumns {
  /// Stored as the enum index of [TransactionType].
  IntColumn get type => integer()();
  TextColumn get name => text().withLength(min: 1, max: 120)();

  /// Amount in minor units (e.g. cents). Always non-negative; direction is
  /// implied by [type].
  IntColumn get amountMinor => integer()();

  DateTimeColumn get occurredAt => dateTime()();

  /// Optional per-transaction icon (code point into kCategoryIcons). When null,
  /// the UI falls back to the linked category's icon (Splitwise-style).
  IntColumn get iconCodePoint => integer().nullable()();

  TextColumn get categoryId => text().nullable().references(Categories, #id)();
  TextColumn get accountId => text().nullable().references(Accounts, #id)();
  TextColumn get paymentMethodId =>
      text().nullable().references(PaymentMethods, #id)();

  /// Enum index of IncomeType when [type] == income; null otherwise.
  IntColumn get incomeType => integer().nullable()();

  TextColumn get merchant => text().nullable()();
  TextColumn get notes => text().nullable()();

  /// Comma-free JSON array of tag strings. Small and denormalized on purpose.
  TextColumn get tagsJson => text().withDefault(const Constant('[]'))();

  TextColumn get linkedPaymentId => text().nullable()();
  TextColumn get linkedLoanId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(name: 'idx_recpay_next_due', columns: {#nextDueDate})
@TableIndex(name: 'idx_recpay_archived', columns: {#archivedAt})
class RecurringPayments extends Table with _AuditColumns {
  TextColumn get name => text().withLength(min: 1, max: 120)();
  IntColumn get amountMinor => integer()();

  /// Enum index of PaymentKind.
  IntColumn get kind => integer()();

  /// Enum index of Frequency.
  IntColumn get frequency => integer()();
  IntColumn get customIntervalDays =>
      integer().withDefault(const Constant(30))();

  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime().nullable()();
  DateTimeColumn get nextDueDate => dateTime()();

  TextColumn get categoryId => text().nullable().references(Categories, #id)();
  TextColumn get accountId => text().nullable().references(Accounts, #id)();
  TextColumn get notes => text().nullable()();

  BoolColumn get autoAddTransaction =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get reminderEnabled =>
      boolean().withDefault(const Constant(true))();
  IntColumn get reminderDaysBefore =>
      integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(name: 'idx_loan_next_payment', columns: {#nextPaymentDate})
@TableIndex(name: 'idx_loan_archived', columns: {#archivedAt})
class Loans extends Table with _AuditColumns {
  TextColumn get name => text().withLength(min: 1, max: 120)();
  TextColumn get lender => text().nullable()();

  IntColumn get originalPrincipalMinor => integer()();
  IntColumn get outstandingPrincipalMinor => integer()();
  IntColumn get emiMinor => integer()();

  /// Interest rate percentage stored ×100 for precision (e.g. 8.75% -> 875).
  IntColumn get interestRateBps => integer().withDefault(const Constant(0))();

  IntColumn get frequency => integer()(); // enum index
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime().nullable()();
  DateTimeColumn get nextPaymentDate => dateTime().nullable()();
  IntColumn get totalPaidMinor => integer().withDefault(const Constant(0))();

  /// Opt-in: list this loan's EMI alongside recurring payments (due and
  /// Upcoming) instead of only on the Loans tab. Off by default so existing
  /// loans keep behaving exactly as before.
  BoolColumn get showInUpcoming =>
      boolean().withDefault(const Constant(false))();

  TextColumn get notes => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Definition of a user-created custom field (Section 6).
class CustomFields extends Table with _AuditColumns {
  TextColumn get name => text().withLength(min: 1, max: 120)();

  /// Enum index of CustomFieldType.
  IntColumn get fieldType => integer()();
  TextColumn get defaultValue => text().nullable()();
  BoolColumn get required => boolean().withDefault(const Constant(false))();
  BoolColumn get visible => boolean().withDefault(const Constant(true))();
  IntColumn get displayOrder => integer().withDefault(const Constant(0))();

  /// JSON array of allowed values (for dropdown / multi-select).
  TextColumn get allowedValuesJson =>
      text().withDefault(const Constant('[]'))();

  /// JSON array of TransactionType indices this field applies to.
  TextColumn get appliesToJson => text().withDefault(const Constant('[]'))();

  @override
  Set<Column> get primaryKey => {id};
}

/// The value a custom field holds for a specific record.
@TableIndex(name: 'idx_cfv_owner', columns: {#ownerId})
@TableIndex(name: 'idx_cfv_field', columns: {#fieldId})
class CustomFieldValues extends Table with _AuditColumns {
  TextColumn get fieldId => text().references(CustomFields, #id)();

  /// The owning record's id (transaction, loan, payment, etc.).
  TextColumn get ownerId => text()();
  TextColumn get ownerType => text()(); // e.g. 'transaction', 'loan'
  TextColumn get value => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Thresholds extends Table with _AuditColumns {
  TextColumn get label => text().withLength(min: 1, max: 160)();

  /// Enum index of ThresholdType.
  IntColumn get thresholdType => integer()();

  /// Percentage (0 to 100) or amount in minor units, per [thresholdType].
  RealColumn get value => real()();
  RealColumn get warningPercent => real().withDefault(const Constant(0.8))();
  RealColumn get criticalPercent => real().withDefault(const Constant(0.95))();
  TextColumn get scopeKey => text().nullable()();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

class NotificationPreferences extends Table with _AuditColumns {
  /// Kind key: 'threshold_approaching', 'payment_due', etc.
  TextColumn get kind => text()();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  IntColumn get timingMinutes => integer().withDefault(const Constant(0))();
  IntColumn get quietStartMinute => integer().nullable()();
  IntColumn get quietEndMinute => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// A record of an export the user generated (Section 21: ExportRecord).
class ExportRecords extends Table with _AuditColumns {
  TextColumn get format => text()(); // 'csv' | 'xlsx'
  TextColumn get scope => text()(); // 'all' | 'month' | 'range' | ...
  IntColumn get recordCount => integer().withDefault(const Constant(0))();
  TextColumn get filePath => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Durable import provenance (Section: non-destructive restore).
///
/// One row is written for every collection record the restore engine INSERTS,
/// recording which backup/source record produced which local record and the
/// canonical content hash at import time. This is what makes restore:
///   * idempotent  - re-importing the same file skips already-imported records,
///   * append-only - collisions are remapped to a NEW local id rather than
///     overwriting an existing record,
///   * auditable   - conflicts are recorded, never silently discarded.
///
/// This table is DEVICE-LOCAL provenance metadata. It is deliberately EXCLUDED
/// from snapshots (it must never travel between devices - it describes this
/// device's import history, not user-owned financial data).
@TableIndex(
  name: 'idx_ledger_source',
  columns: {#sourceEntityType, #sourceRecordId},
)
class ImportLedger extends Table {
  /// UUID of this ledger entry.
  TextColumn get id => text()();

  /// The envelope backup id the source record came from (audit only).
  TextColumn get backupId => text()();

  /// Snapshot table name, e.g. 'transactions'.
  TextColumn get sourceEntityType => text()();

  /// The record's stable id inside the source snapshot.
  TextColumn get sourceRecordId => text()();

  /// Canonical content hash of the source record at import time.
  TextColumn get sourceContentHash => text()();

  /// The id of the local record the source was resolved to (preserved or
  /// remapped).
  TextColumn get localRecordId => text()();

  DateTimeColumn get importedAt => dateTime()();

  /// 'inserted' (preserved id) | 'remapped' (id collision) | 'version' (a newer
  /// version of an already-imported record, appended as a separate record).
  TextColumn get conflictStatus =>
      text().withDefault(const Constant('inserted'))();

  @override
  Set<Column> get primaryKey => {id};
}
