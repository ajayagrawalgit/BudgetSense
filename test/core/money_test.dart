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
