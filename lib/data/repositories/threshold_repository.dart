import 'package:drift/drift.dart';

import '../../domain/services/threshold_service.dart';
import '../database/app_database.dart';
import '../mappers/entity_mappers.dart';

/// Repository for persisted, editable threshold rules (Section 11). The
/// suggested defaults are seeded once; everything is user-editable afterwards.
abstract interface class ThresholdRepository {
  Stream<List<ThresholdRule>> watchAll();
  Future<List<ThresholdRule>> getAll();
  Future<void> upsert(ThresholdRule rule);
  Future<void> setEnabled(String id, {required bool enabled});
  Future<void> delete(String id);

  /// Seeds the category-agnostic suggested defaults once (only if the table is
  /// empty). [extra] carries any category-scoped starter thresholds the user
  /// opted into, each already scoped to a real category id.
  Future<void> seedSuggestedIfEmpty({List<ThresholdRule> extra});
}

class DriftThresholdRepository implements ThresholdRepository {
  DriftThresholdRepository(this._db);
  final AppDatabase _db;

  @override
  Stream<List<ThresholdRule>> watchAll() {
    final q = _db.select(_db.thresholds)
      ..orderBy([(t) => OrderingTerm.asc(t.label)]);
    return q.watch().map((rows) => rows.map(ThresholdMapper.toRule).toList());
  }

  @override
  Future<List<ThresholdRule>> getAll() async {
    final rows = await _db.select(_db.thresholds).get();
    return rows.map(ThresholdMapper.toRule).toList();
  }

  @override
  Future<void> upsert(ThresholdRule rule) async {
    final existing = await (_db.select(_db.thresholds)
          ..where((t) => t.id.equals(rule.id)))
        .getSingleOrNull();
    await _db.into(_db.thresholds).insertOnConflictUpdate(
          ThresholdMapper.toCompanion(
            rule,
            now: DateTime.now(),
            createdAt: existing?.createdAt,
          ),
        );
  }

  @override
  Future<void> setEnabled(String id, {required bool enabled}) =>
      (_db.update(_db.thresholds)..where((t) => t.id.equals(id))).write(
        ThresholdsCompanion(
          enabled: Value(enabled),
          updatedAt: Value(DateTime.now()),
        ),
      );

  @override
  Future<void> delete(String id) =>
      (_db.delete(_db.thresholds)..where((t) => t.id.equals(id))).go();

  @override
  Future<void> seedSuggestedIfEmpty(
      {List<ThresholdRule> extra = const []}) async {
    final existing = await _db.select(_db.thresholds).get();
    if (existing.isNotEmpty) return;
    final now = DateTime.now();
    await _db.batch((b) {
      for (final rule in [...SuggestedThresholds.defaults(), ...extra]) {
        b.insert(
          _db.thresholds,
          ThresholdMapper.toCompanion(rule, now: now),
        );
      }
    });
  }
}
