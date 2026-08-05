import 'dart:io';

import 'package:budgetsense/data/updates/apk_installer.dart';
import 'package:budgetsense/data/updates/update_gateway.dart';
import 'package:budgetsense/data/updates/update_manifest.dart';

/// In-memory fakes so the update flow is fully testable without network or a
/// device installer.

class FakeUpdateGateway implements UpdateGateway {
  FakeUpdateGateway({this.manifest, this.apkBytes = const [1, 2, 3, 4]});

  UpdateManifest? manifest;
  List<int> apkBytes;
  bool throwOnFetch = false;
  bool throwOnDownload = false;
  int fetchCalls = 0;
  int downloadCalls = 0;

  @override
  Future<UpdateManifest?> fetchLatest() async {
    fetchCalls++;
    if (throwOnFetch) throw const SocketException('offline');
    return manifest;
  }

  @override
  Future<File> downloadApk(
    String url,
    String destinationPath, {
    void Function(double progress)? onProgress,
  }) async {
    downloadCalls++;
    if (throwOnDownload) throw const SocketException('offline');
    onProgress?.call(0.5);
    final file = File(destinationPath);
    await file.writeAsBytes(apkBytes);
    onProgress?.call(1.0);
    return file;
  }
}

class FakeApkInstaller implements ApkInstaller {
  FakeApkInstaller(
      {this.allowed = true, this.outcome = InstallOutcome.launched});

  bool allowed;
  InstallOutcome outcome;
  int installCalls = 0;
  String? lastPath;

  @override
  Future<bool> canInstall() async => allowed;

  @override
  Future<InstallOutcome> install(String filePath) async {
    installCalls++;
    lastPath = filePath;
    return outcome;
  }
}
