import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'update_constants.dart';
import 'update_manifest.dart';

/// Fetches the update manifest and downloads the APK. Behind an interface so CI
/// tests it with a fake (no network).
abstract interface class UpdateGateway {
  /// Returns the latest manifest, or null if updates are not configured.
  /// Throws on network/parse errors so the caller can show a friendly message.
  Future<UpdateManifest?> fetchLatest();

  /// Downloads [url] to [destinationPath], reporting progress in 0..1.
  /// Returns the written file. Enforces [UpdateConfig.maxApkBytes].
  Future<File> downloadApk(
    String url,
    String destinationPath, {
    void Function(double progress)? onProgress,
  });
}

/// GitHub Releases implementation. Network code only; not run in CI.
class GitHubUpdateGateway implements UpdateGateway {
  GitHubUpdateGateway({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<UpdateManifest?> fetchLatest() async {
    if (!UpdateConfig.isConfigured) return null;
    final res = await _client.get(Uri.parse(UpdateConfig.manifestUrl));
    if (res.statusCode != 200) {
      throw HttpException(
        'Update check failed (HTTP ${res.statusCode})',
        uri: Uri.parse(UpdateConfig.manifestUrl),
      );
    }
    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Manifest is not a JSON object');
    }
    return UpdateManifest.fromJson(decoded);
  }

  @override
  Future<File> downloadApk(
    String url,
    String destinationPath, {
    void Function(double progress)? onProgress,
  }) async {
    final req = http.Request('GET', Uri.parse(url));
    final res = await _client.send(req);
    if (res.statusCode != 200) {
      throw HttpException('Download failed (HTTP ${res.statusCode})',
          uri: Uri.parse(url));
    }
    final total = res.contentLength ?? 0;
    if (total > UpdateConfig.maxApkBytes) {
      throw const FormatException('Update file is unexpectedly large');
    }
    final file = File(destinationPath);
    final sink = file.openWrite();
    var received = 0;
    try {
      await for (final chunk in res.stream) {
        received += chunk.length;
        if (received > UpdateConfig.maxApkBytes) {
          throw const FormatException('Update file exceeded the size limit');
        }
        sink.add(chunk);
        if (total > 0 && onProgress != null) onProgress(received / total);
      }
      await sink.flush();
    } finally {
      await sink.close();
    }
    return file;
  }
}
