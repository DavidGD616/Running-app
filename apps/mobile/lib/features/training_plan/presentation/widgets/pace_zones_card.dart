import 'package:flutter/material.dart';

import '../../../../core/utils/unit_formatter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/section_label.dart';
import '../../../../features/user_preferences/domain/user_preferences.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../strava/domain/models/strava_coaching_profile.dart';

class PaceZonesCard extends StatelessWidget {
  const PaceZonesCard({
    super.key,
    required this.paceZones,
    required this.unitSystem,
    required this.l10n,
  });

  final StravaPaceZones paceZones;
  final UnitSystem unitSystem;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final zones = <({String label, StravaPaceZone zone})>[
      (
        label: l10n.onboardingStravaAnalysisPaceZoneRecovery,
        zone: paceZones.recovery,
      ),
      (label: l10n.onboardingStravaAnalysisPaceZoneEasy, zone: paceZones.easy),
      (
        label: l10n.onboardingStravaAnalysisPaceZoneLongRun,
        zone: paceZones.longRun,
      ),
      (
        label: l10n.onboardingStravaAnalysisPaceZoneSteady,
        zone: paceZones.steady,
      ),
      (
        label: l10n.onboardingStravaAnalysisPaceZoneTempo,
        zone: paceZones.tempo,
      ),
      (
        label: l10n.onboardingStravaAnalysisPaceZoneThreshold,
        zone: paceZones.threshold,
      ),
      (
        label: l10n.onboardingStravaAnalysisPaceZoneRace,
        zone: paceZones.racePace,
      ),
      (
        label: l10n.onboardingStravaAnalysisPaceZoneIntervals,
        zone: paceZones.intervals,
      ),
      (
        label: l10n.onboardingStravaAnalysisPaceZoneStrides,
        zone: paceZones.strides,
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: AppColors.backgroundCard),
      ),
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(label: l10n.planGuidancePaceZonesTitle),
          const SizedBox(height: AppSpacing.md),
          ...zones.asMap().entries.map((entry) {
            final isLast = entry.key == zones.length - 1;
            final item = entry.value;

            return Column(
              children: [
                _PaceZoneRow(
                  label: item.label,
                  zone: item.zone,
                  unitSystem: unitSystem,
                  l10n: l10n,
                ),
                if (!isLast) ...[
                  const SizedBox(height: AppSpacing.sm),
                  const _SectionDivider(),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _PaceZoneRow extends StatelessWidget {
  const _PaceZoneRow({
    required this.label,
    required this.zone,
    required this.unitSystem,
    required this.l10n,
  });

  final String label;
  final StravaPaceZone zone;
  final UnitSystem unitSystem;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: AppTypography.bodyMedium)),
        Text(
          _formatZoneRange(zone, unitSystem: unitSystem, l10n: l10n),
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, color: AppColors.backgroundCard);
  }
}

String _formatZoneRange(
  StravaPaceZone zone, {
  required UnitSystem unitSystem,
  required AppLocalizations l10n,
}) {
  final paceUnit = UnitFormatter.paceLabel(unitSystem, l10n);

  final minPace = _formatPace(zone.paceMinSecPerKm, unitSystem: unitSystem);
  final maxPace = _formatPace(zone.paceMaxSecPerKm, unitSystem: unitSystem);

  if (minPace.isEmpty && maxPace.isEmpty) return '—';
  if (minPace.isEmpty) {
    return l10n.planGuidanceAtMostPace(maxPace, paceUnit);
  }
  if (maxPace.isEmpty) {
    return l10n.planGuidanceAtLeastPace(minPace, paceUnit);
  }

  return l10n.onboardingStravaAnalysisPaceRange(minPace, maxPace, paceUnit);
}

String _formatPace(int? paceSecondsPerKm, {required UnitSystem unitSystem}) {
  if (paceSecondsPerKm == null) return '';

  final paceSeconds = unitSystem == UnitSystem.km
      ? paceSecondsPerKm.toDouble()
      : paceSecondsPerKm * 1.609344;

  if (paceSeconds <= 0) return '';
  final rounded = paceSeconds.round();
  final minutes = rounded ~/ 60;
  final seconds = rounded % 60;
  return '${minutes.toString()}:${seconds.toString().padLeft(2, '0')}';
}
