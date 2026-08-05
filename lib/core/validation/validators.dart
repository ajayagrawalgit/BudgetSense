import '../utils/money.dart';

/// Centralized, reusable validation. UI forms and repositories both call these
/// so validation rules live in exactly one place (DRY).
abstract final class Validators {
  /// A non-empty, reasonably short display name.
  static String? name(String? value, {String field = 'Name'}) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return '$field is required';
    if (v.length > 120) return '$field must be under 120 characters';
    return null;
  }

  /// A positive monetary amount entered by the user.
  static String? amount(String? value,
      {String? locale, bool allowZero = false}) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Amount is required';
    final money = Money.tryParse(v, locale: locale);
    if (money == null) return 'Enter a valid number';
    if (money.isNegative) return 'Amount cannot be negative';
    if (!allowZero && money.isZero) return 'Amount must be greater than zero';
    return null;
  }

  /// A percentage between 0 and 100 (inclusive).
  static String? percentage(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Percentage is required';
    final parsed = double.tryParse(v);
    if (parsed == null) return 'Enter a valid number';
    if (parsed < 0 || parsed > 100) return 'Must be between 0 and 100';
    return null;
  }

  /// An interest rate - allows values above 100 is nonsensical, cap at 100.
  static String? rate(String? value) => percentage(value);

  /// Optional free text with a sane upper bound.
  static String? optionalNotes(String? value, {int max = 2000}) {
    if (value == null) return null;
    if (value.length > max) return 'Note is too long (max $max characters)';
    return null;
  }
}
