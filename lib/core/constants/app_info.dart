/// Central metadata about BudgetSense and its author.
///
/// Kept in one place so credits stay consistent everywhere they appear
/// (Settings, About, onboarding).
abstract final class AppInfo {
  /// App name shown in headers and the About screen.
  static const String appName = 'BudgetSense';

  /// The release version people actually see: About screen, backup snapshots
  /// and the Android version name.
  ///
  /// `pubspec.yaml` has to carry a three-segment semver (`0.1.0+1`) because
  /// Dart's pubspec parser rejects anything shorter, so it cannot be the source
  /// of the displayed name. This constant and `versionName` in
  /// `android/app/build.gradle.kts` are the two places that spell out the
  /// public version, and `scripts/release_preflight.sh` fails the release if
  /// they ever drift apart.
  static const String version = '0.1';

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

  /// Android package name, also used as the application id.
  static const String androidPackageId = 'com.budgetsense.budgetsense';

  /// Where new versions are published.
  ///
  /// BudgetSense deliberately ships no self-updater. An app that can download
  /// and install its own APK is a code-execution channel that bypasses the
  /// platform's own signature verification, so the app only ever opens this
  /// page in the browser and leaves the decision to the person using it.
  static const String releasesUrl = '$repositoryUrl/releases/latest';
}
