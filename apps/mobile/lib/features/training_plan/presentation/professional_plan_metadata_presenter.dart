import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/models/professional_plan_metadata.dart';
import '../domain/models/training_plan.dart';

class ProfessionalPlanMetadataRow {
  const ProfessionalPlanMetadataRow({required this.label, required this.value});

  final String label;
  final String value;
}

List<ProfessionalPlanMetadataRow> professionalPlanMetadataRows({
  required TrainingPlan plan,
  required AppLocalizations l10n,
}) {
  final rows = <ProfessionalPlanMetadataRow>[];
  final brief = plan.coachingBriefSnapshot;
  final readiness = brief?.readinessLevel;
  final confidence = plan.confidence ?? brief?.confidence;
  final source = brief?.source;
  final currentVolume = brief?.currentVolumeKmPerWeek;
  final runsPerWeek = brief?.currentRunsPerWeek;
  final phaseStrategy = plan.phaseStrategy.isNotEmpty
      ? plan.phaseStrategy
      : brief?.phaseStrategy ?? const <PhaseStrategy>[];
  final evidenceTarget = plan.evidenceTarget ?? brief?.evidenceTarget;
  final ambitiousTarget = plan.ambitiousTarget ?? brief?.ambitiousTarget;
  final rationale = plan.planRationale.isNotEmpty
      ? plan.planRationale.first
      : brief != null && brief.rationale.isNotEmpty
      ? brief.rationale.first
      : null;

  if (readiness != null) {
    rows.add(
      ProfessionalPlanMetadataRow(
        label: l10n.planMetadataReadinessLabel,
        value: _readinessLabel(readiness, l10n),
      ),
    );
  }

  if (confidence != null || source != null) {
    rows.add(
      ProfessionalPlanMetadataRow(
        label: l10n.planMetadataConfidenceLabel,
        value: [
          if (confidence != null) _confidenceLabel(confidence, l10n),
          if (source != null) _sourceLabel(source, l10n),
        ].join(' · '),
      ),
    );
  }

  if (currentVolume != null || runsPerWeek != null) {
    rows.add(
      ProfessionalPlanMetadataRow(
        label: l10n.planMetadataCurrentVolumeLabel,
        value: _currentVolumeLabel(
          volumeKm: currentVolume,
          runsPerWeek: runsPerWeek,
          l10n: l10n,
        ),
      ),
    );
  }

  if (evidenceTarget != null || ambitiousTarget != null) {
    rows.add(
      ProfessionalPlanMetadataRow(
        label: l10n.planMetadataTargetsLabel,
        value: _targetsLabel(
          evidenceTarget: evidenceTarget,
          ambitiousTarget: ambitiousTarget,
          l10n: l10n,
        ),
      ),
    );
  }

  if (phaseStrategy.isNotEmpty) {
    rows.add(
      ProfessionalPlanMetadataRow(
        label: l10n.planMetadataPhaseStrategyLabel,
        value: phaseStrategy
            .take(4)
            .map(
              (phase) => l10n.planMetadataPhaseWeeks(
                _phaseLabel(phase.phase, l10n),
                phase.weeks,
              ),
            )
            .join(' · '),
      ),
    );
  }

  if (rationale != null && rationale.trim().isNotEmpty) {
    rows.add(
      ProfessionalPlanMetadataRow(
        label: l10n.planMetadataRationaleLabel,
        value: rationale.trim(),
      ),
    );
  }

  return rows;
}

String _currentVolumeLabel({
  required double? volumeKm,
  required double? runsPerWeek,
  required AppLocalizations l10n,
}) {
  final parts = <String>[];
  if (volumeKm != null) {
    parts.add(
      l10n.planMetadataVolumeValue(_formatNumber(volumeKm, l10n.localeName)),
    );
  }
  if (runsPerWeek != null) {
    parts.add(
      l10n.planMetadataRunsValue(_formatNumber(runsPerWeek, l10n.localeName)),
    );
  }
  return parts.join(' · ');
}

String _targetsLabel({
  required CoachingTarget? evidenceTarget,
  required CoachingTarget? ambitiousTarget,
  required AppLocalizations l10n,
}) {
  final parts = <String>[];
  final evidence = _targetLabel(evidenceTarget, l10n);
  if (evidence != null) {
    parts.add(l10n.planMetadataEvidenceTargetValue(evidence));
  }
  final ambitious = _targetLabel(ambitiousTarget, l10n);
  if (ambitious != null) {
    parts.add(l10n.planMetadataAmbitiousTargetValue(ambitious));
  }
  return parts.join(' · ');
}

String? _targetLabel(CoachingTarget? target, AppLocalizations l10n) {
  if (target == null) return null;
  if (target.supported == false) {
    return l10n.planMetadataUnsupportedTarget;
  }
  if (target.time != null) return _formatDuration(target.time!);
  if (target.paceSecPerKm != null) {
    return l10n.planMetadataPaceValue(_formatPace(target.paceSecPerKm!));
  }
  return target.reason;
}

String _formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
}

String _formatPace(int secPerKm) {
  final minutes = secPerKm ~/ 60;
  final seconds = (secPerKm % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

String _formatNumber(double value, String locale) {
  final formatter = NumberFormat.decimalPattern(locale);
  if (value == value.roundToDouble()) {
    formatter
      ..minimumFractionDigits = 0
      ..maximumFractionDigits = 0;
  } else {
    formatter
      ..minimumFractionDigits = 1
      ..maximumFractionDigits = 1;
  }
  return formatter.format(value);
}

String _readinessLabel(CoachingReadinessLevel value, AppLocalizations l10n) {
  return switch (value) {
    CoachingReadinessLevel.raceReady => l10n.planMetadataReadinessRaceReady,
    CoachingReadinessLevel.prepared => l10n.planMetadataReadinessPrepared,
    CoachingReadinessLevel.developing => l10n.planMetadataReadinessDeveloping,
    CoachingReadinessLevel.underprepared =>
      l10n.planMetadataReadinessUnderprepared,
    CoachingReadinessLevel.unsupported => l10n.planMetadataReadinessUnsupported,
  };
}

String _confidenceLabel(CoachingConfidence value, AppLocalizations l10n) {
  return switch (value) {
    CoachingConfidence.high => l10n.planMetadataConfidenceHigh,
    CoachingConfidence.medium => l10n.planMetadataConfidenceMedium,
    CoachingConfidence.limited => l10n.planMetadataConfidenceLimited,
  };
}

String _sourceLabel(CoachingSource value, AppLocalizations l10n) {
  return switch (value) {
    CoachingSource.strava => l10n.planMetadataSourceStrava,
    CoachingSource.manual => l10n.planMetadataSourceManual,
    CoachingSource.mixed => l10n.planMetadataSourceMixed,
    CoachingSource.unknown => l10n.planMetadataSourceUnknown,
  };
}

String _phaseLabel(CoachingPhase value, AppLocalizations l10n) {
  return switch (value) {
    CoachingPhase.base => l10n.planMetadataPhaseBase,
    CoachingPhase.build => l10n.planMetadataPhaseBuild,
    CoachingPhase.specific => l10n.planMetadataPhaseSpecific,
    CoachingPhase.peak => l10n.planMetadataPhasePeak,
    CoachingPhase.taperRace => l10n.planMetadataPhaseTaperRace,
    CoachingPhase.safeBuild => l10n.planMetadataPhaseSafeBuild,
    CoachingPhase.unsupportedFallback =>
      l10n.planMetadataPhaseUnsupportedFallback,
  };
}
