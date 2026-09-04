/// High-level home-screen status derived from the backup job.
enum BackupPhase {
  /// No backup run yet / waiting for user.
  idle,

  /// Actively uploading or preparing files.
  working,

  /// Queue emptied with zero failures.
  success,

  /// Finished with at least one failure (or aborted).
  failed,
}

/// Immutable snapshot of backup progress for the UI.
class BackupStatus {
  const BackupStatus({
    required this.phase,
    this.currentFileName,
    this.currentPath,
    this.completed = 0,
    this.total = 0,
    this.failed = 0,
    this.message,
  });

  final BackupPhase phase;
  final String? currentFileName;
  final String? currentPath;
  final int completed;
  final int total;
  final int failed;
  final String? message;

  static const idle = BackupStatus(phase: BackupPhase.idle);

  bool get isWorking => phase == BackupPhase.working;
  bool get isSuccess => phase == BackupPhase.success;
  bool get isIdle => phase == BackupPhase.idle;

  double get progress {
    if (total <= 0) return 0;
    return (completed + failed) / total;
  }

  BackupStatus copyWith({
    BackupPhase? phase,
    String? currentFileName,
    String? currentPath,
    int? completed,
    int? total,
    int? failed,
    String? message,
    bool clearCurrent = false,
  }) {
    return BackupStatus(
      phase: phase ?? this.phase,
      currentFileName: clearCurrent
          ? null
          : (currentFileName ?? this.currentFileName),
      currentPath: clearCurrent ? null : (currentPath ?? this.currentPath),
      completed: completed ?? this.completed,
      total: total ?? this.total,
      failed: failed ?? this.failed,
      message: message ?? this.message,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BackupStatus &&
          phase == other.phase &&
          currentFileName == other.currentFileName &&
          currentPath == other.currentPath &&
          completed == other.completed &&
          total == other.total &&
          failed == other.failed &&
          message == other.message;

  @override
  int get hashCode => Object.hash(
    phase,
    currentFileName,
    currentPath,
    completed,
    total,
    failed,
    message,
  );
}

/// Derives [BackupStatus] from job counters — pure function used by UI + tests.
BackupStatus deriveBackupStatus({
  required bool running,
  required int completed,
  required int total,
  required int failed,
  String? currentFileName,
  String? currentPath,
  String? errorMessage,
}) {
  if (running) {
    return BackupStatus(
      phase: BackupPhase.working,
      currentFileName: currentFileName,
      currentPath: currentPath,
      completed: completed,
      total: total,
      failed: failed,
      message: errorMessage,
    );
  }
  if (total > 0 && completed + failed >= total) {
    if (failed == 0) {
      return BackupStatus(
        phase: BackupPhase.success,
        completed: completed,
        total: total,
        failed: 0,
        message: 'All $completed photos are safe on Pixelfox',
      );
    }
    return BackupStatus(
      phase: BackupPhase.failed,
      completed: completed,
      total: total,
      failed: failed,
      message: '$failed of $total uploads failed',
    );
  }
  if (errorMessage != null && errorMessage.isNotEmpty) {
    return BackupStatus(
      phase: BackupPhase.failed,
      completed: completed,
      total: total,
      failed: failed,
      message: errorMessage,
    );
  }
  return BackupStatus.idle.copyWith(
    completed: completed,
    total: total,
    failed: failed,
  );
}
