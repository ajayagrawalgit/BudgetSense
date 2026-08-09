import 'package:intl/intl.dart';

/// A locale-aware, currency-configurable money value stored as integer
/// **minor units** (e.g. cents) to eliminate floating-point rounding errors.
///
/// Never store financial amounts as `double` in the database. Convert at the
/// UI boundary only.
class Money implements Comparable<Money> {
  const Money(this.minorUnits);

  /// Amount in the smallest currency unit (paise, cents, etc.).
  final int minorUnits;

  /// Assume 2 decimal places for the initial release. When zero-decimal
  /// currencies (JPY) are configured this can be looked up per-currency.
  static const int _fractionDigits = 2;
  static const int _scale = 100; // 10 ^ _fractionDigits

  static const Money zero = Money(0);

  /// Build from a major-unit decimal (e.g. 12.34 -> 1234 minor units).
  factory Money.fromMajor(num major) => Money((major * _scale).round());

  /// Parse a user-entered string using the given [locale]'s number format.
  /// Returns null when the input is not a valid non-negative number.
  static Money? tryParse(String raw, {String? locale}) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    // Strip any currency symbols the user may have typed.
    final cleaned = trimmed.replaceAll(RegExp(r'[^\d.,\-]'), '');
    if (cleaned.isEmpty) return null;

    try {
      final format = NumberFormat.decimalPattern(locale);
      final value = format.parse(cleaned);
      if (value.isNaN || value.isInfinite || value < 0) return null;
      return Money.fromMajor(value);
    } catch (_) {
      // Determine the decimal separator for this locale so we can normalize.
      final decSep = NumberFormat.decimalPattern(locale).symbols.DECIMAL_SEP;
      String normalized = cleaned;
      if (decSep == ',') {
        // Locale uses comma as decimal: strip dots (grouping), swap comma.
        normalized = cleaned.replaceAll('.', '').replaceAll(',', '.');
      } else {
        // Locale uses dot as decimal: strip commas (grouping).
        normalized = cleaned.replaceAll(',', '');
      }
      final value = double.tryParse(normalized);
      if (value == null || value.isNaN || value.isInfinite || value < 0) {
        return null;
      }
      return Money.fromMajor(value);
    }
  }

  double get major => minorUnits / _scale;

  bool get isZero => minorUnits == 0;
  bool get isNegative => minorUnits < 0;
  Money get abs => Money(minorUnits.abs());

  Money operator +(Money other) => Money(minorUnits + other.minorUnits);
  Money operator -(Money other) => Money(minorUnits - other.minorUnits);
  Money operator *(num factor) => Money((minorUnits * factor).round());

  /// Ratio of this to [other] as a fraction (0.0 to 1.0+). Returns 0 when
  /// [other] is zero to avoid divide-by-zero blowups.
  double ratioOf(Money other) =>
      other.minorUnits == 0 ? 0 : minorUnits / other.minorUnits;

  /// Percentage of [other] this represents (0 to 100+).
  double percentOf(Money other) => ratioOf(other) * 100;

  /// Format for display with the configured [currencySymbol] and [locale].
  ///
  /// When [compact] is true, delegates to [formatCompact] so tight UI spaces
  /// show "12.3K" style numbers. Exports and imports must always keep the
  /// default `compact: false` to preserve full precision.
  String format({
    String currencySymbol = '₹',
    String? locale,
    bool compact = false,
  }) {
    if (compact) {
      return formatCompact(currencySymbol: currencySymbol, locale: locale);
    }
    final format = NumberFormat.currency(
      locale: locale,
      symbol: currencySymbol,
      decimalDigits: _fractionDigits,
    );
    return format.format(major);
  }

  /// Compact form for tight spaces (e.g. 12.3K). Still currency-aware.
  String formatCompact({String currencySymbol = '₹', String? locale}) {
    final format = NumberFormat.compactCurrency(
      locale: locale,
      symbol: currencySymbol,
    );
    return format.format(major);
  }

  @override
  int compareTo(Money other) => minorUnits.compareTo(other.minorUnits);

  @override
  bool operator ==(Object other) =>
      other is Money && other.minorUnits == minorUnits;

  @override
  int get hashCode => minorUnits.hashCode;

  @override
  String toString() => 'Money($minorUnits)';
}

/// Sum a collection of [Money] safely (empty -> zero).
Money sumMoney(Iterable<Money> values) =>
    values.fold(Money.zero, (acc, m) => acc + m);
