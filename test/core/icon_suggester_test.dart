import 'package:budgetsense/core/theme/category_icons.dart';
import 'package:budgetsense/core/utils/icon_suggester.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Splitwise-style icon auto-detection. Guarantees the suggestions are
/// real, in-library icons and that the keyword matching behaves sensibly.
void main() {
  test('empty / whitespace input suggests nothing', () {
    expect(IconSuggester.suggestCodePoint(''), isNull);
    expect(IconSuggester.suggestCodePoint('   '), isNull);
  });

  test('detects common Indian expense keywords', () {
    final cases = <String, IconData>{
      'BigBasket groceries': Icons.local_grocery_store_outlined,
      'Morning coffee at CCD': Icons.local_cafe_outlined,
      'Uber to office': Icons.local_taxi_outlined,
      'IndianOil petrol': Icons.local_gas_station_outlined,
      'Swiggy food order': Icons.restaurant_outlined,
      'Netflix subscription': Icons.live_tv_outlined,
      'Cult gym membership': Icons.fitness_center_outlined,
      'Nippon SIP': Icons.savings_outlined,
      'LIC insurance premium': Icons.policy_outlined,
      'Jio recharge': Icons.sim_card_outlined,
      'Apollo pharmacy medicine': Icons.local_pharmacy_outlined,
      'Myntra shopping': Icons.checkroom_outlined,
      'Monthly rent': Icons.home_outlined,
      'Home loan EMI': Icons.request_quote_outlined,
      'School fees': Icons.school_outlined,
      'ISKCON donation': Icons.volunteer_activism_outlined,
    };
    cases.forEach((text, icon) {
      expect(
        IconSuggester.suggestCodePoint(text),
        icon.codePoint,
        reason: '"$text" should map to the expected icon',
      );
    });
  });

  test('every suggested code point resolves to a real library icon', () {
    final libraryPoints = kCategoryIcons.map((i) => i.codePoint).toSet();
    for (final probe in [
      'grocery',
      'coffee',
      'uber',
      'rent',
      'sip',
      'gym',
      'netflix',
      'insurance',
      'pharmacy',
      'school',
      'donation',
      'recharge',
    ]) {
      final cp = IconSuggester.suggestCodePoint(probe);
      expect(cp, isNotNull, reason: '"$probe" should match a rule');
      expect(
        libraryPoints,
        contains(cp),
        reason: 'suggestion for "$probe" must be in kCategoryIcons',
      );
    }
  });

  test('searchCodePoints returns in-library matches and empty for no match',
      () {
    final libraryPoints = kCategoryIcons.map((i) => i.codePoint).toSet();
    final hits = IconSuggester.searchCodePoints('food');
    expect(hits, isNotEmpty);
    expect(libraryPoints.containsAll(hits), isTrue);
    expect(IconSuggester.searchCodePoints('zzzzznotathing'), isEmpty);
    expect(IconSuggester.searchCodePoints(''), isEmpty);
  });

  test('the icon library exposes at least 100 distinct icons', () {
    final distinct = kCategoryIcons.map((i) => i.codePoint).toSet();
    expect(distinct.length, greaterThanOrEqualTo(100));
  });
}
