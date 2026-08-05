/// One place for the in-app update configuration.
///
/// Updates are fetched from GitHub Releases. You publish a small `latest.json`
/// manifest and the signed APK as release assets; GitHub gives every release a
/// stable "latest/download/<asset>" URL, so these constants never need to change
/// per version. See docs/updates/AUTO_UPDATE.md.
///
/// IMPORTANT: the update APK MUST be signed with the SAME keystore as the
/// installed build, or Android rejects the update ("signatures do not match").
abstract final class UpdateConfig {
  /// Your GitHub owner/org and repository name. Leave [repoSlug] empty to keep
  /// the update feature dormant (it will simply report "not configured" and do
  /// nothing, never crash). Example: 'mickey/BudgetSense'.
  static const String repoSlug = String.fromEnvironment(
    'UPDATE_REPO_SLUG',
    defaultValue: '',
  );

  /// Whether update checking is configured at all.
  static bool get isConfigured => repoSlug.trim().isNotEmpty;

  /// Stable URL of the manifest asset attached to the latest GitHub Release.
  static String get manifestUrl =>
      'https://github.com/$repoSlug/releases/latest/download/latest.json';

  /// Safety ceiling for a downloaded APK (bytes). Rejects absurd payloads.
  static const int maxApkBytes = 300 * 1024 * 1024; // 300 MB

  /// Native install channel (Android only).
  static const String installerChannel =
      'com.budgetsense.budgetsense/installer';

  /// Prefs key remembering the versionCode the user chose to skip, so the banner
  /// never nags for a release they already dismissed.
  static const String dismissedVersionKey = 'updates.dismissedVersionCode';
}
