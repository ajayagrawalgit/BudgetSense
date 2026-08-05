import 'dart:developer' as developer;

/// The one place the app writes diagnostic logs.
///
/// User-facing copy should stay warm and vague ("That export didn't go
/// through"); the messy detail (exceptions, stack traces, URLs) belongs here,
/// in the developer console, never in a SnackBar. Routing every log through a
/// single helper keeps that separation honest and makes it trivial to swap in a
/// real crash reporter later.
abstract final class AppLog {
  static const String _name = 'BudgetSense';

  /// Record a handled error with its detail for developers, while the caller
  /// shows the user something kind.
  static void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    developer.log(
      message,
      name: _name,
      level: 1000, // SEVERE
      error: error,
      stackTrace: stackTrace,
    );
  }
}
