import 'package:budgetsense/core/theme/category_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('categoryIcon resolves a known code point to its const IconData', () {
    final icon = categoryIcon(Icons.restaurant_outlined.codePoint);
    // Must be the exact const instance so icon tree-shaking keeps working.
    expect(identical(icon, Icons.restaurant_outlined), isTrue);
  });

  test('categoryIcon falls back for an unknown code point', () {
    final icon = categoryIcon(0x1);
    expect(identical(icon, kFallbackCategoryIcon), isTrue);
  });

  test('the first twelve icons are pinned in order (seed-data contract)', () {
    // Older imports and seed data reference these by position; they must never
    // move. This is a regression guard for that append-only contract.
    expect(kCategoryIcons[0], Icons.home_outlined);
    expect(kCategoryIcons[1], Icons.star_outline);
    expect(kCategoryIcons[2], Icons.account_balance_outlined);
    expect(kCategoryIcons[3], Icons.restaurant_outlined);
    expect(kCategoryIcons[11], Icons.card_giftcard_outlined);
  });

  test('every icon code point is unique so lookups are deterministic', () {
    final points = kCategoryIcons.map((i) => i.codePoint).toList();
    expect(points.toSet().length, points.length);
  });
}
