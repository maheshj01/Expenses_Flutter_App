enum SyncPhase {
  /// No backend configured; data stays on this device.
  localOnly,

  /// Nobody is signed in, so nothing is backed up. Changes wait on this
  /// device and go to the account once someone signs in.
  signedOut,
  idle,
  syncing,

  /// No network; changes are queued and will sync later.
  offline,
  error,
}

class SyncStatus {
  const SyncStatus({
    required this.phase,
    this.backendName,
    this.lastSyncedAt,
    this.pendingCount = 0,
    this.message,
  });

  final SyncPhase phase;
  final String? backendName;
  final DateTime? lastSyncedAt;

  /// Local changes not yet pushed.
  final int pendingCount;

  /// Why the last sync failed, in words for people (see
  /// `RemoteStore.describeError`). Only set when [phase] is
  /// [SyncPhase.error].
  final String? message;

  SyncStatus copyWith({
    SyncPhase? phase,
    DateTime? lastSyncedAt,
    int? pendingCount,
    String? message,
  }) {
    return SyncStatus(
      phase: phase ?? this.phase,
      backendName: backendName,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      pendingCount: pendingCount ?? this.pendingCount,
      message: message,
    );
  }
}
