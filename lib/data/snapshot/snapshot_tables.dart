import 'package:drift/drift.dart';

import '../database/app_database.dart';

/// Column-type registry, row readers, and TOLERANT companion builders for the
/// full-snapshot subsystem.
///
/// Forward compatibility is the whole point of this file:
///   * Reading uses Drift `toJson()`, so exported rows always match the current
///     schema exactly.
///   * Writing builds companions where any absent key becomes [Value.absent],
///     so restoring an OLDER file (missing a newly-added column) lets the
///     database default fill the gap, and restoring a NEWER file (with an extra
///     column) simply ignores the unknown key. Neither case throws.
///
/// The table names and per-table column order below are the on-disk contract
/// for CSV/XML layout. They must not be reordered or renamed once shipped.

/// Logical column kinds, used by the CSV/XML codecs to parse text back to typed
/// values on import.
enum ColType { text, integer, real, boolean, dateTime }

/// One column in the snapshot contract.
class ColSpec {
  const ColSpec(this.key, this.type, {this.nullable = false});
  final String key;
  final ColType type;
  final bool nullable;
}

/// FK-safe insert order (reference tables first).
const List<String> kSnapshotTableOrder = <String>[
  'categories',
  'accounts',
  'paymentMethods',
  'transactions',
  'recurringPayments',
  'loans',
  'customFields',
  'customFieldValues',
  'thresholds',
  'notificationPreferences',
  'exportRecords',
];

const List<ColSpec> _audit = <ColSpec>[
  ColSpec('id', ColType.text),
  ColSpec('createdAt', ColType.dateTime),
  ColSpec('updatedAt', ColType.dateTime),
  ColSpec('archivedAt', ColType.dateTime, nullable: true),
  ColSpec('syncStatus', ColType.integer),
];

