import 'package:budgetsense/core/utils/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Money', () {
    test('stores exact minor units without float drift', () {
      final a = Money.fromMajor(0.1);
      final b = Money.fromMajor(0.2);
      expect((a + b).minorUnits, 30); // 0.30 exactly, no 0.30000000004
    });

    test('fromMajor rounds to nearest minor unit', () {
      expect(Money.fromMajor(12.345).minorUnits, 1235);
      expect(Money.fromMajor(12.344).minorUnits, 1234);
    });

    test('tryParse handles plain decimals', () {
      expect(Money.tryParse('12.34')!.minorUnits, 1234);
      expect(Money.tryParse('  5 ')!.minorUnits, 500);
    });

    test('tryParse rejects garbage', () {
      expect(Money.tryParse('abc'), isNull);
      expect(Money.tryParse(''), isNull);
    });

    test('tryParse rejects amounts with more precision than the currency', () {
      // Silently rounding 10.999 to 11.00 would record money the user never
      // typed, and every total downstream would inherit that invention. The
      // input is rejected so the UI can ask them to fix it instead.
      expect(Money.tryParse('10.999'), isNull);
      expect(Money.tryParse('1234.567'), isNull);
      expect(Money.tryParse('0.005'), isNull);
      expect(Money.tryParse('99.994'), isNull);
    });

    test('tryParse still accepts every legitimate amount', () {
      expect(Money.tryParse('0')!.minorUnits, 0);
      expect(Money.tryParse('0.1')!.minorUnits, 10);
      expect(Money.tryParse('5.00')!.minorUnits, 500);
      expect(Money.tryParse('100')!.minorUnits, 10000);
      expect(Money.tryParse('99.99')!.minorUnits, 9999);
    });

    test('tryParse rejects negative input', () {
      expect(Money.tryParse('-5'), isNull);
      expect(Money.tryParse('-0.01'), isNull);
    });

    test('tryParse handles Indian lakh grouping', () {
      expect(
          Money.tryParse('1,00,000.50', locale: 'en_IN')!.minorUnits, 10000050);
    });

    test('summing many amounts never drifts', () {
      // 1000 x 0.07 is exactly 70.00. Floating point would not guarantee this.
      final values = List.generate(1000, (_) => Money.fromMajor(0.07));
      expect(sumMoney(values).minorUnits, 7000);
    });

    test('arithmetic operators', () {
      expect((const Money(500) - const Money(200)).minorUnits, 300);
      expect((const Money(100) * 3).minorUnits, 300);
    });

    test('percentOf and ratioOf are divide-by-zero safe', () {
      expect(const Money(50).percentOf(Money.zero), 0);
      expect(const Money(50).ratioOf(const Money(200)), 0.25);
      expect(const Money(50).percentOf(const Money(200)), 25);
    });

    test('sumMoney of empty is zero', () {
      expect(sumMoney(const <Money>[]), Money.zero);
      expect(sumMoney([const Money(100), const Money(250)]).minorUnits, 350);
    });

    test('formats with currency symbol', () {
      final formatted =
          const Money(123456).format(currencySymbol: r'$', locale: 'en_US');
      expect(formatted, contains('1,234.56'));
    });

    test('compact flag switches to abbreviated form', () {
      const m = Money(1234500); // 12,345.00 major
      final full = m.format(currencySymbol: r'$', locale: 'en_US');
      final compact =
          m.format(currencySymbol: r'$', locale: 'en_US', compact: true);
      expect(full, contains('12,345'));
      // Compact drops the thousands grouping in favour of a K/thousand suffix.
      expect(compact, isNot(contains('12,345')));
      expect(compact.toUpperCase(), contains('K'));
    });
  });
}
