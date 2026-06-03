import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/unit_formatter.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_progress_bar.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../integrations/domain/models/device_connection.dart';
import '../../../integrations/presentation/device_connection_provider.dart';
import '../../../strava/data/strava_service.dart';
import '../../../strava/domain/athlete_summary.dart';
import '../../../user_preferences/domain/user_preferences.dart';
import '../../../user_preferences/presentation/user_preferences_provider.dart';
import '../onboarding_provider.dart';

class StravaAnalysisScreen extends ConsumerStatefulWidget {
  const StravaAnalysisScreen({super.key});

  @override
  ConsumerState<StravaAnalysisScreen> createState() =>
      _StravaAnalysisScreenState();
}

class _StravaAnalysisScreenState extends ConsumerState<StravaAnalysisScreen> {
  bool _isDisconnecting = false;
  String? _disconnectErrorMessage;

  void _useStravaAnalysis() {
    context.push(RouteNames.raceTarget);
  }

  void _continueWithManualDetails() {
    ref.read(onboardingProvider.notifier).useManualFitnessInput();
    context.push(RouteNames.manualFitness);
  }

  Future<void> _disconnectStrava() async {
    if (_isDisconnecting) return;

    setState(() {
      _isDisconnecting = true;
      _disconnectErrorMessage = null;
    });
    final l10n = AppLocalizations.of(context)!;
    try {
      await ref.read(stravaServiceProvider).disconnect();
      await ref
          .read(deviceConnectionsProvider.notifier)
          .removeConnectionForVendor(IntegrationVendor.strava);
      await ref.read(onboardingProvider.notifier).clearStravaFitness();
      if (!mounted) return;
      context.go(RouteNames.manualFitness);
    } catch (_) {
      if (mounted) {
        setState(() {
          _disconnectErrorMessage =
              l10n.onboardingStravaAnalysisDisconnectError;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isDisconnecting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final dateFormatter = DateFormat.yMMMd(locale);
    final numberFormatter = NumberFormat.decimalPattern(locale);
    final distanceFormatter = NumberFormat.decimalPattern(locale)
      ..minimumFractionDigits = 1
      ..maximumFractionDigits = 1;
    final compactDistanceFormatter = NumberFormat.decimalPattern(locale)
      ..maximumFractionDigits = 1;
    final unitSystem =
        ref.watch(userPreferencesProvider).value?.unitSystem ?? UnitSystem.km;
    final profile = ref
        .watch(onboardingProvider)
        .value
        ?.fitness
        .stravaCoachingProfile;

    final confidence = profile?.dataConfidence ?? StravaDataConfidence.limited;
    final hasUsefulStravaAnalysis =
        profile != null && confidence == StravaDataConfidence.high;
    final primaryLabel = hasUsefulStravaAnalysis
        ? l10n.onboardingStravaAnalysisUseAction
        : l10n.onboardingStravaAnalysisManualContinueAction;

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                AppSpacing.xs,
                AppSpacing.screen,
                0,
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => context.pop(),
                        child: SizedBox(
                          width: 48,
                          height: 48,
                          child: Center(
                            child: SvgPicture.asset(
                              'assets/icons/chevron_left.svg',
                              width: 24,
                              height: 24,
                              colorFilter: const ColorFilter.mode(
                                AppColors.textPrimary,
                                BlendMode.srcIn,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Text(
                        l10n.onboardingStep(3, 9),
                        style: AppTypography.textTheme.labelSmall?.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const Padding(
                    padding: EdgeInsets.only(left: AppSpacing.sm),
                    child: AppProgressBar(current: 3, total: 9),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screen,
                  AppSpacing.lg,
                  AppSpacing.screen,
                  AppSpacing.xl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.onboardingStravaAnalysisTitle,
                      style: AppTypography.headlineMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      l10n.onboardingStravaAnalysisSubtitle,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _AnalysisStatusCard(
                      confidenceLabel: _confidenceLabel(confidence, l10n),
                      confidenceDescription: _confidenceDescription(
                        profile,
                        confidence,
                        l10n,
                      ),
                      windowLabel: profile == null
                          ? l10n.onboardingStravaAnalysisNoDataWindow
                          : l10n.onboardingStravaAnalysisWindow(
                              dateFormatter.format(
                                profile.provenance.dataFromDate,
                              ),
                              dateFormatter.format(
                                profile.provenance.dataThroughDate,
                              ),
                              profile.provenance.runActivityCount,
                            ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    if (profile == null)
                      _EmptyAnalysisCard(
                        title: l10n.onboardingStravaAnalysisNoUsefulDataTitle,
                        body: l10n.onboardingStravaAnalysisNoUsefulDataBody,
                      )
                    else ...[
                      _EvidenceSection(
                        title: l10n.onboardingStravaAnalysisTrainingBaseSection,
                        points: profile.trainingBase,
                        dateFormatter: dateFormatter,
                        numberFormatter: numberFormatter,
                        distanceFormatter: distanceFormatter,
                        unitSystem: unitSystem,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _EvidenceSection(
                        title: l10n.onboardingStravaAnalysisEnduranceSection,
                        points: profile.endurance,
                        dateFormatter: dateFormatter,
                        numberFormatter: numberFormatter,
                        distanceFormatter: distanceFormatter,
                        unitSystem: unitSystem,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _PaceZonesSection(
                        zones: profile.paceZones,
                        speedMarkers: profile.speedMarkers,
                        dateFormatter: dateFormatter,
                        numberFormatter: numberFormatter,
                        distanceFormatter: distanceFormatter,
                        unitSystem: unitSystem,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _SummarySection(
                        title: l10n.onboardingStravaAnalysisTerrainSection,
                        rows: [
                          _SummaryRowData(
                            label: l10n.onboardingStravaAnalysisTerrainSection,
                            value: _terrainLabel(profile.terrain, l10n),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _GuardrailsSection(
                        guardrails: profile.recoveryGuardrails,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _RaceTargetSection(
                        raceTargets: profile.raceTargets,
                        dateFormatter: dateFormatter,
                        numberFormatter: numberFormatter,
                        distanceFormatter: distanceFormatter,
                        compactDistanceFormatter: compactDistanceFormatter,
                        unitSystem: unitSystem,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _SummarySection(
                        title: l10n.onboardingStravaAnalysisPlanFocusSection,
                        rows: [
                          _SummaryRowData(
                            label:
                                l10n.onboardingStravaAnalysisPlanFocusSection,
                            value: _planFocusLabel(
                              profile.planFocus.category,
                              l10n,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen,
                AppSpacing.sm,
                AppSpacing.screen,
                AppSpacing.xl,
              ),
              child: Column(
                children: [
                  if (_disconnectErrorMessage != null) ...[
                    Text(
                      _disconnectErrorMessage!,
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  AppButton(
                    label: primaryLabel,
                    onPressed: hasUsefulStravaAnalysis
                        ? _useStravaAnalysis
                        : _continueWithManualDetails,
                  ),
                  if (hasUsefulStravaAnalysis) ...[
                    const SizedBox(height: AppSpacing.md),
                    AppButton(
                      label: l10n.onboardingStravaAnalysisManualAction,
                      variant: AppButtonVariant.secondary,
                      onPressed: _continueWithManualDetails,
                    ),
                  ],
                  if (profile != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    AppButton(
                      label: l10n.onboardingStravaAnalysisDisconnectAction,
                      variant: AppButtonVariant.text,
                      isLoading: _isDisconnecting,
                      onPressed: _isDisconnecting ? null : _disconnectStrava,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnalysisStatusCard extends StatelessWidget {
  const _AnalysisStatusCard({
    required this.confidenceLabel,
    required this.confidenceDescription,
    required this.windowLabel,
  });

  final String confidenceLabel;
  final String confidenceDescription;
  final String windowLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.onboardingStravaAnalysisConfidenceLabel,
            style: AppTypography.labelMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            confidenceLabel,
            style: AppTypography.titleLarge.copyWith(
              color: AppColors.accentPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            confidenceDescription,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            windowLabel,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyAnalysisCard extends StatelessWidget {
  const _EmptyAnalysisCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            body,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _EvidenceSection extends StatelessWidget {
  const _EvidenceSection({
    required this.title,
    required this.points,
    required this.dateFormatter,
    required this.numberFormatter,
    required this.distanceFormatter,
    required this.unitSystem,
  });

  final String title;
  final List<StravaEvidencePoint> points;
  final DateFormat dateFormatter;
  final NumberFormat numberFormatter;
  final NumberFormat distanceFormatter;
  final UnitSystem unitSystem;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return _SummarySection(
      title: title,
      rows: points.isEmpty
          ? [
              _SummaryRowData(
                label: l10n.onboardingStravaAnalysisNoUsefulDataTitle,
                value: l10n.onboardingStravaAnalysisNoSectionData,
              ),
            ]
          : points
                .map(
                  (point) => _SummaryRowData(
                    label: _evidenceMetricLabel(point.metric, l10n),
                    value: l10n.onboardingStravaAnalysisEvidenceValue(
                      _formatEvidenceValue(
                        point,
                        unitSystem,
                        l10n,
                        numberFormatter,
                        distanceFormatter,
                      ),
                      dateFormatter.format(point.date),
                    ),
                  ),
                )
                .toList(growable: false),
    );
  }
}

class _PaceZonesSection extends StatelessWidget {
  const _PaceZonesSection({
    required this.zones,
    required this.speedMarkers,
    required this.dateFormatter,
    required this.numberFormatter,
    required this.distanceFormatter,
    required this.unitSystem,
  });

  final StravaPaceZones zones;
  final List<StravaEvidencePoint> speedMarkers;
  final DateFormat dateFormatter;
  final NumberFormat numberFormatter;
  final NumberFormat distanceFormatter;
  final UnitSystem unitSystem;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final rows = <_SummaryRowData>[
      ...speedMarkers.map(
        (point) => _SummaryRowData(
          label: _evidenceMetricLabel(point.metric, l10n),
          value: l10n.onboardingStravaAnalysisEvidenceValue(
            _formatEvidenceValue(
              point,
              unitSystem,
              l10n,
              numberFormatter,
              distanceFormatter,
            ),
            dateFormatter.format(point.date),
          ),
        ),
      ),
      _paceZoneRow(
        l10n.onboardingStravaAnalysisPaceZoneRecovery,
        zones.recovery,
        l10n,
      ),
      _paceZoneRow(l10n.onboardingStravaAnalysisPaceZoneEasy, zones.easy, l10n),
      _paceZoneRow(
        l10n.onboardingStravaAnalysisPaceZoneLongRun,
        zones.longRun,
        l10n,
      ),
      _paceZoneRow(
        l10n.onboardingStravaAnalysisPaceZoneSteady,
        zones.steady,
        l10n,
      ),
      _paceZoneRow(
        l10n.onboardingStravaAnalysisPaceZoneTempo,
        zones.tempo,
        l10n,
      ),
      _paceZoneRow(
        l10n.onboardingStravaAnalysisPaceZoneThreshold,
        zones.threshold,
        l10n,
      ),
      _paceZoneRow(
        l10n.onboardingStravaAnalysisPaceZoneRace,
        zones.racePace,
        l10n,
      ),
      _paceZoneRow(
        l10n.onboardingStravaAnalysisPaceZoneIntervals,
        zones.intervals,
        l10n,
      ),
      _paceZoneRow(
        l10n.onboardingStravaAnalysisPaceZoneStrides,
        zones.strides,
        l10n,
      ),
    ].where((row) => row.value.isNotEmpty).toList(growable: false);

    return _SummarySection(
      title: l10n.onboardingStravaAnalysisSpeedSection,
      rows: rows.isEmpty
          ? [
              _SummaryRowData(
                label: l10n.onboardingStravaAnalysisSpeedSection,
                value: l10n.onboardingStravaAnalysisNoSectionData,
              ),
            ]
          : rows,
    );
  }

  _SummaryRowData _paceZoneRow(
    String label,
    StravaPaceZone zone,
    AppLocalizations l10n,
  ) {
    if (zone.paceMinSecPerKm == null && zone.paceMaxSecPerKm == null) {
      return _SummaryRowData(label: label, value: '');
    }

    final unit = UnitFormatter.paceLabel(unitSystem, l10n);
    final minPace = zone.paceMinSecPerKm;
    final maxPace = zone.paceMaxSecPerKm;
    return _SummaryRowData(
      label: label,
      value: minPace != null && maxPace != null
          ? l10n.onboardingStravaAnalysisPaceRange(
              _formatPace(minPace, unitSystem),
              _formatPace(maxPace, unitSystem),
              unit,
            )
          : l10n.onboardingStravaAnalysisPaceSingle(
              _formatPace((minPace ?? maxPace)!, unitSystem),
              unit,
            ),
    );
  }
}

class _GuardrailsSection extends StatelessWidget {
  const _GuardrailsSection({required this.guardrails});

  final List<StravaGuardrail> guardrails;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _SummarySection(
      title: l10n.onboardingStravaAnalysisRecoverySection,
      rows: guardrails.isEmpty
          ? [
              _SummaryRowData(
                label: l10n.onboardingStravaAnalysisRecoverySection,
                value: l10n.onboardingStravaAnalysisNoGuardrails,
              ),
            ]
          : guardrails
                .map(
                  (guardrail) => _SummaryRowData(
                    label: _guardrailLabel(guardrail.category, l10n),
                    value: _guardrailDescription(guardrail.category, l10n),
                  ),
                )
                .toList(growable: false),
    );
  }
}

class _RaceTargetSection extends StatelessWidget {
  const _RaceTargetSection({
    required this.raceTargets,
    required this.dateFormatter,
    required this.numberFormatter,
    required this.distanceFormatter,
    required this.compactDistanceFormatter,
    required this.unitSystem,
  });

  final List<StravaRaceTargetEstimate> raceTargets;
  final DateFormat dateFormatter;
  final NumberFormat numberFormatter;
  final NumberFormat distanceFormatter;
  final NumberFormat compactDistanceFormatter;
  final UnitSystem unitSystem;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _SummarySection(
      title: l10n.onboardingStravaAnalysisRaceTargetSection,
      rows: raceTargets.isEmpty
          ? [
              _SummaryRowData(
                label: l10n.onboardingStravaAnalysisRaceTargetSection,
                value: l10n.onboardingStravaAnalysisNoRaceTarget,
              ),
            ]
          : raceTargets
                .map(
                  (target) => _SummaryRowData(
                    label: _formatLocalizedDistanceLabel(
                      target.distanceKm,
                      unitSystem,
                      l10n,
                      compactDistanceFormatter,
                    ),
                    value: _raceTargetValue(
                      target,
                      l10n,
                      dateFormatter,
                      numberFormatter,
                      distanceFormatter,
                    ),
                  ),
                )
                .toList(growable: false),
    );
  }

  String _raceTargetValue(
    StravaRaceTargetEstimate target,
    AppLocalizations l10n,
    DateFormat dateFormatter,
    NumberFormat numberFormatter,
    NumberFormat distanceFormatter,
  ) {
    final base = l10n.onboardingStravaAnalysisRaceTargetValue(
      _formatDuration(target.primaryTime),
      _confidenceLabel(target.confidence, l10n),
    );
    final stretch = target.stretchTime == null
        ? null
        : l10n.onboardingStravaAnalysisRaceTargetStretch(
            _formatDuration(target.stretchTime!),
          );
    final evidence = target.evidence.isEmpty
        ? null
        : l10n.onboardingStravaAnalysisEvidenceValue(
            _formatEvidenceValue(
              target.evidence.first,
              unitSystem,
              l10n,
              numberFormatter,
              distanceFormatter,
            ),
            dateFormatter.format(target.evidence.first.date),
          );

    return [base, ?stretch, ?evidence].join('\n');
  }
}

class _SummarySection extends StatelessWidget {
  const _SummarySection({required this.title, required this.rows});

  final String title;
  final List<_SummaryRowData> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.titleMedium),
          const SizedBox(height: AppSpacing.md),
          for (var index = 0; index < rows.length; index++) ...[
            if (index > 0) const SizedBox(height: AppSpacing.md),
            _SummaryRow(row: rows[index]),
          ],
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.row});

  final _SummaryRowData row;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 5,
          child: Text(
            row.label,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          flex: 6,
          child: Text(
            row.value,
            textAlign: TextAlign.right,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _SummaryRowData {
  const _SummaryRowData({required this.label, required this.value});

  final String label;
  final String value;
}

String _confidenceLabel(
  StravaDataConfidence confidence,
  AppLocalizations l10n,
) {
  return switch (confidence) {
    StravaDataConfidence.high => l10n.onboardingStravaAnalysisConfidenceStrong,
    StravaDataConfidence.medium => l10n.onboardingStravaAnalysisConfidenceWeak,
    StravaDataConfidence.limited =>
      l10n.onboardingStravaAnalysisConfidenceNoUsefulData,
  };
}

String _confidenceDescription(
  StravaCoachingProfile? profile,
  StravaDataConfidence confidence,
  AppLocalizations l10n,
) {
  if (profile == null) return l10n.onboardingStravaAnalysisNoUsefulDataBody;
  return switch (confidence) {
    StravaDataConfidence.high =>
      l10n.onboardingStravaAnalysisConfidenceStrongBody,
    StravaDataConfidence.medium =>
      l10n.onboardingStravaAnalysisConfidenceWeakBody,
    StravaDataConfidence.limited =>
      l10n.onboardingStravaAnalysisConfidenceNoUsefulDataBody,
  };
}

String _evidenceMetricLabel(String metric, AppLocalizations l10n) {
  return switch (metric) {
    'training_base_weekly_km' =>
      l10n.onboardingStravaAnalysisMetricWeeklyVolume,
    'training_base_runs_per_week' =>
      l10n.onboardingStravaAnalysisMetricRunsPerWeek,
    'endurance_long_run_km' => l10n.onboardingStravaAnalysisMetricLongRun,
    'endurance_longest_layoff_days' =>
      l10n.onboardingStravaAnalysisMetricLongestLayoff,
    'speed_marker_hard_pace' => l10n.onboardingStravaAnalysisMetricHardPace,
    'speed_marker_easy_pace' => l10n.onboardingStravaAnalysisMetricEasyPace,
    'speed_marker_threshold_pace' =>
      l10n.onboardingStravaAnalysisMetricThresholdPace,
    'race_target_reference_effort' || 'race_target_reference_run' =>
      l10n.onboardingStravaAnalysisMetricRaceReference,
    _ => l10n.onboardingStravaAnalysisMetricTrainingSignal,
  };
}

String _formatEvidenceValue(
  StravaEvidencePoint point,
  UnitSystem unitSystem,
  AppLocalizations l10n,
  NumberFormat numberFormatter,
  NumberFormat distanceFormatter,
) {
  return switch (point.unit) {
    'km_per_week' => l10n.onboardingStravaAnalysisPerWeekValue(
      _formatLocalizedDistanceValue(
        point.value.toDouble(),
        unitSystem,
        distanceFormatter,
      ),
      UnitFormatter.unitLabel(unitSystem, l10n),
    ),
    'km' => _formatLocalizedDistanceLabel(
      point.value.toDouble(),
      unitSystem,
      l10n,
      distanceFormatter,
    ),
    'sec_per_km' => l10n.onboardingStravaAnalysisPaceSingle(
      _formatPace(point.value.toDouble().round(), unitSystem),
      UnitFormatter.paceLabel(unitSystem, l10n),
    ),
    'runs_per_week' => l10n.onboardingStravaAnalysisRunsPerWeekValue(
      numberFormatter.format(point.value),
    ),
    'days' => l10n.onboardingStravaAnalysisDaysValue(point.value.round()),
    'sec' => _formatDuration(Duration(seconds: point.value.round())),
    _ => numberFormatter.format(point.value),
  };
}

String _formatLocalizedDistanceValue(
  double km,
  UnitSystem unitSystem,
  NumberFormat formatter,
) {
  final value = unitSystem == UnitSystem.km ? km : km * 0.621371;
  return formatter.format(value);
}

String _formatLocalizedDistanceLabel(
  double km,
  UnitSystem unitSystem,
  AppLocalizations l10n,
  NumberFormat formatter,
) {
  return '${_formatLocalizedDistanceValue(km, unitSystem, formatter)} '
      '${UnitFormatter.unitLabel(unitSystem, l10n)}';
}

String _formatPace(int secondsPerKm, UnitSystem unitSystem) {
  final seconds = unitSystem == UnitSystem.km
      ? secondsPerKm
      : (secondsPerKm * 1.609344).round();
  final minutes = seconds ~/ 60;
  final remainder = (seconds % 60).toString().padLeft(2, '0');
  return '$minutes:$remainder';
}

String _formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (hours > 0) return '$hours:$minutes:$seconds';
  return '$minutes:$seconds';
}

String _terrainLabel(StravaTerrainProfile terrain, AppLocalizations l10n) {
  return switch (terrain) {
    StravaTerrainProfile.flat => l10n.terrainFlat,
    StravaTerrainProfile.rolling => l10n.terrainSomeHills,
    StravaTerrainProfile.hilly => l10n.terrainHilly,
    StravaTerrainProfile.notSure => l10n.notSure,
  };
}

String _guardrailLabel(String category, AppLocalizations l10n) {
  return switch (category) {
    'recovery_load_spike' =>
      l10n.onboardingStravaAnalysisGuardrailLoadSpikeTitle,
    'recovery_detraining' =>
      l10n.onboardingStravaAnalysisGuardrailDetrainingTitle,
    'recovery_long_layoff' =>
      l10n.onboardingStravaAnalysisGuardrailLongLayoffTitle,
    'recovery_sparse_data' =>
      l10n.onboardingStravaAnalysisGuardrailSparseDataTitle,
    'recovery_pace_uncertainty' =>
      l10n.onboardingStravaAnalysisGuardrailPaceUncertaintyTitle,
    'recovery_data_collection' =>
      l10n.onboardingStravaAnalysisGuardrailDataCollectionTitle,
    _ => l10n.onboardingStravaAnalysisGuardrailFallbackTitle,
  };
}

String _guardrailDescription(String category, AppLocalizations l10n) {
  return switch (category) {
    'recovery_load_spike' =>
      l10n.onboardingStravaAnalysisGuardrailLoadSpikeBody,
    'recovery_detraining' =>
      l10n.onboardingStravaAnalysisGuardrailDetrainingBody,
    'recovery_long_layoff' =>
      l10n.onboardingStravaAnalysisGuardrailLongLayoffBody,
    'recovery_sparse_data' =>
      l10n.onboardingStravaAnalysisGuardrailSparseDataBody,
    'recovery_pace_uncertainty' =>
      l10n.onboardingStravaAnalysisGuardrailPaceUncertaintyBody,
    'recovery_data_collection' =>
      l10n.onboardingStravaAnalysisGuardrailDataCollectionBody,
    _ => l10n.onboardingStravaAnalysisGuardrailFallbackBody,
  };
}

String _planFocusLabel(String category, AppLocalizations l10n) {
  return switch (category) {
    'focus_data_collection' =>
      l10n.onboardingStravaAnalysisPlanFocusDataCollection,
    'focus_recovery_and_consistency' =>
      l10n.onboardingStravaAnalysisPlanFocusRecoveryConsistency,
    'focus_threshold_and_endurance' =>
      l10n.onboardingStravaAnalysisPlanFocusThresholdEndurance,
    'focus_endurance_and_speed' =>
      l10n.onboardingStravaAnalysisPlanFocusEnduranceSpeed,
    _ => l10n.onboardingStravaAnalysisPlanFocusFallback,
  };
}