/// Ordered column spec per table. Used only by CSV/XML for headers and typed
/// parsing; JSON carries the maps verbatim.
final Map<String, List<ColSpec>> kSnapshotColumns = <String, List<ColSpec>>{
  'categories': <ColSpec>[
    ..._audit,
    const ColSpec('name', ColType.text),
    const ColSpec('colorValue', ColType.integer),
    const ColSpec('iconCodePoint', ColType.integer),
    const ColSpec('sortOrder', ColType.integer),
    const ColSpec('isDefault', ColType.boolean),
    const ColSpec('semanticBucket', ColType.text),
  ],
  'accounts': <ColSpec>[
    ..._audit,
    const ColSpec('name', ColType.text),
    const ColSpec('sortOrder', ColType.integer),
  ],
  'paymentMethods': <ColSpec>[
    ..._audit,
    const ColSpec('name', ColType.text),
    const ColSpec('sortOrder', ColType.integer),
  ],
  'transactions': <ColSpec>[
    ..._audit,
    const ColSpec('type', ColType.integer),
    const ColSpec('name', ColType.text),
    const ColSpec('amountMinor', ColType.integer),
    const ColSpec('occurredAt', ColType.dateTime),
    const ColSpec('iconCodePoint', ColType.integer, nullable: true),
    const ColSpec('categoryId', ColType.text, nullable: true),
    const ColSpec('accountId', ColType.text, nullable: true),
    const ColSpec('paymentMethodId', ColType.text, nullable: true),
    const ColSpec('incomeType', ColType.integer, nullable: true),
    const ColSpec('merchant', ColType.text, nullable: true),
    const ColSpec('notes', ColType.text, nullable: true),
    const ColSpec('tagsJson', ColType.text),
    const ColSpec('linkedPaymentId', ColType.text, nullable: true),
    const ColSpec('linkedLoanId', ColType.text, nullable: true),
  ],
  'recurringPayments': <ColSpec>[
    ..._audit,
    const ColSpec('name', ColType.text),
    const ColSpec('amountMinor', ColType.integer),
    const ColSpec('kind', ColType.integer),
    const ColSpec('frequency', ColType.integer),
    const ColSpec('customIntervalDays', ColType.integer),
    const ColSpec('startDate', ColType.dateTime),
    const ColSpec('endDate', ColType.dateTime, nullable: true),
    const ColSpec('nextDueDate', ColType.dateTime),
    const ColSpec('categoryId', ColType.text, nullable: true),
    const ColSpec('accountId', ColType.text, nullable: true),
    const ColSpec('notes', ColType.text, nullable: true),
    const ColSpec('autoAddTransaction', ColType.boolean),
    const ColSpec('reminderEnabled', ColType.boolean),
    const ColSpec('reminderDaysBefore', ColType.integer),
  ],
  'loans': <ColSpec>[
    ..._audit,
    const ColSpec('name', ColType.text),
    const ColSpec('lender', ColType.text, nullable: true),
    const ColSpec('originalPrincipalMinor', ColType.integer),
    const ColSpec('outstandingPrincipalMinor', ColType.integer),
    const ColSpec('emiMinor', ColType.integer),
    const ColSpec('interestRateBps', ColType.integer),
    const ColSpec('frequency', ColType.integer),
    const ColSpec('startDate', ColType.dateTime),
    const ColSpec('endDate', ColType.dateTime, nullable: true),
    const ColSpec('nextPaymentDate', ColType.dateTime, nullable: true),
    const ColSpec('totalPaidMinor', ColType.integer),
    const ColSpec('notes', ColType.text, nullable: true),
  ],
  'customFields': <ColSpec>[
    ..._audit,
    const ColSpec('name', ColType.text),
    const ColSpec('fieldType', ColType.integer),
    const ColSpec('defaultValue', ColType.text, nullable: true),
    const ColSpec('required', ColType.boolean),
    const ColSpec('visible', ColType.boolean),
    const ColSpec('displayOrder', ColType.integer),
    const ColSpec('allowedValuesJson', ColType.text),
    const ColSpec('appliesToJson', ColType.text),
  ],
  'customFieldValues': <ColSpec>[
    ..._audit,
    const ColSpec('fieldId', ColType.text),
    const ColSpec('ownerId', ColType.text),
    const ColSpec('ownerType', ColType.text),
    const ColSpec('value', ColType.text, nullable: true),
  ],
  'thresholds': <ColSpec>[
    ..._audit,
    const ColSpec('label', ColType.text),
    const ColSpec('thresholdType', ColType.integer),
    const ColSpec('value', ColType.real),
    const ColSpec('warningPercent', ColType.real),
    const ColSpec('criticalPercent', ColType.real),
    const ColSpec('scopeKey', ColType.text, nullable: true),
    const ColSpec('enabled', ColType.boolean),
  ],
  'notificationPreferences': <ColSpec>[
    ..._audit,
    const ColSpec('kind', ColType.text),
    const ColSpec('enabled', ColType.boolean),
    const ColSpec('timingMinutes', ColType.integer),
    const ColSpec('quietStartMinute', ColType.integer, nullable: true),
    const ColSpec('quietEndMinute', ColType.integer, nullable: true),
  ],
  'exportRecords': <ColSpec>[
    ..._audit,
    const ColSpec('format', ColType.text),
    const ColSpec('scope', ColType.text),
    const ColSpec('recordCount', ColType.integer),
    const ColSpec('filePath', ColType.text, nullable: true),
  ],
};

// ---- Reading (export) ------------------------------------------------------

