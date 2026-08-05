import 'package:budgetsense/data/cloud/cloud_failure.dart';
import 'package:budgetsense/data/cloud/cloud_gateway.dart';
import 'package:budgetsense/data/cloud/cloud_stores.dart';

/// In-memory fakes so the cloud layer is fully testable without Google, secure
/// storage, or SharedPreferences plugins.

class InMemoryKeyValueStore implements KeyValueStore {
  final Map<String, Object?> _m = {};
  @override
  String? getString(String key) => _m[key] as String?;
  @override
  Future<void> setString(String key, String value) async => _m[key] = value;
  @override
  int? getInt(String key) => _m[key] as int?;
  @override
  Future<void> setInt(String key, int value) async => _m[key] = value;
  @override
  bool? getBool(String key) => _m[key] as bool?;
  @override
  Future<void> setBool(String key, bool value) async => _m[key] = value;
  @override
  Future<void> remove(String key) async => _m.remove(key);
}

class InMemorySecretStore implements SecretStore {
  final Map<String, String> _m = {};
  @override
  Future<String?> read(String key) async => _m[key];
  @override
  Future<void> write(String key, String value) async => _m[key] = value;
  @override
  Future<void> delete(String key) async => _m.remove(key);
}

/// Configurable fake auth gateway.
class FakeAuthGateway implements CloudBackupAuthGateway {
  FakeAuthGateway(
      {this.account = const CloudAccount(id: 'acc-1', email: 'a@b.co')});
  CloudAccount account;
  bool cancelInteractive = false;
  bool silentReturnsNull = false;
  CloudAccount? _current;
  int signInCalls = 0;
  int disconnectCalls = 0;

  @override
  CloudAccount? get currentAccount => _current;

  @override
  Future<CloudAccount?> signInSilently() async {
    if (silentReturnsNull) return null;
    return _current ??= account;
  }

  @override
  Future<CloudAccount> signIn() async {
    signInCalls++;
    if (cancelInteractive) {
      throw const CloudFailure(
        CloudFailureKind.authCanceled,
        'Sign-in was cancelled.',
      );
    }
    return _current = account;
  }

  @override
  Future<void> signOut() async => _current = null;

  @override
  Future<void> disconnect() async {
    disconnectCalls++;
    _current = null;
  }
}

/// In-memory fake Drive. Tracks one folder + one canonical file with a
/// monotonic version and appProperties, and can simulate every failure.
class FakeDriveGateway implements CloudBackupGateway {
  RemoteFolder? _folder;
  _FakeFile? _file;
  int _version = 0;
  int folderCreateCount = 0;
  int fileCreateCount = 0;
  int updateCount = 0;

  // Failure injection.
  bool remoteChangedUnderfoot = false;
  bool fileTrashed = false;
  bool failNextUpload = false;

  /// Seed a pre-existing remote backup (for reconciliation tests).
  void seedExistingFile(List<int> bytes,
      {String digest = 'seed', int generation = 0}) {
    _folder ??= const RemoteFolder(id: 'folder-1');
    _version++;
    _file = _FakeFile(
      id: 'file-1',
      version: _version,
      bytes: List.of(bytes),
      digest: digest,
      generation: generation,
    );
  }

  @override
  Future<RemoteFolder> ensureFolder() async {
    if (_folder != null) return _folder!;
    folderCreateCount++;
    return _folder = const RemoteFolder(id: 'folder-1');
  }

  @override
  Future<RemoteFolder?> validateFolder(String folderId) async =>
      _folder?.id == folderId ? _folder : null;

  @override
  Future<RemoteBackupFile?> findBackupFile(String folderId) async =>
      _file?.toMeta(trashed: fileTrashed);

  @override
  Future<RemoteBackupFile?> validateFile(String fileId) async =>
      (_file?.id == fileId && !fileTrashed) ? _file!.toMeta() : null;

  @override
  Future<RemoteBackupFile> createBackupFile({
    required String folderId,
    required List<int> bytes,
    required String payloadDigest,
    required int generation,
    required int formatVersion,
  }) async {
    fileCreateCount++;
    if (failNextUpload) {
      failNextUpload = false;
      throw const CloudFailure(
        CloudFailureKind.transientServer,
        'Temporary Google Drive error.',
      );
    }
    _version++;
    _file = _FakeFile(
      id: 'file-1',
      version: _version,
      bytes: List.of(bytes),
      digest: payloadDigest,
      generation: generation,
    );
    return _file!.toMeta();
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
    updateCount++;
    if (failNextUpload) {
      failNextUpload = false;
      throw const CloudFailure(
        CloudFailureKind.transientServer,
        'Temporary Google Drive error.',
      );
    }
    if (fileTrashed) {
      throw const CloudFailure(CloudFailureKind.trashed, 'File is in Trash.');
    }
    if (remoteChangedUnderfoot) {
      // Simulate another device having bumped the version since we last read.
      _version++;
    }
    if (expectedVersion != null && expectedVersion != _version) {
      throw const CloudFailure(
        CloudFailureKind.remoteConflict,
        'Your cloud backup was updated on another device.',
      );
    }
    _version++;
    _file = _FakeFile(
      id: fileId,
      version: _version,
      bytes: List.of(bytes),
      digest: payloadDigest,
      generation: generation,
    );
    return _file!.toMeta();
  }

  @override
  Future<List<int>> downloadBackupFile(String fileId) async {
    final f = _file;
    if (f == null || f.id != fileId) {
      throw const CloudFailure(CloudFailureKind.fileMissing, 'No backup file.');
    }
    return f.bytes;
  }

  @override
  Future<RemoteBackupFile?> getMetadata(String fileId) async =>
      _file?.id == fileId ? _file!.toMeta(trashed: fileTrashed) : null;

  @override
  Future<void> deleteBackupFile(String fileId) async {
    if (_file?.id == fileId) _file = null;
  }

  List<int>? get storedBytes => _file?.bytes;
  int? get currentGeneration => _file?.generation;
}

class _FakeFile {
  _FakeFile({
    required this.id,
    required this.version,
    required this.bytes,
    required this.digest,
    required this.generation,
  });
  final String id;
  final int version;
  final List<int> bytes;
  final String digest;
  final int generation;

  RemoteBackupFile toMeta({bool trashed = false}) => RemoteBackupFile(
        id: id,
        version: version,
        size: bytes.length,
        payloadDigest: digest,
        generation: generation,
        modifiedTime: DateTime(2026),
        trashed: trashed,
      );
}
