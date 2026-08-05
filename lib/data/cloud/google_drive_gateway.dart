import 'dart:async';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

import 'cloud_constants.dart';
import 'cloud_failure.dart';
import 'cloud_gateway.dart';

/// Real Google implementations of the cloud gateways (Phase 5).
///
/// IMPORTANT: this file is the ONLY place that touches Google Sign-In and the
/// Drive API. It is written against the installed package versions
/// (google_sign_in 7.2.0, googleapis 13.x) and their CURRENT APIs, not old
/// examples. It cannot be unit-tested against Google in CI; the behavior it
/// implements is covered by the in-memory fakes and must be verified on a real
/// device with real OAuth (see docs/backup/GOOGLE_DRIVE_SETUP.md).

/// Auth gateway backed by google_sign_in 7.2.0 (singleton + event model).
class GoogleDriveAuthGateway implements CloudBackupAuthGateway {
  GoogleDriveAuthGateway({this.serverClientId, this.clientId});

  /// Platform OAuth client ids. On Android the client id is typically supplied
  /// by the platform config (SHA-registered OAuth client); [serverClientId] is
  /// used when a server auth code is needed. A client SECRET is never embedded.
  final String? serverClientId;
  final String? clientId;

  bool _initialized = false;
  GoogleSignInAccount? _account;

  static const _scopes = <String>[CloudBackupConstants.driveFileScope];

  Future<void> _ensureInit() async {
    if (_initialized) return;
    await GoogleSignIn.instance
        .initialize(clientId: clientId, serverClientId: serverClientId);
    _initialized = true;
  }

  @override
  CloudAccount? get currentAccount => _account == null
      ? null
      : CloudAccount(id: _account!.id, email: _account!.email);

  @override
  Future<CloudAccount?> signInSilently() async {
    await _ensureInit();
    try {
      final account =
          await GoogleSignIn.instance.attemptLightweightAuthentication();
      if (account == null) return null;
      _account = account;
      return CloudAccount(id: account.id, email: account.email);
    } on GoogleSignInException {
      return null; // no interactive fallback here, by contract
    }
  }

  @override
  Future<CloudAccount> signIn() async {
    await _ensureInit();
    try {
      final account =
          await GoogleSignIn.instance.authenticate(scopeHint: _scopes);
      _account = account;
      // Ensure the drive.file scope is actually authorized.
      final auth = await account.authorizationClient.authorizeScopes(_scopes);
      if (auth.accessToken.isEmpty) {
        throw const CloudFailure(
          CloudFailureKind.insufficientScope,
          'BudgetSense was not granted permission to use Google Drive.',
        );
      }
      return CloudAccount(id: account.id, email: account.email);
    } on GoogleSignInException catch (e) {
      throw _mapSignInException(e);
    }
  }

  @override
  Future<void> signOut() async {
    await _ensureInit();
    await GoogleSignIn.instance.signOut();
    _account = null;
  }

  @override
  Future<void> disconnect() async {
    await _ensureInit();
    await GoogleSignIn.instance.disconnect();
    _account = null;
  }

  /// An authenticated HTTP client for the Drive API, refreshing authorization
  /// headers per request. Throws [CloudFailure] if authorization is missing.
  Future<http.Client> authorizedClient() async {
    final account = _account;
    if (account == null) {
      throw const CloudFailure(
        CloudFailureKind.authRequired,
        'Please sign in to Google to use cloud backup.',
      );
    }
    return _AuthedClient(account, _scopes);
  }

  CloudFailure _mapSignInException(GoogleSignInException e) {
    return switch (e.code) {
      GoogleSignInExceptionCode.canceled => const CloudFailure(
          CloudFailureKind.authCanceled, 'Sign-in was cancelled.'),
      GoogleSignInExceptionCode.interrupted => const CloudFailure(
          CloudFailureKind.timeout, 'Sign-in was interrupted. Try again.'),
      // The app is not (yet) registered with a Google OAuth client that
      // matches this build's package name and signing certificate. Sign-in
      // physically cannot complete until that is configured in Google Cloud
      // Console (see docs/backup/GOOGLE_DRIVE_SETUP.md). Reauth will not help.
      GoogleSignInExceptionCode.clientConfigurationError ||
      GoogleSignInExceptionCode.providerConfigurationError =>
        const CloudFailure(
            CloudFailureKind.authRequired,
            'Google Drive backup is not set up for this build yet. It needs a '
            'Google sign-in client registered for this app before it can '
            'connect. See the setup guide.'),
      GoogleSignInExceptionCode.uiUnavailable => const CloudFailure(
          CloudFailureKind.authRequired,
          'Google sign-in is unavailable right now. Please try again.'),
      _ => const CloudFailure(CloudFailureKind.authRequired,
          'Could not sign in to Google. Please try again.'),
    };
  }
}

/// http.Client that injects Google authorization headers on every request.
class _AuthedClient extends http.BaseClient {
  _AuthedClient(this._account, this._scopes);
  final GoogleSignInAccount _account;
  final List<String> _scopes;
  final http.Client _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final headers = await _account.authorizationClient
        .authorizationHeaders(_scopes, promptIfNecessary: false);
    if (headers == null) {
      throw const CloudFailure(
        CloudFailureKind.authorizationRevoked,
        'Google Drive access is no longer authorized. Please sign in again.',
      );
    }
    request.headers.addAll(headers);
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}