/// Reads every table as ordered JSON maps (Drift `toJson()`).
Future<Map<String, List<Map<String, Object?>>>> readAllTables(
  AppDatabase db,
) async {
  Future<List<Map<String, Object?>>> rows(Iterable<dynamic> data) async =>
      data.map((e) => (e as dynamic).toJson() as Map<String, Object?>).toList();

  return <String, List<Map<String, Object?>>>{
    'categories': await rows(await db.select(db.categories).get()),
    'accounts': await rows(await db.select(db.accounts).get()),
    'paymentMethods': await rows(await db.select(db.paymentMethods).get()),
    'transactions': await rows(await db.select(db.transactions).get()),
    'recurringPayments':
        await rows(await db.select(db.recurringPayments).get()),
    'loans': await rows(await db.select(db.loans).get()),
    'customFields': await rows(await db.select(db.customFields).get()),
    'customFieldValues':
        await rows(await db.select(db.customFieldValues).get()),
    'thresholds': await rows(await db.select(db.thresholds).get()),
    'notificationPreferences':
        await rows(await db.select(db.notificationPreferences).get()),
    'exportRecords': await rows(await db.select(db.exportRecords).get()),
  };
}

// ---- Writing (import) ------------------------------------------------------

/// Inserts a single fully-resolved [row] into [table] with a PLAIN insert (no
/// upsert). The restore engine guarantees the row's `id` is free (either a
/// preserved id known not to collide, or a freshly minted one) and that all
/// foreign keys are already remapped, so a plain insert is correct and safe:
/// an unexpected collision throws and rolls the whole restore back rather than
/// silently overwriting a user's record.
///
/// Returns true if a row was inserted; false for an unknown table name.
Future<bool> insertResolvedRow(
  AppDatabase db,
  String table,
  Map<String, Object?> row,
) async {
  switch (table) {
    case 'categories':
      await db.into(db.categories).insert(_categories(row));
    case 'accounts':
      await db.into(db.accounts).insert(_accounts(row));
    case 'paymentMethods':
      await db.into(db.paymentMethods).insert(_paymentMethods(row));
    case 'transactions':
      await db.into(db.transactions).insert(_transactions(row));
    case 'recurringPayments':
      await db.into(db.recurringPayments).insert(_recurringPayments(row));
    case 'loans':
      await db.into(db.loans).insert(_loans(row));
    case 'customFields':
      await db.into(db.customFields).insert(_customFields(row));
    case 'customFieldValues':
      await db.into(db.customFieldValues).insert(_customFieldValues(row));
    case 'thresholds':
      await db.into(db.thresholds).insert(_thresholds(row));
    case 'notificationPreferences':
      await db
          .into(db.notificationPreferences)
          .insert(_notificationPreferences(row));
    case 'exportRecords':
      await db.into(db.exportRecords).insert(_exportRecords(row));
    default:
      return false;
  }
  return true;
}

/// Restores [rows] into [table] using insert-or-update (by primary key), inside
/// whatever transaction the caller opened. Unknown table names are ignored by
/// the caller; this asserts a known name.
Future<int> insertSnapshotRows(
  AppDatabase db,
  String table,
  List<Map<String, Object?>> rows,
) async {
  var n = 0;
  for (final m in rows) {
    switch (table) {
      case 'categories':
        await db.into(db.categories).insertOnConflictUpdate(_categories(m));
      case 'accounts':
        await db.into(db.accounts).insertOnConflictUpdate(_accounts(m));
      case 'paymentMethods':
        await db
            .into(db.paymentMethods)
            .insertOnConflictUpdate(_paymentMethods(m));
      case 'transactions':
        await db.into(db.transactions).insertOnConflictUpdate(_transactions(m));
      case 'recurringPayments':
        await db
            .into(db.recurringPayments)
            .insertOnConflictUpdate(_recurringPayments(m));
      case 'loans':
        await db.into(db.loans).insertOnConflictUpdate(_loans(m));
      case 'customFields':
        await db.into(db.customFields).insertOnConflictUpdate(_customFields(m));
      case 'customFieldValues':
        await db
            .into(db.customFieldValues)
            .insertOnConflictUpdate(_customFieldValues(m));
      case 'thresholds':
        await db.into(db.thresholds).insertOnConflictUpdate(_thresholds(m));
      case 'notificationPreferences':
        await db
            .into(db.notificationPreferences)
            .insertOnConflictUpdate(_notificationPreferences(m));
      case 'exportRecords':
        await db
            .into(db.exportRecords)
            .insertOnConflictUpdate(_exportRecords(m));
      default:
        return n; // unknown table: skip silently (handled/warned by caller)
    }
    n++;
  }
  return n;
}

