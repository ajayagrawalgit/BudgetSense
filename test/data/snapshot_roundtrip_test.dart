import 'dart:convert';

import 'package:budgetsense/core/theme/app_colors.dart';
import 'package:budgetsense/core/theme/app_fonts.dart';
import 'package:budgetsense/data/database/app_database.dart';
import 'package:budgetsense/data/snapshot/app_snapshot_service.dart';
import 'package:budgetsense/data/snapshot/snapshot_codecs.dart';
import 'package:budgetsense/data/snapshot/snapshot_tables.dart';
import 'package:budgetsense/domain/services/snapshot_service.dart';
import 'package:budgetsense/features/settings/settings_state.dart';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_database.dart';

AppDatabase _memDb() => newTestDatabase();

/// A representative settings blob covering unicode, enums, booleans, ints, empty
/// strings, and null (localeCode) so the codecs are exercised on every scalar.
Map<String, Object?> _settings() => const SettingsState()
    .copyWith(
      userName: 'Café ☕ René',
      userNickname: 'R',
      userAge: 30,
      userPhone: '',
      currencySymbol: '₹',
      themeVariant: AppThemeVariant.dark,
      accent: AccentPreset.plum,
      fontChoice: FontChoice.caveat,
      numberFormatCompact: true,
      appLockEnabled: true,
      screenSecurityEnabled: false,
    )
    .toMap();

/// Seeds one representative row per table, deliberately including nulls,
/// unicode, embedded quotes/commas/newlines, negatives, and doubles.
Future<void> _seed(AppDatabase db) async {
  final t = DateTime.utc(2026, 7, 27, 9, 30, 15);
  await db.into(db.categories).insert(
        CategoriesCompanion.insert(
          id: 'cat-1',
          createdAt: t,
          updatedAt: t,
          name: 'Café ☕, "essentials"',
          colorValue: 0xFF7E97A6,
          iconCodePoint: 0xe000,
          semanticBucket: const Value('needs'),
          isDefault: const Value(true),
        ),
      );
  await db.into(db.categories).insert(
        CategoriesCompanion.insert(
          id: 'cat-2',
          createdAt: t,
          updatedAt: t,
          name: 'Wants',
          colorValue: 0xFFB07C5E,
          iconCodePoint: 0xe001,
          archivedAt: Value(t),
        ),
      );
  await db.into(db.accounts).insert(
        AccountsCompanion.insert(
          id: 'acc-1',
          createdAt: t,
          updatedAt: t,
          name: 'Cash',
        ),
      );
  await db.into(db.paymentMethods).insert(
        PaymentMethodsCompanion.insert(
          id: 'pm-1',
          createdAt: t,
          updatedAt: t,
          name: 'UPI',
        ),
      );
  await db.into(db.transactions).insert(
        TransactionsCompanion.insert(
          id: 'txn-1',
          createdAt: t,
          updatedAt: t,
          type: 0,
          name: 'Coffee, "the good kind"\nwith notes',
          amountMinor: 4500,
          occurredAt: t,
          categoryId: const Value('cat-1'),
          merchant: const Value(null),
          notes: const Value('Line1\nLine2, with ₹ and "quotes"'),
          tagsJson: const Value('["a","b, c"]'),
        ),
      );
  await db.into(db.transactions).insert(
        TransactionsCompanion.insert(
          id: 'txn-2',
          createdAt: t,
          updatedAt: t,
          type: 1,
          name: 'Salary',
          amountMinor: 5000000,
          occurredAt: t,
          incomeType: const Value(0),
        ),
      );
  await db.into(db.recurringPayments).insert(
        RecurringPaymentsCompanion.insert(
          id: 'rp-1',
          createdAt: t,
          updatedAt: t,
          name: 'Netflix',
          amountMinor: 64900,
          kind: 5,
          frequency: 3,
          startDate: t,
          nextDueDate: t,
          autoAddTransaction: const Value(true),
          reminderEnabled: const Value(false),
        ),
      );
  await db.into(db.loans).insert(
        LoansCompanion.insert(
          id: 'loan-1',
          createdAt: t,
          updatedAt: t,
          name: 'Car loan',
          originalPrincipalMinor: 100000000,
          outstandingPrincipalMinor: 75000000,
          emiMinor: 2500000,
          frequency: 3,
          startDate: t,
          interestRateBps: const Value(875),
          // Non-default on purpose: a flag left at its default would still
          // "round-trip" even if it were never serialized at all.
          showInUpcoming: const Value(true),
        ),
      );
  await db.into(db.customFields).insert(
        CustomFieldsCompanion.insert(
          id: 'cf-1',
          createdAt: t,
          updatedAt: t,
          name: 'Mood',
          fieldType: 7,
          allowedValuesJson: const Value('["happy","meh"]'),
          required: const Value(true),
        ),
      );
  await db.into(db.customFieldValues).insert(
        CustomFieldValuesCompanion.insert(
          id: 'cfv-1',
          createdAt: t,
          updatedAt: t,
          fieldId: 'cf-1',
          ownerId: 'txn-1',
          ownerType: 'transaction',
          value: const Value(null),
        ),
      );
  await db.into(db.thresholds).insert(
        ThresholdsCompanion.insert(
          id: 'th-1',
          createdAt: t,
          updatedAt: t,
          label: 'Wants under 30%',
          thresholdType: 0,
          value: 30.5,
          warningPercent: const Value(0.8),
          criticalPercent: const Value(0.95),
        ),
      );
  await db.into(db.notificationPreferences).insert(
        NotificationPreferencesCompanion.insert(
          id: 'np-1',
          createdAt: t,
          updatedAt: t,
          kind: 'payment_due',
        ),
      );
  await db.into(db.exportRecords).insert(
        ExportRecordsCompanion.insert(
          id: 'ex-1',
          createdAt: t,
          updatedAt: t,
          format: 'csv',
          scope: 'all',
          recordCount: const Value(12),
        ),
      );
}

