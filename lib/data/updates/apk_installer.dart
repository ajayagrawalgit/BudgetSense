import 'package:flutter/services.dart';

import 'update_constants.dart';

/// Result of asking Android to install an APK.
enum InstallOutcome {
  /// The system installer was launched (the user still confirms in the OS UI).
  launched,

  /// The user must first grant "install unknown apps"; we routed them there.
  needsPermission,

  /// Something went wrong handing off to the installer.
  failed,
}

/// Hands a downloaded APK to the platform installer. Behind an interface so the
/// pure update logic stays testable; the real one is Android-only.
abstract interface class ApkInstaller {
  /// Whether the app is currently allowed to request package installs.
  Future<bool> canInstall();

  /// Launches the system installer for the APK at [filePath].
  Future<InstallOutcome> install(String filePath);
}

/// No-op installer for tests and non-Android platforms.
class NoopApkInstaller implements ApkInstaller {
  const NoopApkInstaller();
  @override
  Future<bool> canInstall() async => false;
  @override
  Future<InstallOutcome> install(String filePath) async =>
      InstallOutcome.failed;
}

/// Android installer via a MethodChannel into [MainActivity]. DEVICE-ONLY: this
/// hands off to the OS PackageInstaller through a FileProvider URI. Not run in
/// CI; verify on a real device.
class AndroidApkInstaller implements ApkInstaller {
  const AndroidApkInstaller();

  static const _channel = MethodChannel(UpdateConfig.installerChannel);

  @override
  Future<bool> canInstall() async {
    final ok = await _channel.invokeMethod<bool>('canInstall');
    return ok ?? false;
  }

  @override
  Future<InstallOutcome> install(String filePath) async {
    final result =
        await _channel.invokeMethod<String>('install', {'path': filePath});
    return switch (result) {
      'launched' => InstallOutcome.launched,
      'needsPermission' => InstallOutcome.needsPermission,
      _ => InstallOutcome.failed,
    };
  }
}
