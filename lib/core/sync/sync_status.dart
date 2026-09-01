class SyncStatus {
  const SyncStatus({
    this.online = true,
    this.pendingCount = 0,
    this.lastError,
    this.oldestPendingAt,
    this.hydrated = false,
  });

  final bool online;
  final int pendingCount;
  final String? lastError;
  final DateTime? oldestPendingAt;
  final bool hydrated;

  bool get showNotSynced {
    if (lastError != null && pendingCount > 0) {
      return true;
    }
    if (pendingCount == 0 || oldestPendingAt == null) {
      return false;
    }
    return DateTime.now().difference(oldestPendingAt!) > const Duration(seconds: 20);
  }

  SyncStatus copyWith({
    bool? online,
    int? pendingCount,
    String? lastError,
    DateTime? oldestPendingAt,
    bool? hydrated,
    bool clearError = false,
  }) {
    return SyncStatus(
      online: online ?? this.online,
      pendingCount: pendingCount ?? this.pendingCount,
      lastError: clearError ? null : (lastError ?? this.lastError),
      oldestPendingAt: oldestPendingAt ?? this.oldestPendingAt,
      hydrated: hydrated ?? this.hydrated,
    );
  }
}
