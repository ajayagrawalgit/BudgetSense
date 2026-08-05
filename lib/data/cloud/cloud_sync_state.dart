import 'cloud_failure.dart';

/// The cloud sync state machine (Phase 5/9).
enum CloudSyncStatus {
  /// Cloud backup is off. No auth, no network, nothing scheduled.
  disabled,

  /// Setup in progress (auth + folder/file + first backup).
  linking,

  /// Enabled, everything uploaded, nothing pending.
  idle,

  /// Enabled with committed changes waiting to upload.
  pending,

  /// An upload is in flight.
  syncing,

  /// The remote file changed unexpectedly (another device). Requires the user
  /// to reconcile before any further upload.
  remoteConflict,

  /// Authorization lost / revoked. Requires the user to sign in again.
  requiresSignIn,

  /// A non-transient error the user should see.
  error,
}

/// Immutable snapshot of the cloud sync state for the UI.
class CloudSyncState {
  const CloudSyncState({
    this.status = CloudSyncStatus.disabled,
    this.email,
    this.lastSyncAt,
    this.pending = false,
    this.lastError,
  });

  final CloudSyncStatus status;
  final String? email;
  final DateTime? lastSyncAt;
  final bool pending;
  final CloudFailure? lastError;

  bool get enabled => status != CloudSyncStatus.disabled;

  CloudSyncState copyWith({
    CloudSyncStatus? status,
    String? email,
    DateTime? lastSyncAt,
    bool? pending,
    CloudFailure? lastError,
    bool clearError = false,
    bool clearEmail = false,
  }) =>
      CloudSyncState(
        status: status ?? this.status,
        email: clearEmail ? null : (email ?? this.email),
        lastSyncAt: lastSyncAt ?? this.lastSyncAt,
        pending: pending ?? this.pending,
        lastError: clearError ? null : (lastError ?? this.lastError),
      );
}

/// Background-work adapter (Phase 7). Abstracted so CI does not depend on
/// WorkManager and so iOS/Android differences stay behind one seam.
abstract interface class BackgroundSyncScheduler {
  /// Register a unique, network-constrained, backoff-retried sync job.
  Future<void> scheduleUniqueSync();

  /// Cancel the unique sync job (on disable/disconnect).
  Future<void> cancel();
}

/// A no-op scheduler for tests and platforms without background support.
class NoopBackgroundSyncScheduler implements BackgroundSyncScheduler {
  const NoopBackgroundSyncScheduler();
  @override
  Future<void> scheduleUniqueSync() async {}
  @override
  Future<void> cancel() async {}
}