/// Drive storage gateway (drive.file scope only).
class GoogleDriveBackupGateway implements CloudBackupGateway {
  GoogleDriveBackupGateway(this._auth);

  final GoogleDriveAuthGateway _auth;

  Future<drive.DriveApi> _api() async =>
      drive.DriveApi(await _auth.authorizedClient());

  static const _fields =
      'id,name,version,size,trashed,modifiedTime,appProperties,parents';

  Map<String, String> get _folderProps => {
        CloudBackupConstants.propProduct: CloudBackupConstants.propProductValue,
        CloudBackupConstants.propResourceType:
            CloudBackupConstants.resourceFolder,
      };

  Map<String, String> _fileProps({
    required String digest,
    required int generation,
    required int formatVersion,
  }) =>
      {
        CloudBackupConstants.propProduct: CloudBackupConstants.propProductValue,
        CloudBackupConstants.propResourceType:
            CloudBackupConstants.resourceSnapshot,
        CloudBackupConstants.propPayloadDigest: digest,
        CloudBackupConstants.propGeneration: '$generation',
        CloudBackupConstants.propFormatVersion: '$formatVersion',
      };

  @override
  Future<RemoteFolder> ensureFolder() async {
    return _guard(() async {
      final api = await _api();
      final existing = await _findFolder(api);
      if (existing != null) return RemoteFolder(id: existing.id!);
      final created = await api.files.create(
        drive.File()
          ..name = CloudBackupConstants.folderName
          ..mimeType = CloudBackupConstants.folderMimeType
          ..appProperties = _folderProps,
        $fields: 'id',
      );
      return RemoteFolder(id: created.id!);
    });
  }

  @override
  Future<RemoteFolder?> validateFolder(String folderId) async {
    return _guard(() async {
      final api = await _api();
      try {
        final f = await api.files.get(folderId, $fields: _fields) as drive.File;
        final ours = f.appProperties?[CloudBackupConstants.propResourceType] ==
            CloudBackupConstants.resourceFolder;
        if (f.trashed == true || !ours) return null;
        return RemoteFolder(id: f.id!);
      } on drive.DetailedApiRequestError catch (e) {
        if (e.status == 404) return null;
        rethrow;
      }
    });
  }

  Future<drive.File?> _findFolder(drive.DriveApi api) async {
    const q = "mimeType='${CloudBackupConstants.folderMimeType}' "
        "and name='${CloudBackupConstants.folderName}' "
        "and trashed=false "
        "and appProperties has { key='${CloudBackupConstants.propResourceType}' "
        "and value='${CloudBackupConstants.resourceFolder}' }";
    final res = await api.files.list(
      q: q,
      spaces: 'drive',
      $fields: 'files($_fields)',
    );
    final files = res.files ?? const [];
    if (files.isEmpty) return null;
    // Deterministic: oldest wins if duplicates exist.
    files.sort((a, b) => (a.modifiedTime ?? DateTime(0))
        .compareTo(b.modifiedTime ?? DateTime(0)));
    return files.first;
  }

  @override
  Future<RemoteBackupFile?> findBackupFile(String folderId) async {
    return _guard(() async {
      final api = await _api();
      final q = "name='${CloudBackupConstants.backupFileName}' "
          "and '$folderId' in parents and trashed=false "
          "and appProperties has { key='${CloudBackupConstants.propResourceType}' "
          "and value='${CloudBackupConstants.resourceSnapshot}' }";
      final res = await api.files.list(
        q: q,
        spaces: 'drive',
        $fields: 'files($_fields)',
      );
      final files = res.files ?? const [];
      if (files.isEmpty) return null;
      files.sort((a, b) => (a.modifiedTime ?? DateTime(0))
          .compareTo(b.modifiedTime ?? DateTime(0)));
      return _toMeta(files.first);
    });
  }

  @override
  Future<RemoteBackupFile?> validateFile(String fileId) async {
    return _guard(() async {
      final api = await _api();
      try {
        final f = await api.files.get(fileId, $fields: _fields) as drive.File;
        final ours = f.appProperties?[CloudBackupConstants.propResourceType] ==
            CloudBackupConstants.resourceSnapshot;
        if (f.trashed == true || !ours) return null;
        return _toMeta(f);
      } on drive.DetailedApiRequestError catch (e) {
        if (e.status == 404) return null;
        rethrow;
      }
    });
  }

  @override
  Future<RemoteBackupFile> createBackupFile({
    required String folderId,
    required List<int> bytes,
    required String payloadDigest,
    required int generation,
    required int formatVersion,
  }) async {
    return _guard(() async {
      final api = await _api();
      final created = await api.files.create(
        drive.File()
          ..name = CloudBackupConstants.backupFileName
          ..parents = [folderId]
          ..mimeType = CloudBackupConstants.backupMimeType
          ..appProperties = _fileProps(
            digest: payloadDigest,
            generation: generation,
            formatVersion: formatVersion,
          ),
        uploadMedia: drive.Media(
          Stream.value(bytes),
          bytes.length,
          contentType: CloudBackupConstants.backupMimeType,
        ),
        $fields: _fields,
      );
      return _toMeta(created);
    });
  }

