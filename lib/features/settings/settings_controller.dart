import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'settings_state.dart';

/// Riverpod async provider that loads persisted settings on startup.
final settingsControllerProvider =
    AsyncNotifierProvider<SettingsController, SettingsState>(
  SettingsController.new,
);

/// Persists user preferences to [SharedPreferences] as a single JSON blob.
/// Individual settings can be reset without wiping everything (Section 18).
class SettingsController extends AsyncNotifier<SettingsState> {
  static const _key = 'budgetsense.settings.v1';

  @override
  Future<SettingsState> build() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return const SettingsState();
    try {
      final map = jsonDecode(raw) as Map<String, Object?>;
      return SettingsState.fromMap(map);
    } catch (_) {
      return const SettingsState();
    }
  }

  Future<void> _persist(SettingsState next) async {
    state = AsyncData(next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(next.toMap()));
  }

  /// Apply an arbitrary patch via a copyWith-style transform.
  Future<void> save(
    SettingsState Function(SettingsState current) transform,
  ) async {
    final current = state.valueOrNull ?? const SettingsState();
    await _persist(transform(current));
  }

  /// Reset a single field back to defaults without touching the rest.
  Future<void> resetField(
    SettingsState Function(SettingsState current, SettingsState defaults) pick,
  ) async {
    final current = state.valueOrNull ?? const SettingsState();
    await _persist(pick(current, const SettingsState()));
  }
}
