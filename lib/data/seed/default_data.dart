import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/enums.dart';
import '../../core/theme/category_icons.dart';
import '../../domain/services/threshold_service.dart';
import '../database/app_database.dart';

/// A starter category that was actually written to the database, carrying its
/// freshly minted (dynamic) id plus the optional threshold percentage that was
/// suggested for it. Callers use this to seed category-scoped thresholds that
/// point at the real id, so nothing ever hard-codes a category name.
typedef SeededCategory = ({String id, String name, double? thresholdPercent});

/// Seeds the sensible starting data offered during onboarding (Section 23):
/// the optional starter categories, a default account, and (via the caller)
/// suggested thresholds.
///
/// Everything seeded here is fully editable afterwards - these are defaults,
/// not hard-coded constants baked into the UI.
class DefaultDataSeeder {
  DefaultDataSeeder(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  /// Idempotent: only seeds when the categories table is empty. Returns the
  /// starter categories it created this run (empty if seeding was skipped).
  Future<List<SeededCategory>> seedIfEmpty() async {
    final existing = await _db.select(_db.categories).get();
    if (existing.isNotEmpty) return const [];
    return seedDefaults();
  }

  /// Writes the starter categories + default account and returns the created
  /// starter categories (with their real ids and suggested threshold percents).
  Future<List<SeededCategory>> seedDefaults() async {
    final now = DateTime.now();

    // Optional starter categories with muted, on-brand colors and material icon
    // points. These are STRICTLY suggestions: fully editable, renamable, and
    // removable. Nothing else in the codebase reads these names, matches on
    // them, or reserves any meaning for them. The `thresholdPercent` here is
    // only a *suggested* max-spend share that, if the user opts in, is seeded as
    // a threshold scoped to the category's dynamic id (never its name) - see
    // `starterCategoryThresholds` below. Users can wipe or replace this set
    // entirely and every screen, threshold and widget continues to work.
    final defaults =
        <({String name, int color, int icon, double? thresholdPercent})>[
      (
        name: 'Needs',
        color: 0xFF7E97A6,
        icon: kCategoryIcons[0].codePoint, // home
        thresholdPercent: 50,
      ),
      (
        name: 'Wants',
        color: 0xFFB07C5E,
        icon: kCategoryIcons[1].codePoint, // star
        thresholdPercent: 30,
      ),
      (
        name: 'Responsibilities',
        color: 0xFF7B7F52,
        icon: kCategoryIcons[2].codePoint, // account_balance
        thresholdPercent: 35,
      ),
    ];

    // Mint ids up front so we can return them for threshold seeding.
    final created = <SeededCategory>[
      for (final d in defaults)
        (id: _uuid.v4(), name: d.name, thresholdPercent: d.thresholdPercent),
    ];

    await _db.batch((b) {
      for (var i = 0; i < defaults.length; i++) {
        final d = defaults[i];
        b.insert(
          _db.categories,
          CategoriesCompanion.insert(
            id: created[i].id,
            name: d.name,
            colorValue: d.color,
            iconCodePoint: d.icon,
            sortOrder: Value(i),
            isDefault: Value(i == 0),
            createdAt: now,
            updatedAt: now,
          ),
        );
      }

      // A single default account so transactions have somewhere to belong.
      b.insert(
        _db.accounts,
        AccountsCompanion.insert(
          id: _uuid.v4(),
          name: 'Cash',
          sortOrder: const Value(0),
          createdAt: now,
          updatedAt: now,
        ),
      );
    });

    return created;
  }

  static String newId() => _uuid.v4();
}

/// Builds category-scoped suggested thresholds for the starter categories the
/// user opted into. Each rule is scoped to the category's real id (dynamic) and
/// merely *labelled* with its current name, so renaming or deleting a category
/// never breaks anything. Only categories that carry a `thresholdPercent`
/// produce a rule; if the user did not seed starter categories, this returns an
/// empty list and no name-based thresholds exist anywhere.
List<ThresholdRule> starterCategoryThresholds(List<SeededCategory> categories) {
  const uuid = Uuid();
  return [
    for (final c in categories)
      if (c.thresholdPercent != null)
        ThresholdRule(
          id: uuid.v4(),
          label: '${c.name} under ${c.thresholdPercent!.round()}%',
          type: ThresholdType.maxPercentage,
          value: c.thresholdPercent!,
          warningPercent: 0.8,
          criticalPercent: 0.95,
          scopeKey: c.id,
        ),
  ];
}
