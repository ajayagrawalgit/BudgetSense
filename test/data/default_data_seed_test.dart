import 'package:budgetsense/data/database/app_database.dart';
import 'package:budgetsense/data/repositories/threshold_repository.dart';
import 'package:budgetsense/data/seed/default_data.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

AppDatabase _memDb() => AppDatabase.forTesting(NativeDatabase.memory());

/// Guards the NON-NEGOTIABLE rule (Section 12 / 23): Needs / Wants /
/// Responsibilities exist ONLY as optional starter categories. Any threshold
/// tied to them must be scoped to the category's real, dynamic id (never a
/// hard-coded name), and must only be created when the user opts into the
/// starter categories.
void main() {
  test('seeder returns starter categories with dynamic ids and suggested %',
      () async {
    final db = _memDb();
    addTearDown(db.close);

    final created = await DefaultDataSeeder(db).seedIfEmpty();

    expect(created.length, 3);
    // Ids are freshly minted UUIDs, not the category names.
    for (final c in created) {
      expect(c.id.isNotEmpty, isTrue);
      expect(
        const ['needs', 'wants', 'responsibilities'].contains(c.id),
        isFalse,
        reason: 'scope must be a dynamic id, never a bucket name',
      );
    }
    // The starter suggestions carry their percentages as data, not logic.
    final byName = {for (final c in created) c.name: c.thresholdPercent};
    expect(byName['Needs'], 50);
    expect(byName['Wants'], 30);
    expect(byName['Responsibilities'], 35);
  });

  test('seedIfEmpty is idempotent and returns nothing on a seeded db',
      () async {
    final db = _memDb();
    addTearDown(db.close);
    await DefaultDataSeeder(db).seedIfEmpty();
    final second = await DefaultDataSeeder(db).seedIfEmpty();
    expect(second, isEmpty);
  });

  test('opt-in seeds app-level + category-scoped thresholds by id only',
      () async {
    final db = _memDb();
    addTearDown(db.close);

    final created = await DefaultDataSeeder(db).seedIfEmpty();
    final repo = DriftThresholdRepository(db);
    await repo.seedSuggestedIfEmpty(extra: starterCategoryThresholds(created));

    final rules = await repo.getAll();
    final scopes = rules.map((r) => r.scopeKey).toSet();

    // App-level, category-agnostic suggestions are present.
    expect(scopes.contains('investments'), isTrue);
    expect(scopes.contains('unallocated'), isTrue);

    // Category rules are scoped to the REAL created ids, never names.
    final createdIds = created.map((c) => c.id).toSet();
    expect(scopes.containsAll(createdIds), isTrue);
    for (final name in const ['needs', 'wants', 'responsibilities']) {
      expect(
        scopes.contains(name),
        isFalse,
        reason: 'no threshold may be scoped to a hard-coded category name',
      );
    }

    // Each category rule is labelled by the (current) name and is a max %.
    final needsId = created.firstWhere((c) => c.name == 'Needs').id;
    final needsRule = rules.firstWhere((r) => r.scopeKey == needsId);
    expect(needsRule.value, 50);
    expect(needsRule.label, 'Needs under 50%');
  });

  test('no starter categories opted in means no name-based thresholds', () {
    // If the user does not seed starter categories, the helper produces nothing,
    // so Needs/Wants/Responsibilities thresholds simply never exist.
    expect(starterCategoryThresholds(const []), isEmpty);
  });
}
