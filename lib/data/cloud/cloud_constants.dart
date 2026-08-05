/// One place for every Google Drive backup constant. These are the on-Drive
/// contract; do not scatter them as string literals across the codebase.
library;

abstract final class CloudBackupConstants {
  /// The visible Drive folder the user will see. Exact, stable name.
  static const String folderName = 'BudgetSense_Backup';

  /// The single canonical backup file, reused for the whole linked lifecycle.
  /// A new file is NEVER created per mutation.
  static const String backupFileName = 'budgetsense_backup.bsbak';

  /// Narrowest sufficient OAuth scope: per-file access to files the app creates
  /// or is explicitly opened. NEVER request the broad `drive` scope.
  static const String driveFileScope =
      'https://www.googleapis.com/auth/drive.file';

  /// Drive folder MIME type.
  static const String folderMimeType = 'application/vnd.google-apps.folder';

  /// MIME type stored for our backup file (encrypted binary).
  static const String backupMimeType = 'application/octet-stream';

  /// `appProperties` markers so we never adopt an arbitrary same-named folder
  /// or file created outside BudgetSense.
  static const String propProduct = 'bs_product';
  static const String propProductValue = 'BudgetSense';
  static const String propResourceType = 'bs_resource';
  static const String resourceFolder = 'backup-folder';
  static const String resourceSnapshot = 'canonical-snapshot';
  static const String propFormatVersion = 'bs_format_version';
  static const String propPayloadDigest = 'bs_payload_sha256';
  static const String propGeneration = 'bs_generation';

  /// Debounce window: rapid edits coalesce into one upload.
  static const Duration debounce = Duration(seconds: 8);

  /// Unique background work name (WorkManager unique work).
  static const String backgroundTaskName = 'budgetsense.cloud.sync';
  static const String backgroundUniqueName = 'budgetsense-cloud-sync-unique';
}
