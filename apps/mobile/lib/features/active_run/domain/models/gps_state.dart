enum GpsStatus {
  acquiring,
  ready,
  weak,
  lost,
  disabled,
}

class GpsFix {
  const GpsFix({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.timestamp,
  });

  final double latitude;
  final double longitude;
  final double accuracy;
  final DateTime timestamp;

  bool get isAccurate => accuracy <= 30;
  bool get isWeak => accuracy > 30 && accuracy <= 60;
  bool get isPoor => accuracy > 60;
}

class GpsState {
  const GpsState({
    required this.status,
    this.lastFix,
    required this.lastStatusChange,
  });

  factory GpsState.initial() => GpsState(
        status: GpsStatus.acquiring,
        lastStatusChange: DateTime.now(),
      );

  final GpsStatus status;
  final GpsFix? lastFix;
  final DateTime lastStatusChange;

  static const Duration _lostTimeout = Duration(seconds: 10);

  GpsState copyWith({
    GpsStatus? status,
    GpsFix? lastFix,
    DateTime? lastStatusChange,
  }) {
    return GpsState(
      status: status ?? this.status,
      lastFix: lastFix ?? this.lastFix,
      lastStatusChange: lastStatusChange ?? this.lastStatusChange,
    );
  }

  GpsState disable() {
    return GpsState(
      status: GpsStatus.disabled,
      lastFix: lastFix,
      lastStatusChange: DateTime.now(),
    );
  }

  GpsState enable() {
    return GpsState(
      status: GpsStatus.acquiring,
      lastFix: null,
      lastStatusChange: DateTime.now(),
    );
  }

  GpsState recordFix(GpsFix fix) {
    final now = DateTime.now();
    final newStatus = _computeStatus(fix, now);
    return GpsState(
      status: newStatus,
      lastFix: fix,
      lastStatusChange:
          newStatus != status ? now : lastStatusChange,
    );
  }

  GpsState checkLost() {
    final now = DateTime.now();
    final timeSinceLastFix = lastFix != null
        ? now.difference(lastFix!.timestamp)
        : const Duration(days: 1);
    final shouldBeLost =
        status != GpsStatus.disabled &&
        status != GpsStatus.lost &&
        (lastFix == null || timeSinceLastFix > _lostTimeout);
    if (shouldBeLost) {
      return GpsState(
        status: GpsStatus.lost,
        lastFix: lastFix,
        lastStatusChange: now,
      );
    }
    return this;
  }

  GpsStatus _computeStatus(GpsFix fix, DateTime now) {
    if (fix.isAccurate) {
      return GpsStatus.ready;
    } else if (fix.isWeak) {
      return GpsStatus.weak;
    } else {
      return GpsStatus.lost;
    }
  }

  bool get isReady => status == GpsStatus.ready;
  bool get isWeak => status == GpsStatus.weak;
  bool get isLost => status == GpsStatus.lost;
  bool get isDisabled => status == GpsStatus.disabled;
  bool get isAcquiring => status == GpsStatus.acquiring;
}
