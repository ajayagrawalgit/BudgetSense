import 'cloud_stores.dart';

/// Persistent mutation tracking (Phase 7).
///
/// Not an in-memory boolean. A monotonic local data generation counter is
/// persisted so "waiting to back up" survives app and process restarts. Every
/// committed user-data mutation increments the generation; a validated upload
/// records the generation it uploaded. The backup is PENDING whenever the
/// current generation is ahead of the last uploaded one.
///
/// The user-facing term is "Pending backup" / "Waiting to back up", never
/// "dirty".
class BackupMutationTracker {
  BackupMutationTracker(this._kv);
  final KeyValueStore _kv;

  static const _kCurrent = 'currentGeneration';
  static const _kUploaded = 'lastUploadedGeneration';

  int get currentGeneration => _kv.getInt(_kCurrent) ?? 0;
  int get lastUploadedGeneration => _kv.getInt(_kUploaded) ?? 0;

  /// True when there are committed changes not yet in a validated upload.
  bool get isPending => currentGeneration > lastUploadedGeneration;

  /// Call AFTER a user-data mutation commits. Returns the new generation.
  Future<int> markDirty() async {
    final next = currentGeneration + 1;
    await _kv.setInt(_kCurrent, next);
    return next;
  }

  /// Record that [generation] was uploaded and validated. Never regresses; if
  /// newer mutations happened during the upload, [isPending] stays true.
  Future<void> markUploaded(int generation) async {
    if (generation > lastUploadedGeneration) {
      await _kv.setInt(_kUploaded, generation);
    }
  }

  /// Reset both counters (used when disabling / disconnecting).
  Future<void> reset() async {
    await _kv.remove(_kCurrent);
    await _kv.remove(_kUploaded);
  }
}