  @override
  Future<RemoteBackupFile> updateBackupFile({
    required String fileId,
    required List<int> bytes,
    required String payloadDigest,
    required int generation,
    required int formatVersion,
    int? expectedVersion,
  }) async {
    return _guard(() async {
      final api = await _api();
      // Optimistic conflict check: confirm the remote version is still the one
      // this device last saw before replacing it. Drive v3 has no simple
      // If-Match on files.update, so this is a documented check-then-act.
      if (expectedVersion != null) {
        final current =
            await api.files.get(fileId, $fields: 'version') as drive.File;
        final remoteVersion = int.tryParse(current.version ?? '') ?? -1;
        if (remoteVersion != expectedVersion) {
          throw const CloudFailure(
            CloudFailureKind.remoteConflict,
            'Your cloud backup was changed on another device. Review the newer '
            'backup before replacing it.',
          );
        }
      }
      final updated = await api.files.update(
        drive.File()
          ..appProperties = _fileProps(
            digest: payloadDigest,
            generation: generation,
            formatVersion: formatVersion,
          ),
        fileId,
        uploadMedia: drive.Media(
          Stream.value(bytes),
          bytes.length,
          contentType: CloudBackupConstants.backupMimeType,
        ),
        $fields: _fields,
      );
      return _toMeta(updated);
    });
  }

  @override
  Future<List<int>> downloadBackupFile(String fileId) async {
    return _guard(() async {
      final api = await _api();
      final media = await api.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;
      final out = <int>[];
      await for (final chunk in media.stream) {
        out.addAll(chunk);
      }
      return out;
    });
  }

  @override
  Future<RemoteBackupFile?> getMetadata(String fileId) async {
    return _guard(() async {
      final api = await _api();
      try {
        final f = await api.files.get(fileId, $fields: _fields) as drive.File;
        return _toMeta(f);
      } on drive.DetailedApiRequestError catch (e) {
        if (e.status == 404) return null;
        rethrow;
      }
    });
  }

  @override
  Future<void> deleteBackupFile(String fileId) async {
    return _guard(() async {
      final api = await _api();
      await api.files.delete(fileId);
    });
  }

  RemoteBackupFile _toMeta(drive.File f) => RemoteBackupFile(
        id: f.id!,
        version: int.tryParse(f.version ?? '') ?? 0,
        size: int.tryParse(f.size ?? '') ?? 0,
        payloadDigest: f.appProperties?[CloudBackupConstants.propPayloadDigest],
        generation: int.tryParse(
            f.appProperties?[CloudBackupConstants.propGeneration] ?? ''),
        modifiedTime: f.modifiedTime,
        trashed: f.trashed ?? false,
      );

  /// Maps Drive/network errors to the typed failure taxonomy. Never leaks raw
  /// payloads, tokens, file ids, or stack traces.
  Future<T> _guard<T>(Future<T> Function() op) async {
    try {
      return await op();
    } on CloudFailure {
      rethrow;
    } on drive.DetailedApiRequestError catch (e) {
      throw _mapApiError(e);
    } on TimeoutException {
      throw const CloudFailure(
          CloudFailureKind.timeout, 'Google Drive timed out. Try again.');
    } catch (_) {
      // Network / socket errors surface here without details.
      throw const CloudFailure(
        CloudFailureKind.offline,
        'Could not reach Google Drive. Check your connection and try again.',
      );
    }
  }

  CloudFailure _mapApiError(drive.DetailedApiRequestError e) {
    switch (e.status) {
      case 401:
        return const CloudFailure(CloudFailureKind.authRequired,
            'Google Drive access expired. Please sign in again.');
      case 403:
        final reason = (e.message ?? '').toLowerCase();
        if (reason.contains('quota') || reason.contains('storage')) {
          return const CloudFailure(CloudFailureKind.quotaExhausted,
              'Your Google Drive storage is full. Free up space and try again.');
        }
        if (reason.contains('rate') || reason.contains('limit')) {
          return const CloudFailure(CloudFailureKind.rateLimited,
              'Google Drive is busy. BudgetSense will retry shortly.');
        }
        return const CloudFailure(CloudFailureKind.insufficientScope,
            'BudgetSense is not authorized for this Drive action.');
      case 404:
        return const CloudFailure(CloudFailureKind.fileMissing,
            'The cloud backup could not be found on Google Drive.');
      case 429:
        return const CloudFailure(CloudFailureKind.rateLimited,
            'Google Drive is busy. BudgetSense will retry shortly.');
      case 500:
      case 502:
      case 503:
      case 504:
        return const CloudFailure(CloudFailureKind.transientServer,
            'Google Drive had a temporary problem. BudgetSense will retry.');
      default:
        return const CloudFailure(CloudFailureKind.unknown,
            'Something went wrong talking to Google Drive.');
    }
  }
}
