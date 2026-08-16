import 'package:shared_preferences/shared_preferences.dart';

/// Device-local record of which threshold alerts have already been delivered.
///
/// Deliberately NOT part of [SettingsState]: settings travel in backups, and
/// alert receipts must not. Restoring last year's snapshot onto a new phone
/// should never silence this month's warnings, and a backup taken mid-month
/// should never re-arm alerts the user has already seen. This is provenance
/// about one device's notification tray, so it stays on that device, the same
/// reasoning that keeps `import_ledger` out of the snapshot.
///
/// Keys are [ThresholdAlert.dedupeKey] values (`ruleId|monthKey|level`). The
/// store self-prunes to the current month, so it cannot grow without bound.
abstract interface class ThresholdAlertLog {
  Future<Set<String>> read();

  /// Records [keys] as delivered and discards receipts from any month other
  /// than [currentMonthKey].
  Future<void> add(Set<String> keys, {required String currentMonthKey});
}

class PrefsThresholdAlertLog implements ThresholdAlertLog {
  const PrefsThresholdAlertLog();

  static const _key = 'budgetsense.threshold_alerts.v1';

  @override
  Future<Set<String>> read() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_key) ?? const <String>[]).toSet();
  }

  @override
  Future<void> add(
    Set<String> keys, {
    required String currentMonthKey,
  }) async {
    if (keys.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final merged = <String>{
      ...(prefs.getStringList(_key) ?? const <String>[]),
      ...keys,
    };
    // Prune anything from a previous month. Receipts are only meaningful for
    // the month they were issued in, and dropping them is what lets every rule
    // re-arm cleanly at the month boundary.
    final kept = merged
        .where((k) => k.split('|').elementAtOrNull(1) == currentMonthKey)
        .toList();
    await prefs.setStringList(_key, kept);
  }
}

/// In-memory implementation for tests and for any context without a plugin
/// binding. Behaves identically, including the month-boundary pruning.
class InMemoryThresholdAlertLog implements ThresholdAlertLog {
  final Set<String> _keys = <String>{};

  @override
  Future<Set<String>> read() async => Set<String>.from(_keys);

  @override
  Future<void> add(Set<String> keys, {required String currentMonthKey}) async {
    _keys
      ..addAll(keys)
      ..removeWhere((k) => k.split('|').elementAtOrNull(1) != currentMonthKey);
  }
}
