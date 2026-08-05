import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/services/snapshot_service.dart';
import '../database/app_database.dart';
import 'snapshot_tables.dart';

/// The non-destructive, append-only restore engine (Phase 4).
///
/// Guarantees, proven by `test/data/restore_engine_test.dart`:
///   * Existing local records are NEVER updated, replaced, or deleted.
///   * Collections are INSERT-ONLY. Restoring the same snapshot twice produces
///     the same final state as restoring it once (idempotent).
///   * Two legitimate identical-looking records with distinct source ids are
///     both preserved.
///   * An id collision with different content is remapped to a NEW local id;
///     the local record is untouched and every FK to the remapped record is
///     rewritten consistently.
///   * A previously imported source record that changed in a newer snapshot is
///     appended as a separate versioned record, never used to overwrite.
///   * Settings are merged non-destructively; existing values are preserved
///     unless the local value is uninitialized or the key is explicitly chosen.
///   * A failure rolls back every inserted record (single Drift transaction)
///     and never applies settings.
///
/// The engine is split into a MUTATION-FREE preflight/plan phase and a
/// transactional execute phase, so callers (and the UI) can validate and show
/// a plan before anything is written.
class RestoreEngine {
  RestoreEngine(this._db, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final Uuid _uuid;

  static const _hardNullableFks = <String, Set<String>>{
    'transactions': {'categoryId', 'accountId', 'paymentMethodId'},
    'recurringPayments': {'categoryId', 'accountId'},
  };

  /// FK field -> snapshot table it points at. Soft (non-constraint) FKs are
  /// remapped too, so appended records keep pointing at the right rows.
  static const _fkTargets = <String, Map<String, String>>{
    'transactions': {
      'categoryId': 'categories',
      'accountId': 'accounts',
      'paymentMethodId': 'paymentMethods',
      'linkedPaymentId': 'recurringPayments',
      'linkedLoanId': 'loans',
    },
    'recurringPayments': {
      'categoryId': 'categories',
      'accountId': 'accounts',
    },
    'customFieldValues': {
      'fieldId': 'customFields',
    },
  };

  /// Insert order that satisfies every hard FK constraint. The full id map is
  /// built before any insert, so remapping is order-independent; this order is
  /// only needed so the database's referential checks are satisfied row by row.
  static const _insertOrder = <String>[
    'categories',
    'accounts',
    'paymentMethods',
    'customFields',
    'loans',
    'recurringPayments',
    'transactions',
    'customFieldValues',
    'thresholds',
    'notificationPreferences',
    'exportRecords',
  ];

  // ---- Preflight / plan (NO mutations) -------------------------------------

  /// Validates [snapshot] and builds a complete [RestorePlan] without touching
  /// the database. Throws [SnapshotException] on any critical validation
  /// failure so that a corrupt snapshot causes zero mutations.
  Future<RestorePlan> plan(AppSnapshot snapshot) async {
    _validateStructure(snapshot);

    // Existing local ids and content hashes, per snapshot table.
    final existing = <String, Set<String>>{};
    final localHashById = <String, Map<String, String>>{};
    for (final table in kSnapshotTableOrder) {
      final rows = await _readLocalRows(table);
      existing[table] = {for (final r in rows) '${r['id']}'};
      localHashById[table] = {
        for (final r in rows) '${r['id']}': _contentHash(r),
      };
    }

    // Prior import provenance, keyed by "type\u0000sourceId".
    final ledger = await _db.select(_db.importLedger).get();
    final ledgerBySource = <String, List<ImportLedgerData>>{};
    for (final e in ledger) {
      ledgerBySource
          .putIfAbsent(
              '${e.sourceEntityType}\u0000${e.sourceRecordId}', () => [])
          .add(e);
    }
    final liveLocalIds = <String, Set<String>>{
      for (final t in kSnapshotTableOrder) t: {...existing[t]!},
    };

    final items = <PlannedRow>[];
    // idMap[table][sourceId] = resolvedLocalId (for FK remapping).
    final idMap = <String, Map<String, String>>{
      for (final t in kSnapshotTableOrder) t: <String, String>{},
    };

    for (final table in kSnapshotTableOrder) {
      final rows = snapshot.tables[table] ?? const [];
      final seenSourceIds = <String>{};
      for (final row in rows) {
        final sourceId = row['id']?.toString();
        if (sourceId == null || sourceId.isEmpty) {
          throw SnapshotException(
            'A "$table" record is missing its id. The backup is invalid.',
          );
        }
        if (!seenSourceIds.add(sourceId)) {
          throw SnapshotException(
            'Duplicate id "$sourceId" inside "$table". The backup is corrupt.',
          );
        }
        _validateRow(table, row);

        final hash = _contentHash(row);
        final key = '$table\u0000$sourceId';
        final priors = ledgerBySource[key] ?? const [];

        // 1) Already imported, same content, local record still present -> skip.
        final idempotent = priors.any(
          (p) =>
              p.sourceContentHash == hash &&
              (existing[table]?.contains(p.localRecordId) ?? false),
        );
        if (idempotent) {
          items.add(PlannedRow.skip(table, sourceId));
          final prior = priors.firstWhere(
            (p) =>
                p.sourceContentHash == hash &&
                (existing[table]?.contains(p.localRecordId) ?? false),
          );
          idMap[table]![sourceId] = prior.localRecordId;
          continue;
        }

        // 2) Previously imported but content changed (version conflict) OR the
        //    imported local copy was deleted -> append a new versioned record.
        if (priors.isNotEmpty) {
          final newId = _freshId(liveLocalIds);
          items.add(PlannedRow.insert(
            table,
            sourceId,
            newId,
            hash,
            RestoreStatus.version,
          ));
          idMap[table]![sourceId] = newId;
          continue;
        }

        // 3) Never imported before.
        final collides = existing[table]?.contains(sourceId) ?? false;
        if (!collides) {
          // Preserve the source id.
          items.add(PlannedRow.insert(
            table,
            sourceId,
            sourceId,
            hash,
            RestoreStatus.inserted,
          ));
          liveLocalIds[table]!.add(sourceId);
          idMap[table]![sourceId] = sourceId;
          continue;
        }

        // Id collision with an untracked local record.
        final localHash = localHashById[table]?[sourceId];
        if (localHash == hash) {
          // Byte-identical record already present -> skip (still record it so
          // future restores stay idempotent).
          items.add(PlannedRow.skip(
            table,
            sourceId,
            recordLedger: true,
            resolvedId: sourceId,
            hash: hash,
          ));
          idMap[table]![sourceId] = sourceId;
          continue;
        }
        // Same id, different content -> remap to a new id, keep both.
        final newId = _freshId(liveLocalIds);
        items.add(PlannedRow.insert(
          table,
          sourceId,
          newId,
          hash,
          RestoreStatus.remapped,
        ));
        idMap[table]![sourceId] = newId;
      }
    }

    return RestorePlan._(
      snapshot: snapshot,
      items: items,
      idMap: idMap,
      existingLocalIds: existing,
    );
  }

  // ---- Execute (transactional, append-only) --------------------------------

  /// Applies [plan] atomically. All inserts happen in one Drift transaction; on
  /// any failure the transaction rolls back so no partial state remains. This
  /// method NEVER updates or deletes an existing record.
  Future<RestoreExecutionResult> executeCollections(RestorePlan plan) async {
    final inserted = <String, int>{};
    final skipped = <String, int>{};
    final remapped = <String, int>{};
    final versioned = <String, int>{};
    var fkRewrites = 0;

    // Valid target ids for FK checks = pre-existing locals + everything the
    // plan will insert/resolve.
    final validIds = <String, Set<String>>{};
    for (final t in kSnapshotTableOrder) {
      validIds[t] = {
        ...plan.existingLocalIds[t] ?? const {},
        ...plan.idMap[t]?.values ?? const {},
      };
    }

    final ledgerRows = <ImportLedgerCompanion>[];
    final now = DateTime.now();
    final backupId = plan.snapshot.backupId;

    await _db.transaction(() async {
      final bySourceId = <String, Map<String, PlannedRow>>{
        for (final t in kSnapshotTableOrder) t: <String, PlannedRow>{},
      };
      for (final item in plan.items) {
        bySourceId[item.table]![item.sourceId] = item;
      }

      for (final table in _insertOrder) {
        final rows = plan.snapshot.tables[table] ?? const [];
        for (final row in rows) {
          final sourceId = '${row['id']}';
          final item = bySourceId[table]![sourceId]!;

          if (item.status == RestoreStatus.skipped) {
            skipped[table] = (skipped[table] ?? 0) + 1;
            if (item.recordLedger) {
              ledgerRows.add(_ledgerRow(
                backupId,
                table,
                sourceId,
                item.hash!,
                item.resolvedId!,
                'inserted',
                now,
              ));
            }
            continue;
          }

          final resolved = Map<String, Object?>.from(row)
            ..['id'] = item.resolvedId;
          final rewrote =
              _remapForeignKeys(table, resolved, plan.idMap, validIds);
          fkRewrites += rewrote;

          final ok = await insertResolvedRow(_db, table, resolved);
          if (!ok) continue;

          switch (item.status) {
            case RestoreStatus.inserted:
              inserted[table] = (inserted[table] ?? 0) + 1;
            case RestoreStatus.remapped:
              inserted[table] = (inserted[table] ?? 0) + 1;
              remapped[table] = (remapped[table] ?? 0) + 1;
            case RestoreStatus.version:
              inserted[table] = (inserted[table] ?? 0) + 1;
              versioned[table] = (versioned[table] ?? 0) + 1;
            case RestoreStatus.skipped:
              break;
          }

          ledgerRows.add(_ledgerRow(
            backupId,
            table,
            sourceId,
            item.hash!,
            item.resolvedId!,
            switch (item.status) {
              RestoreStatus.remapped => 'remapped',
              RestoreStatus.version => 'version',
              _ => 'inserted',
            },
            now,
          ));
        }
      }

      if (ledgerRows.isNotEmpty) {
        await _db.batch((b) => b.insertAll(_db.importLedger, ledgerRows));
      }
    });

    return RestoreExecutionResult(
      inserted: inserted,
      skipped: skipped,
      remapped: remapped,
      versioned: versioned,
      fkRewrites: fkRewrites,
    );
  }

  int _remapForeignKeys(
    String table,
    Map<String, Object?> row,
    Map<String, Map<String, String>> idMap,
    Map<String, Set<String>> validIds,
  ) {
    var rewrites = 0;
    final targets = _fkTargets[table];
    if (targets != null) {
      targets.forEach((field, targetTable) {
        final value = row[field]?.toString();
        if (value == null || value.isEmpty) return;
        final mapped = idMap[targetTable]?[value];
        if (mapped != null && mapped != value) {
          row[field] = mapped;
          rewrites++;
        }
        // Hard nullable FK pointing at a record present in neither the snapshot
        // nor the local DB: null it to avoid a constraint violation rather than
        // failing the whole restore.
        final resolved = row[field]?.toString();
        final isHard = _hardNullableFks[table]?.contains(field) ?? false;
        if (isHard &&
            resolved != null &&
            !(validIds[targetTable]?.contains(resolved) ?? false)) {
          row[field] = null;
        }
      });
    }
    // Polymorphic owner reference on custom field values.
    if (table == 'customFieldValues') {
      final ownerType = row['ownerType']?.toString();
      final target = switch (ownerType) {
        'transaction' => 'transactions',
        'loan' => 'loans',
        'recurringPayment' || 'payment' => 'recurringPayments',
        _ => null,
      };
      if (target != null) {
        final value = row['ownerId']?.toString();
        final mapped = value == null ? null : idMap[target]?[value];
        if (mapped != null && mapped != value) {
          row['ownerId'] = mapped;
          rewrites++;
        }
      }
    }
    return rewrites;
  }

  // ---- Validation ----------------------------------------------------------

  void _validateStructure(AppSnapshot snapshot) {
    if (snapshot.tables.values.every((r) => r.isEmpty) &&
        snapshot.settings.isEmpty) {
      throw const SnapshotException(
        'This backup contains no data or settings to restore.',
      );
    }
    if (snapshot.version > AppSnapshot.currentVersion) {
      throw SnapshotException(
        'This backup was made by a newer version of BudgetSense '
        '(format v${snapshot.version}). Update the app, then restore.',
      );
    }
  }

  void _validateRow(String table, Map<String, Object?> row) {
    // Monetary integrity: minor-unit money columns must be finite integers.
    const moneyCols = <String, List<String>>{
      'transactions': ['amountMinor'],
      'recurringPayments': ['amountMinor'],
      'loans': [
        'originalPrincipalMinor',
        'outstandingPrincipalMinor',
        'emiMinor',
        'totalPaidMinor',
      ],
    };
    for (final col in moneyCols[table] ?? const []) {
      final v = row[col];
      if (v == null) continue;
      if (v is num && (v.isNaN || v.isInfinite)) {
        throw SnapshotException(
          'Invalid amount in "$table" (not a finite number). '
          'The backup is corrupt.',
        );
      }
    }
    // Real-valued threshold fields must be finite.
    if (table == 'thresholds') {
      for (final col in ['value', 'warningPercent', 'criticalPercent']) {
        final v = row[col];
        if (v is num && (v.isNaN || v.isInfinite)) {
          throw const SnapshotException(
            'Invalid threshold value in the backup (not finite).',
          );
        }
      }
    }
  }

  // ---- Helpers -------------------------------------------------------------

  Future<List<Map<String, Object?>>> _readLocalRows(String table) async {
    final all = await readAllTables(_db);
    return all[table] ?? const [];
  }

  ImportLedgerCompanion _ledgerRow(
    String backupId,
    String table,
    String sourceId,
    String hash,
    String localId,
    String status,
    DateTime now,
  ) =>
      ImportLedgerCompanion.insert(
        id: _uuid.v4(),
        backupId: backupId,
        sourceEntityType: table,
        sourceRecordId: sourceId,
        sourceContentHash: hash,
        localRecordId: localId,
        importedAt: now,
        conflictStatus: Value(status),
      );

  String _freshId(Map<String, Set<String>> liveLocalIds) {
    while (true) {
      final id = _uuid.v4();
      final clash = liveLocalIds.values.any((s) => s.contains(id));
      if (!clash) return id;
    }
  }

  /// Canonical, stable content hash of a row, ignoring the `id`. Symmetric
  /// between exported rows and Drift `toJson()` rows (both encode DateTime as
  /// ints), so re-importing the same record hashes identically. FNV-1a/64 over
  /// a key-sorted JSON encoding - deterministic across process restarts and
  /// dependency-free.
  static String _contentHash(Map<String, Object?> row) {
    final keys = row.keys.where((k) => k != 'id').toList()..sort();
    final buf = StringBuffer();
    for (final k in keys) {
      buf
        ..write(k)
        ..write('=')
        ..write(jsonEncode(row[k]))
        ..write('\u0001');
    }
    return _fnv1a64(buf.toString());
  }

  static String _fnv1a64(String s) {
    // 64-bit FNV-1a using BigInt to stay exact on the web too.
    final bytes = utf8.encode(s);
    var hash = BigInt.parse('14695981039346656037');
    final prime = BigInt.parse('1099511628211');
    final mask = (BigInt.one << 64) - BigInt.one;
    for (final b in bytes) {
      hash = (hash ^ BigInt.from(b)) & mask;
      hash = (hash * prime) & mask;
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }
}

/// A single row's restore decision (mutation-free plan output).
enum RestoreStatus { inserted, remapped, version, skipped }

class PlannedRow {
  const PlannedRow._(
    this.table,
    this.sourceId,
    this.status, {
    this.resolvedId,
    this.hash,
    this.recordLedger = false,
  });

  factory PlannedRow.insert(
    String table,
    String sourceId,
    String resolvedId,
    String hash,
    RestoreStatus status,
  ) =>
      PlannedRow._(
        table,
        sourceId,
        status,
        resolvedId: resolvedId,
        hash: hash,
      );

  factory PlannedRow.skip(
    String table,
    String sourceId, {
    bool recordLedger = false,
    String? resolvedId,
    String? hash,
  }) =>
      PlannedRow._(
        table,
        sourceId,
        RestoreStatus.skipped,
        recordLedger: recordLedger,
        resolvedId: resolvedId,
        hash: hash,
      );

  final String table;
  final String sourceId;
  final RestoreStatus status;
  final String? resolvedId;
  final String? hash;
  final bool recordLedger;
}

/// A complete, reviewable, mutation-free restore plan.
class RestorePlan {
  const RestorePlan._({
    required this.snapshot,
    required this.items,
    required this.idMap,
    required this.existingLocalIds,
  });

  final AppSnapshot snapshot;
  final List<PlannedRow> items;
  final Map<String, Map<String, String>> idMap;
  final Map<String, Set<String>> existingLocalIds;

  int _count(RestoreStatus s) => items.where((i) => i.status == s).length;

  int get toInsert => _count(RestoreStatus.inserted);
  int get toRemap => _count(RestoreStatus.remapped);
  int get toVersion => _count(RestoreStatus.version);
  int get toSkip => _count(RestoreStatus.skipped);

  /// Per-table counts of new rows that will be inserted (any non-skip status).
  Map<String, int> get insertCountsByTable {
    final out = <String, int>{};
    for (final i in items) {
      if (i.status == RestoreStatus.skipped) continue;
      out[i.table] = (out[i.table] ?? 0) + 1;
    }
    return out;
  }
}

/// The result of executing the collection portion of a restore.
class RestoreExecutionResult {
  const RestoreExecutionResult({
    required this.inserted,
    required this.skipped,
    required this.remapped,
    required this.versioned,
    required this.fkRewrites,
  });

  final Map<String, int> inserted;
  final Map<String, int> skipped;
  final Map<String, int> remapped;
  final Map<String, int> versioned;
  final int fkRewrites;

  int get totalInserted => inserted.values.fold(0, (a, b) => a + b);
  int get totalSkipped => skipped.values.fold(0, (a, b) => a + b);
  int get totalRemapped => remapped.values.fold(0, (a, b) => a + b);
  int get totalVersioned => versioned.values.fold(0, (a, b) => a + b);
}
