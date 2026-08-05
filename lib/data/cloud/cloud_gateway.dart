/// Cloud-agnostic models and gateway interfaces (Phase 5).
///
/// The core backup/restore/domain layers depend ONLY on these abstractions,
/// never on Google API classes. The Google implementation lives in
/// `google_drive_gateway.dart`; tests use in-memory fakes.
library;

/// The linked Google account, reduced to what BudgetSense needs.
class CloudAccount {
  const CloudAccount({required this.id, required this.email});
  final String id;
  final String email;
}

/// The BudgetSense_Backup folder on Drive.
class RemoteFolder {
  const RemoteFolder({required this.id});
  final String id;
}

/// The canonical backup file's metadata. [version] is Drive's monotonically
/// increasing file version, used for conditional-update conflict detection.
class RemoteBackupFile {
  const RemoteBackupFile({
    required this.id,
    required this.version,
    required this.size,
    this.payloadDigest,
    this.generation,
    this.modifiedTime,
    this.trashed = false,
  });

  final String id;
  final int version;
  final int size;
  final String? payloadDigest;
  final int? generation;
  final DateTime? modifiedTime;
  final bool trashed;
}

/// Authentication gateway. The ONLY component that touches Google Sign-In.
abstract interface class CloudBackupAuthGateway {
  /// Lightweight, non-interactive restore of a prior session. Returns null if
  /// no session can be restored without user interaction.
  Future<CloudAccount?> signInSilently();

  /// Interactive sign-in + authorization of the drive.file scope. Must be
  /// triggered by an explicit user gesture. Throws [CloudFailure] on cancel /
  /// failure.
  Future<CloudAccount> signIn();

  /// The current account, or null if not signed in.
  CloudAccount? get currentAccount;

  /// Sign out locally (keeps the granted consent).
  Future<void> signOut();

  /// Revoke consent entirely (disconnect the app from the account).
  Future<void> disconnect();
}

/// Storage gateway. Cloud-agnostic Drive file operations, assuming the auth
/// gateway has already authorized the drive.file scope.
abstract interface class CloudBackupGateway {
  /// Find the app-owned BudgetSense_Backup folder (by marker) or create it.
  /// Never adopts an arbitrary same-named folder lacking the app marker.
  Future<RemoteFolder> ensureFolder();

  /// Validate a cached folder id still exists, is not trashed, and carries the
  /// app marker. Returns null if stale.
  Future<RemoteFolder?> validateFolder(String folderId);

  /// Find the canonical backup file inside [folderId], or null.
  Future<RemoteBackupFile?> findBackupFile(String folderId);

  /// Validate a cached file id. Returns null if missing / trashed / not ours.
  Future<RemoteBackupFile?> validateFile(String fileId);

  /// Create the canonical backup file with [bytes] and app markers.
  Future<RemoteBackupFile> createBackupFile({
    required String folderId,
    required List<int> bytes,
    required String payloadDigest,
    required int generation,
    required int formatVersion,
  });

  /// Update the existing file. [expectedVersion], when provided, is used for a
  /// conditional update; if the remote version has moved, throws a
  /// [CloudFailure] of kind remoteConflict rather than overwriting.
  Future<RemoteBackupFile> updateBackupFile({
    required String fileId,
    required List<int> bytes,
    required String payloadDigest,
    required int generation,
    required int formatVersion,
    int? expectedVersion,
  });

  /// Download the file's bytes for restore.
  Future<List<int>> downloadBackupFile(String fileId);

  /// Fetch minimal metadata (for conflict checks).
  Future<RemoteBackupFile?> getMetadata(String fileId);

  /// Permanently delete the backup file (explicit user action only).
  Future<void> deleteBackupFile(String fileId);
}