// ---- Per-table tolerant companion builders ---------------------------------

CategoriesCompanion _categories(Map<String, Object?> m) => CategoriesCompanion(
      id: _str(m, 'id'),
      createdAt: _date(m, 'createdAt'),
      updatedAt: _date(m, 'updatedAt'),
      archivedAt: _dateN(m, 'archivedAt'),
      syncStatus: _int(m, 'syncStatus'),
      name: _str(m, 'name'),
      colorValue: _int(m, 'colorValue'),
      iconCodePoint: _int(m, 'iconCodePoint'),
      sortOrder: _int(m, 'sortOrder'),
      isDefault: _bool(m, 'isDefault'),
      semanticBucket: _str(m, 'semanticBucket'),
    );

AccountsCompanion _accounts(Map<String, Object?> m) => AccountsCompanion(
      id: _str(m, 'id'),
      createdAt: _date(m, 'createdAt'),
      updatedAt: _date(m, 'updatedAt'),
      archivedAt: _dateN(m, 'archivedAt'),
      syncStatus: _int(m, 'syncStatus'),
      name: _str(m, 'name'),
      sortOrder: _int(m, 'sortOrder'),
    );

PaymentMethodsCompanion _paymentMethods(Map<String, Object?> m) =>
    PaymentMethodsCompanion(
      id: _str(m, 'id'),
      createdAt: _date(m, 'createdAt'),
      updatedAt: _date(m, 'updatedAt'),
      archivedAt: _dateN(m, 'archivedAt'),
      syncStatus: _int(m, 'syncStatus'),
      name: _str(m, 'name'),
      sortOrder: _int(m, 'sortOrder'),
    );

TransactionsCompanion _transactions(Map<String, Object?> m) =>
    TransactionsCompanion(
      id: _str(m, 'id'),
      createdAt: _date(m, 'createdAt'),
      updatedAt: _date(m, 'updatedAt'),
      archivedAt: _dateN(m, 'archivedAt'),
      syncStatus: _int(m, 'syncStatus'),
      type: _int(m, 'type'),
      name: _str(m, 'name'),
      amountMinor: _int(m, 'amountMinor'),
      occurredAt: _date(m, 'occurredAt'),
      iconCodePoint: _intN(m, 'iconCodePoint'),
      categoryId: _strN(m, 'categoryId'),
      accountId: _strN(m, 'accountId'),
      paymentMethodId: _strN(m, 'paymentMethodId'),
      incomeType: _intN(m, 'incomeType'),
      merchant: _strN(m, 'merchant'),
      notes: _strN(m, 'notes'),
      tagsJson: _str(m, 'tagsJson'),
      linkedPaymentId: _strN(m, 'linkedPaymentId'),
      linkedLoanId: _strN(m, 'linkedLoanId'),
    );

RecurringPaymentsCompanion _recurringPayments(Map<String, Object?> m) =>
    RecurringPaymentsCompanion(
      id: _str(m, 'id'),
      createdAt: _date(m, 'createdAt'),
      updatedAt: _date(m, 'updatedAt'),
      archivedAt: _dateN(m, 'archivedAt'),
      syncStatus: _int(m, 'syncStatus'),
      name: _str(m, 'name'),
      amountMinor: _int(m, 'amountMinor'),
      kind: _int(m, 'kind'),
      frequency: _int(m, 'frequency'),
      customIntervalDays: _int(m, 'customIntervalDays'),
      startDate: _date(m, 'startDate'),
      endDate: _dateN(m, 'endDate'),
      nextDueDate: _date(m, 'nextDueDate'),
      categoryId: _strN(m, 'categoryId'),
      accountId: _strN(m, 'accountId'),
      notes: _strN(m, 'notes'),
      autoAddTransaction: _bool(m, 'autoAddTransaction'),
      reminderEnabled: _bool(m, 'reminderEnabled'),
      reminderDaysBefore: _int(m, 'reminderDaysBefore'),
    );

