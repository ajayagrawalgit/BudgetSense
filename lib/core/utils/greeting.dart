import '../../features/settings/settings_state.dart';

/// Resolves the name to address the user by, following the rule:
/// nickname (if set) → first name (first word of [SettingsState.userName]) →
/// a friendly fallback.
String resolveDisplayName(SettingsState? settings,
    {String fallback = 'there'}) {
  final nickname = settings?.userNickname.trim() ?? '';
  if (nickname.isNotEmpty) return nickname;

  final full = settings?.userName.trim() ?? '';
  if (full.isNotEmpty) {
    final first = full.split(RegExp(r'\s+')).first.trim();
    if (first.isNotEmpty) return first;
  }
  return fallback;
}

/// Fills a greeting template's `{name}` placeholder with [name].
String formatGreeting(String template, String name) =>
    template.replaceAll('{name}', name.isEmpty ? 'there' : name);
