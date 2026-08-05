import 'package:budgetsense/features/widgets/widget_sync.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the home-screen widget privacy behaviour (2.6): when app-lock is on,
/// every monetary figure must be hidden, while non-sensitive metadata stays so
/// the widget still shows which month it belongs to.
void main() {
  test('maskSensitive hides every financial figure but keeps metadata', () {
    final payload = {
      'currencySymbol': '₹',
      'monthLabel': 'July 2026',
      'balance': '1,200.00',
      'income': '5,000.00',
      'spend': '3,800.00',
      'invested': '1,000.00',
      'catCount': '3',
      'cat1Label': 'Groceries',
      'cat1Value': '2,000.00',
      'cat1Pct': '100',
      'cat2Label': 'Fun',
      'cat2Value': '1,000.00',
      'cat2Pct': '50',
      'cat3Label': 'Rent',
      'cat3Value': '800.00',
      'cat3Pct': '40',
      'cat4Label': 'Travel',
      'cat4Value': '300.00',
      'cat4Pct': '15',
      'savingsRate': '20%',
      'investmentRate': '20%',
      'avgDailySpend': '126.00',
      'projectedBalance': '900.00',
      'savingsRateNum': '20',
      'investmentRateNum': '20',
      'runwayNote': 'At this pace you will end July around 900.00.',
      'nextDueAmount': '499.00',
      'expenseAverage': '210.00',
      'biggestAmount': '1,500.00',
      'updatedAt': '2026-07-24T10:00:00.000',
      'spendGrid': '1234012',
      'footerText': 'Nice and steady.',
    };

    final masked = maskSensitive(payload);

    // Every money-bearing field is hidden.
    for (final key in kSensitiveWidgetKeys) {
      expect(
        masked[key],
        '••••',
        reason: '$key must be masked',
      );
    }
    // Metadata is preserved so the widget stays recognisable.
    expect(masked['currencySymbol'], '₹');
    expect(masked['monthLabel'], 'July 2026');
    expect(masked['updatedAt'], '2026-07-24T10:00:00.000');
    // Category names are labels, not figures, so they stay visible.
    expect(masked['cat1Label'], 'Groceries');
    expect(masked['catCount'], '3');
    // But their amounts and percentages are hidden.
    expect(masked['cat1Value'], '••••');
    expect(masked['cat1Pct'], '••••');
    // The spend grid reveals your day-by-day shape, so it is masked.
    expect(masked['spendGrid'], '••••');
    // The motivating footer line is not a figure, so it stays visible.
    expect(masked['footerText'], 'Nice and steady.');
    // No keys are added or dropped by masking.
    expect(masked.keys.toSet(), payload.keys.toSet());
  });

  test('sensitive and metadata key sets never overlap', () {
    const metadataKeys = {'currencySymbol', 'monthLabel', 'updatedAt'};
    expect(kSensitiveWidgetKeys.intersection(metadataKeys), isEmpty);
  });
}