AppSnapshotService _service(
  AppDatabase db,
  Map<String, Object?> settings,
  void Function(Map<String, Object?>) onWrite,
) =>
    AppSnapshotService(
      db,
      readSettings: () async => settings,
      writeSettings: (s) async => onWrite(s),
    );

void main() {
  group('AppSnapshot round-trip (JSON / CSV / XML)', () {
    for (final format in SnapshotFormat.values) {
      test('${format.label}: every table and setting survives export+import',
          () async {
        final src = _memDb();
        addTearDown(src.close);
        await _seed(src);
        final settings = _settings();

        final exporter = _service(src, settings, (_) {});
        final export = await exporter.export(format);

        // The format is self-identifying.
        expect(SnapshotCodecs.detectFormat(export.bytes), format);
        expect(export.format, format);
        expect(export.recordCount, 13); // 2+1+1+2+1+1+1+1+1+1+1

        // Import into a brand-new database.
        final dst = _memDb();
        addTearDown(dst.close);
        Map<String, Object?>? written;
        final importer = _service(dst, const {}, (s) => written = s);
        final result = await importer.importBytes(export.bytes);

        expect(result.format, format);
        expect(result.settingsApplied, isTrue);
        expect(result.totalRows, 13);

        // Settings survive verbatim.
        expect(written == null, isFalse);
        expect(written!['userName'], 'Café ☕ René');
        expect(written!['themeVariant'], 'dark');
        expect(written!['accent'], 'plum');
        expect(written!['fontChoice'], 'caveat');
        expect(written!['numberFormatCompact'], true);
        expect(written!['screenSecurityEnabled'], false);
        expect(written!['userAge'], 30);
        expect(written!['localeCode'], null);

        // Every table matches the source exactly (order-preserving, deep).
        final before = await readAllTables(src);
        final after = await readAllTables(dst);
        expect(after, equals(before));

        // Spot-check the tricky transaction values explicitly.
        final txn1 =
            after['transactions']!.firstWhere((r) => r['id'] == 'txn-1');
        expect(txn1['merchant'], null);
        expect(txn1['notes'], 'Line1\nLine2, with ₹ and "quotes"');
        expect(txn1['name'], 'Coffee, "the good kind"\nwith notes');
        expect(txn1['tagsJson'], '["a","b, c"]');
        expect(txn1['amountMinor'], 4500);
        final th = after['thresholds']!.first;
        expect(th['value'], 30.5);
      });
    }
  });

  test('detectFormat recognises each format and rejects noise', () {
    expect(
      SnapshotCodecs.detectFormat(utf8.encode('{"app":"BudgetSense"}')),
      SnapshotFormat.json,
    );
    expect(
      SnapshotCodecs.detectFormat(utf8.encode('#BUDGETSENSE,3\n')),
      SnapshotFormat.csv,
    );
    expect(
      SnapshotCodecs.detectFormat(utf8.encode('<?xml version="1.0"?>')),
      SnapshotFormat.xml,
    );
    expect(
      SnapshotCodecs.detectFormat(utf8.encode('   <budgetsense/>')),
      SnapshotFormat.xml,
    );
    expect(SnapshotCodecs.detectFormat(utf8.encode('hello world')), null);
    expect(SnapshotCodecs.detectFormat(const []), null);
  });

  test('foreign JSON (e.g. Paisa) is rejected, never silently imported',
      () async {
    final db = _memDb();
    addTearDown(db.close);
    final importer = _service(db, const {}, (_) {});
    final paisaLike = utf8.encode(
      jsonEncode(
        {
          'appName': 'Paisa',
          'expenses': [
            {'name': 'x', 'amount': 1.0, 'type': 0},
          ],
        },
      ),
    );
    await expectLater(
      importer.importBytes(paisaLike),
      throwsA(isA<SnapshotException>()),
    );
    // Nothing was written.
    expect(await db.select(db.transactions).get(), isEmpty);
  });

  test('legacy DB-only backup JSON (v2, no settings) still restores', () async {
    final dst = _memDb();
    addTearDown(dst.close);
    // Shape produced by LocalBackupService: version + top-level table keys.
    final legacy = utf8.encode(
      jsonEncode(
        {
          'version': 2,
          'exportedAt': DateTime.utc(2026, 1, 1).toIso8601String(),
          'categories': [
            {
              'id': 'lc-1',
              'createdAt': DateTime.utc(2026).toIso8601String(),
              'updatedAt': DateTime.utc(2026).toIso8601String(),
              'archivedAt': null,
              'syncStatus': 0,
              'name': 'Legacy',
              'colorValue': 0xFF000000,
              'iconCodePoint': 0xe000,
              'sortOrder': 0,
              'isDefault': false,
              'semanticBucket': '',
            },
          ],
        },
      ),
    );
    var wroteSettings = false;
    final importer = _service(dst, const {}, (_) => wroteSettings = true);
    final result = await importer.importBytes(legacy);
    expect(result.tableRows['categories'], 1);
    expect(
        result.settingsApplied, isFalse); // no settings block in legacy files
    expect(wroteSettings, isFalse);
    final cats = await dst.select(dst.categories).get();
    expect(cats.single.name, 'Legacy');
  });

  test('forward-compatible: unknown column + missing future column are safe',
      () async {
    final dst = _memDb();
    addTearDown(dst.close);
    final t = DateTime.utc(2026).toIso8601String();
    // A transaction row carrying an unknown "futureColumn" and omitting
    // "syncStatus" (as if that column did not exist when the file was written).
    // Neither should break the import. Uses the CURRENT envelope version so the
    // future-version guard is exercised separately.
    final future = utf8.encode(
      jsonEncode(
        {
          'app': 'BudgetSense',
          'snapshot': 4,
          'settings': {'userName': 'X', 'brandNewSetting': 'ignored'},
          'data': {
            'categories': [
              {
                'id': 'c1',
                'createdAt': t,
                'updatedAt': t,
                'name': 'C',
                'colorValue': 1,
                'iconCodePoint': 2,
                'futureColumn': 'whatever',
              },
            ],
          },
        },
      ),
    );
    Map<String, Object?>? written;
    final importer = _service(dst, const {}, (s) => written = s);
    final result = await importer.importBytes(future);
    expect(result.tableRows['categories'], 1);
    final cat = (await dst.select(dst.categories).get()).single;
    expect(cat.name, 'C');
    expect(cat.syncStatus, 0); // DB default filled the missing column
    // Known settings merge in; unknown keys are dropped by the non-destructive
    // merge (only registered, mergeable keys are applied).
    expect(written!['userName'], 'X');
    expect(written!.containsKey('brandNewSetting'), isFalse);
  });

  test('unsupported FUTURE envelope version is rejected with zero mutations',
      () async {
    final dst = _memDb();
    addTearDown(dst.close);
    final t = DateTime.utc(2026).toIso8601String();
    final future = utf8.encode(
      jsonEncode(
        {
          'app': 'BudgetSense',
          'snapshot': 999,
          'settings': {'userName': 'X'},
          'data': {
            'categories': [
              {
                'id': 'c1',
                'createdAt': t,
                'updatedAt': t,
                'name': 'C',
                'colorValue': 1,
                'iconCodePoint': 2,
              },
            ],
          },
        },
      ),
    );
    var wroteSettings = false;
    final importer = _service(dst, const {}, (_) => wroteSettings = true);
    await expectLater(
      importer.importBytes(future),
      throwsA(isA<SnapshotException>()),
    );
    expect(await dst.select(dst.categories).get(), isEmpty);
    expect(wroteSettings, isFalse);
  });
}
