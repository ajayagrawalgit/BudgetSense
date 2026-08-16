import 'package:budgetsense/core/theme/app_fonts.dart';
import 'package:budgetsense/core/utils/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FontChoice', () {
    test('system uses the platform default (no bundled family)', () {
      expect(FontChoice.system.fontFamily, isNull);
      expect(FontChoice.system.isHandwritten, isFalse);
      expect(FontChoice.system.sizeFactor, 1.0);
    });

    test('every non-system choice maps to a bundled family', () {
      for (final f in FontChoice.values.where((f) => f != FontChoice.system)) {
        expect(f.fontFamily, isNotNull, reason: '${f.name} needs a family');
        expect(f.fontFamily, isNotEmpty);
      }
    });

    test('handwritten faces are scaled up for readability', () {
      for (final f in FontChoice.values.where((f) => f.isHandwritten)) {
        expect(
          f.sizeFactor,
          greaterThan(1.0),
          reason: '${f.name} should nudge size up',
        );
      }
      // Zen Maru (a UI font) is not treated as handwritten.
      expect(FontChoice.zenMaru.isHandwritten, isFalse);
    });

    test('labels and descriptions are non-empty for all choices', () {
      for (final f in FontChoice.values) {
        expect(f.label, isNotEmpty);
        expect(f.description, isNotEmpty);
        expect(f.sample, isNotEmpty);
      }
    });

    test('font families are unique', () {
      final families = FontChoice.values
          .map((f) => f.fontFamily)
          .whereType<String>()
          .toList();
      expect(families.toSet().length, families.length);
    });

    test('the preview shows a real amount in the app currency symbol', () {
      for (final f in FontChoice.values) {
        expect(f.sample, 'Chai  \u00b7  \u20b912');
        // The symbol, not the word, and not a bare ASCII 'Rs'.
        expect(f.sample, contains(Money.defaultCurrencySymbol));
        expect(f.sample.toLowerCase(), isNot(contains('rupee')));
      }
    });
  });
}
