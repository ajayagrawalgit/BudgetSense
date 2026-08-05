/// Central metadata about BudgetSense and its author.
///
/// Kept in one place so credits stay consistent everywhere they appear
/// (Settings, About, onboarding). Update [repositoryUrl] once the project
/// is published as open source.
abstract final class AppInfo {
  /// App name shown in headers and the About screen.
  static const String appName = 'BudgetSense';

  /// Semantic version. Single source of truth is `pubspec.yaml` (`version:`);
  /// this compile-time mirror is kept identical to the pubspec version part and
  /// is verified by `scripts/release_preflight.sh` on every release, so any
  /// drift fails the build. Displayed on the About screen and stamped into
  /// backup snapshots.
  static const String version = '0.1.0';

  /// Short tagline used under the app name.
  static const String tagline = 'A calm, offline-first finance journal.';

  /// The person who designed and built the app.
  static const String authorName = 'Ajay Agrawal';

  /// Author's public profiles.
  static const String githubUrl = 'https://www.github.com/ajayagrawalgit';
  static const String linkedInUrl =
      'https://www.linkedin.com/in/theajayagrawal';

  /// Public source repository.
  static const String repositoryUrl =
      'https://github.com/ajayagrawalgit/BudgetSense';

  /// Whether [repositoryUrl] points at a live repository. When `false`, the UI
  /// shows the "Source code" entry as "coming soon" instead of a link.
  static const bool hasRepositoryLink = true;
}
