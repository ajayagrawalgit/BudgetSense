import 'package:budgetsense/features/widgets/spend_graph_footer.dart';
import 'package:flutter_test/flutter_test.dart';

/// The footer picker is pure and name-aware, so we can pin its behaviour.
void main() {
  group('spendFooterMessage', () {
    test('uses the name pool and substitutes the name when given', () {
      final line = spendFooterMessage('Mickey', DateTime(2026, 7, 30));
      expect(line.contains('{name}'), isFalse);
      // Whatever line is chosen, if it was a name line it now shows the name.
      // We assert the token is resolved and the output is non-empty.
      expect(line.isNotEmpty, isTrue);
    });

    test('a name line actually contains the name on a known day', () {
      // Day-of-year 0 (Jan 1) maps to index 0 of the name pool, which uses
      // {name}, so the resolved line must contain the name.
      final line = spendFooterMessage('Mickey', DateTime(2026, 1, 1));
      expect(line.contains('Mickey'), isTrue);
    });

    test('falls back to the plain pool when there is no name', () {
      for (final n in [null, '', '   ']) {
        final line = spendFooterMessage(n, DateTime(2026, 7, 30));
        expect(line.isNotEmpty, isTrue);
        expect(line.contains('{name}'), isFalse);
      }
    });

    test('is deterministic for the same day', () {
      final a = spendFooterMessage('Mickey', DateTime(2026, 7, 30));
      final b = spendFooterMessage('Mickey', DateTime(2026, 7, 30, 23, 59));
      expect(a, b);
    });

    test('never emits an em or en dash', () {
      for (final list in [kFooterLinesWithName, kFooterLinesPlain]) {
        for (final line in list) {
          expect(line.contains('\u2014'), isFalse, reason: line);
          expect(line.contains('\u2013'), isFalse, reason: line);
        }
      }
    });

    test('the two pools together offer at least 100 lines', () {
      expect(
        kFooterLinesWithName.length + kFooterLinesPlain.length,
        greaterThanOrEqualTo(100),
      );
    });
  });
}