LoansCompanion _loans(Map<String, Object?> m) => LoansCompanion(
      id: _str(m, 'id'),
      createdAt: _date(m, 'createdAt'),
      updatedAt: _date(m, 'updatedAt'),
      archivedAt: _dateN(m, 'archivedAt'),
      syncStatus: _int(m, 'syncStatus'),
      name: _str(m, 'name'),
      lender: _strN(m, 'lender'),
      originalPrincipalMinor: _int(m, 'originalPrincipalMinor'),
      outstandingPrincipalMinor: _int(m, 'outstandingPrincipalMinor'),
      emiMinor: _int(m, 'emiMinor'),
      interestRateBps: _int(m, 'interestRateBps'),
      frequency: _int(m, 'frequency'),
      startDate: _date(m, 'startDate'),
      endDate: _dateN(m, 'endDate'),
      nextPaymentDate: _dateN(m, 'nextPaymentDate'),
      totalPaidMinor: _int(m, 'totalPaidMinor'),
      notes: _strN(m, 'notes'),
    );

CustomFieldsCompanion _customFields(Map<String, Object?> m) =>
    CustomFieldsCompanion(
      id: _str(m, 'id'),
      createdAt: _date(m, 'createdAt'),
      updatedAt: _date(m, 'updatedAt'),
      archivedAt: _dateN(m, 'archivedAt'),
      syncStatus: _int(m, 'syncStatus'),
      name: _str(m, 'name'),
      fieldType: _int(m, 'fieldType'),
      defaultValue: _strN(m, 'defaultValue'),
      required: _bool(m, 'required'),
      visible: _bool(m, 'visible'),
      displayOrder: _int(m, 'displayOrder'),
      allowedValuesJson: _str(m, 'allowedValuesJson'),
      appliesToJson: _str(m, 'appliesToJson'),
    );

CustomFieldValuesCompanion _customFieldValues(Map<String, Object?> m) =>
    CustomFieldValuesCompanion(
      id: _str(m, 'id'),
      createdAt: _date(m, 'createdAt'),
      updatedAt: _date(m, 'updatedAt'),
      archivedAt: _dateN(m, 'archivedAt'),
      syncStatus: _int(m, 'syncStatus'),
      fieldId: _str(m, 'fieldId'),
      ownerId: _str(m, 'ownerId'),
      ownerType: _str(m, 'ownerType'),
      value: _strN(m, 'value'),
    );

ThresholdsCompanion _thresholds(Map<String, Object?> m) => ThresholdsCompanion(
      id: _str(m, 'id'),
      createdAt: _date(m, 'createdAt'),
      updatedAt: _date(m, 'updatedAt'),
      archivedAt: _dateN(m, 'archivedAt'),
      syncStatus: _int(m, 'syncStatus'),
      label: _str(m, 'label'),
      thresholdType: _int(m, 'thresholdType'),
      value: _real(m, 'value'),
      warningPercent: _real(m, 'warningPercent'),
      criticalPercent: _real(m, 'criticalPercent'),
      scopeKey: _strN(m, 'scopeKey'),
      enabled: _bool(m, 'enabled'),
    );

