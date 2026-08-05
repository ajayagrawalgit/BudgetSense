import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../data/updates/apk_installer.dart';
import '../data/updates/update_gateway.dart';
import '../data/updates/update_service.dart';
import 'cloud_providers.dart';

/// In-app update provider graph (sideloaded / non-Play builds).

final updateGatewayProvider = Provider<UpdateGateway>(
  (_) => GitHubUpdateGateway(),
);

final apkInstallerProvider = Provider<ApkInstaller>(
  (_) => Platform.isAndroid
      ? const AndroidApkInstaller()
      : const NoopApkInstaller(),
);

final updateServiceProvider = Provider<UpdateService>((ref) {
  final service = UpdateService(
    gateway: ref.watch(updateGatewayProvider),
    installer: ref.watch(apkInstallerProvider),
    store: ref.watch(cloudKeyValueStoreProvider),
    currentVersionCode: () async {
      final info = await PackageInfo.fromPlatform();
      return int.tryParse(info.buildNumber) ?? 0;
    },
    downloadDirectory: () async => (await getTemporaryDirectory()).path,
  );
  ref.onDispose(service.dispose);
  return service;
});
