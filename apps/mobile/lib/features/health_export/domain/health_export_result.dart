/// Result of attempting to export a run to Apple Health.
sealed class HealthExportResult {
  const HealthExportResult();
}

class HealthExportSuccess extends HealthExportResult {
  const HealthExportSuccess();
}

class HealthExportFailure extends HealthExportResult {
  const HealthExportFailure(this.reason);
  final String reason;
}