NotificationPreferencesCompanion _notificationPreferences(
  Map<String, Object?> m,
) =>
    NotificationPreferencesCompanion(
      id: _str(m, 'id'),
      createdAt: _date(m, 'createdAt'),
      updatedAt: _date(m, 'updatedAt'),
      archivedAt: _dateN(m, 'archivedAt'),
      syncStatus: _int(m, 'syncStatus'),
      kind: _str(m, 'kind'),
      enabled: _bool(m, 'enabled'),
      timingMinutes: _int(m, 'timingMinutes'),
      quietStartMinute: _intN(m, 'quietStartMinute'),
      quietEndMinute: _intN(m, 'quietEndMinute'),
    );

ExportRecordsCompanion _exportRecords(Map<String, Object?> m) =>
    ExportRecordsCompanion(
      id: _str(m, 'id'),
      createdAt: _date(m, 'createdAt'),
      updatedAt: _date(m, 'updatedAt'),
      archivedAt: _dateN(m, 'archivedAt'),
      syncStatus: _int(m, 'syncStatus'),
      format: _str(m, 'format'),
      scope: _str(m, 'scope'),
      recordCount: _int(m, 'recordCount'),
      filePath: _strN(m, 'filePath'),
    );

// ---- Coercion helpers ------------------------------------------------------
// Non-null helpers: absent key OR explicit null -> Value.absent() (DB default).
// Nullable helpers: absent key -> Value.absent(); explicit null -> Value(null).

int _toInt(Object v) =>
    v is int ? v : (v is num ? v.toInt() : int.parse(v.toString()));
double _toReal(Object v) =>
    v is double ? v : (v is num ? v.toDouble() : double.parse(v.toString()));
bool _toBool(Object v) =>
    v is bool ? v : (v.toString() == 'true' || v.toString() == '1');

/// Drift's `toJson()` serializes DateTime as an integer (via the default
/// serializer), so reconstruct it with the SAME serializer to stay perfectly
/// symmetric with export regardless of drift's internal unit/config. A plain
/// ISO string (e.g. a hand-edited file) is still accepted as a fallback.
DateTime _toDate(Object v) {
  if (v is DateTime) return v;
  if (v is num) {
    return driftRuntimeOptions.defaultSerializer.fromJson<DateTime>(v);
  }
  final s = v.toString();
  final n = num.tryParse(s);
  if (n != null) {
    return driftRuntimeOptions.defaultSerializer.fromJson<DateTime>(n);
  }
  return DateTime.parse(s);
}

Value<String> _str(Map<String, Object?> m, String k) {
  final v = m[k];
  if (!m.containsKey(k) || v == null) return const Value.absent();
  return Value(v.toString());
}

Value<String?> _strN(Map<String, Object?> m, String k) {
  if (!m.containsKey(k)) return const Value.absent();
  final v = m[k];
  return v == null ? const Value<String?>(null) : Value(v.toString());
}

Value<int> _int(Map<String, Object?> m, String k) {
  final v = m[k];
  if (!m.containsKey(k) || v == null) return const Value.absent();
  return Value(_toInt(v));
}

Value<int?> _intN(Map<String, Object?> m, String k) {
  if (!m.containsKey(k)) return const Value.absent();
  final v = m[k];
  return v == null ? const Value<int?>(null) : Value(_toInt(v));
}

Value<double> _real(Map<String, Object?> m, String k) {
  final v = m[k];
  if (!m.containsKey(k) || v == null) return const Value.absent();
  return Value(_toReal(v));
}

Value<bool> _bool(Map<String, Object?> m, String k) {
  final v = m[k];
  if (!m.containsKey(k) || v == null) return const Value.absent();
  return Value(_toBool(v));
}

Value<DateTime> _date(Map<String, Object?> m, String k) {
  final v = m[k];
  if (!m.containsKey(k) || v == null) return const Value.absent();
  return Value(_toDate(v));
}

Value<DateTime?> _dateN(Map<String, Object?> m, String k) {
  if (!m.containsKey(k)) return const Value.absent();
  final v = m[k];
  return v == null ? const Value<DateTime?>(null) : Value(_toDate(v));
}
