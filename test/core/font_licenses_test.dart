import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

/// The SIL Open Font License requires the notice to be distributed with the
/// fonts. `main.dart` loads this asset into Flutter's licence registry, so if
/// the asset goes missing or loses a copyright line, the shipped app quietly
/// stops carrying attribution it is obliged to carry.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bundled font licence asset carries the OFL and every copyright line',
      () async {
    final text = await rootBundle.loadString('assets/fonts/OFL.txt');

    expect(text, contains('SIL OPEN FONT LICENSE Version 1.1'));

    const copyrightHolders = <String>[
      'The Zen Maru Gothic Authors',
      'The Caveat Project Authors',
      'Patrick Wagesreiter',
      'Huerta Tipografica',
      'Kimberly Geswein',
    ];
    for (final holder in copyrightHolders) {
      expect(text, contains(holder), reason: 'missing notice for $holder');
    }
  });
}
