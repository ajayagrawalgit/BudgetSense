/// Typed failure taxonomy for cloud backup (Phase 9).
///
/// Every cloud operation surfaces one of these categories so the controller can
/// pick the correct policy (retry, require sign-in, stop-and-warn) and the UI
/// can show a safe, understandable message. Raw payloads, tokens, file ids,
/// stack traces, and cryptographic material MUST NEVER appear in [userMessage].
library;

enum CloudFailureKind {
  offline,
  timeout,
  authCanceled,
  authRequired,
  authorizationRevoked,
  insufficientScope,
  wrongAccount,
  folderMissing,
  fileMissing,
  trashed,
  quotaExhausted,
  rateLimited,
  transientServer,
  remoteConflict,
  snapshotGenerationFailed,
  snapshotValidationFailed,
  encryptionFailed,
  incorrectPassphrase,
  uploadIntegrityMismatch,
  downloadIntegrityMismatch,
  unsupportedVersion,
  localStorageFailed,
  restoreRollbackFailed,
  unknown,
}

/// A cloud failure with a user-safe message. [kind] drives retry/auth policy.
class CloudFailure implements Exception {
  const CloudFailure(this.kind, this.userMessage);

  final CloudFailureKind kind;
  final String userMessage;

  /// Transient failures worth an automatic backoff retry.
  bool get isTransient =>
      kind == CloudFailureKind.offline ||
      kind == CloudFailureKind.timeout ||
      kind == CloudFailureKind.rateLimited ||
      kind == CloudFailureKind.transientServer;

  /// Failures that require the user to re-authenticate or re-authorize before
  /// any further attempt makes sense.
  bool get needsReauth =>
      kind == CloudFailureKind.authRequired ||
      kind == CloudFailureKind.authorizationRevoked ||
      kind == CloudFailureKind.insufficientScope;

  @override
  String toString() => 'CloudFailure(${kind.name}): $userMessage';
}
