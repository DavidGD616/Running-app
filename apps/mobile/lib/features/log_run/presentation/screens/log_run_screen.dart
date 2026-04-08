import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/unit_formatter.dart';
import '../../../../core/widgets/app_header_bar.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../activity/activity.dart';
import '../../../pre_run/presentation/run_flow_context.dart';
import '../../../training_plan/presentation/training_plan_provider.dart';
import '../../../training_plan/domain/models/session_type.dart';
import '../../../user_preferences/domain/user_preferences.dart';
import '../../../user_preferences/presentation/user_preferences_provider.dart';

class LogRunScreen extends ConsumerStatefulWidget {
  const LogRunScreen({super.key, this.args});

  final LogRunArgs? args;

  @override
  ConsumerState<LogRunScreen> createState() => _LogRunScreenState();
}

class _LogRunScreenState extends ConsumerState<LogRunScreen> {
  ActivityPerceivedEffort? _selectedFeeling;
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveRun() async {
    final session = widget.args?.session;
    if (session == null || !session.isRunSession) {
      if (mounted) Navigator.of(context).maybePop();
      return;
    }

    final now = DateTime.now();
    final actualDuration = session.durationMinutes != null
        ? Duration(minutes: session.durationMinutes!)
        : null;
    final record = RunActivity(
      id: session.sessionId,
      linkedSessionId: session.sessionId,
      source: ActivitySource.plannedSession,
      completionStatus: ActivityCompletionStatus.completed,
      recordedAt: now,
      startedAt: actualDuration != null ? now.subtract(actualDuration) : now,
      endedAt: now,
      actualDuration: actualDuration,
      actualDistanceKm: session.distanceKm,
      actualElevationGainMeters: session.elevationGainMeters,
      perceivedEffort: _selectedFeeling,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );

    await ref.read(activitiesProvider.notifier).saveActivity(record);
    ref.read(trainingPlanProvider.notifier).recordCompletedRunFeedback(
      session: session,
      activityId: record.id,
      perceivedEffort: _selectedFeeling,
      checkIn: widget.args?.checkIn,
      notes: record.notes,
      recordedAt: now,
    );
    if (!mounted) return;
    context.go(RouteNames.today);
  }

  String _sessionTitle(SessionType type, AppLocalizations l10n) {
    switch (type) {
      case SessionType.restDay:
        return l10n.sessionTypeRestDay;
      case SessionType.easyRun:
        return l10n.weeklyPlanSessionEasyRun;
      case SessionType.longRun:
        return l10n.weeklyPlanSessionLongRun;
      case SessionType.progressionRun:
        return l10n.sessionTypeProgressionRun;
      case SessionType.intervals:
        return l10n.weeklyPlanSessionIntervals;
      case SessionType.hillRepeats:
        return l10n.sessionTypeHillRepeats;
      case SessionType.fartlek:
        return l10n.sessionTypeFartlek;
      case SessionType.tempoRun:
        return l10n.sessionTypeTempoRun;
      case SessionType.thresholdRun:
        return l10n.sessionTypeThresholdRun;
      case SessionType.racePaceRun:
        return l10n.sessionTypeRacePaceRun;
      case SessionType.recoveryRun:
        return l10n.weeklyPlanSessionRecoveryRun;
      case SessionType.crossTraining:
        return l10n.sessionTypeCrossTraining;
    }
  }

  String _feelingLabel(ActivityPerceivedEffort feeling, AppLocalizations l10n) {
    return switch (feeling) {
      ActivityPerceivedEffort.veryEasy => l10n.logSessionEasy,
      ActivityPerceivedEffort.easy => l10n.logSessionEasy,
      ActivityPerceivedEffort.moderate => l10n.logSessionModerate,
      ActivityPerceivedEffort.hard => l10n.logSessionHard,
      ActivityPerceivedEffort.veryHard => l10n.logSessionVeryHard,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final unitSystem =
        ref.watch(userPreferencesProvider).value?.unitSystem ?? UnitSystem.km;
    final session = widget.args?.session;
    final plannedDistanceKm = session?.distanceKm;
    final plannedDurationMinutes = session?.durationMinutes;
    final displayDistanceKm = plannedDistanceKm ?? 6.02;
    final displayDurationMinutes = plannedDurationMinutes ?? 45;
    final plannedTitle = session != null
        ? _sessionTitle(session.sessionType, l10n)
        : l10n.logSessionSessionName;
    final distanceLabel = UnitFormatter.formatDistanceValue(
      displayDistanceKm,
      unitSystem,
    );
    final distanceUnit = UnitFormatter.unitLabel(unitSystem, l10n);

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppDetailHeaderBar(
        title: l10n.logSessionTitle,
        onBack: () => Navigator.of(context).maybePop(),
      ),
      body: SafeArea(
        child: Column(
          children: [
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
                    _PlannedSessionCard(
                      label: l10n.logSessionPlannedSession,
                      sessionName: plannedTitle,
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    Row(
                      children: [
                        Expanded(
                          child: _MetricCard(
                            glowColor: const Color(0xFF00D4FF),
                            iconAsset: 'assets/icons/clock.svg',
                            label: l10n.logSessionDurationLabel,
                            value: displayDurationMinutes.toString(),
                            unit: l10n.logSessionMinUnit,
                            subtitle: l10n.logSessionActiveTime,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xl),
                        Expanded(
                          child: _MetricCard(
                            glowColor: const Color(0xFFFFC107),
                            iconAsset: 'assets/icons/activity.svg',
                            label: l10n.logSessionDistanceLabel,
                            value: distanceLabel,
                            unit: distanceUnit,
                            subtitle: l10n.logSessionPaceValue,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.xl),

                    Text(
                      l10n.logSessionHowDidItFeel,
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _FeelButton(
                                label: _feelingLabel(
                                  ActivityPerceivedEffort.easy,
                                  l10n,
                                ),
                                isSelected:
                                    _selectedFeeling ==
                                    ActivityPerceivedEffort.easy,
                                onTap: () => setState(
                                  () => _selectedFeeling =
                                      ActivityPerceivedEffort.easy,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: _FeelButton(
                                label: _feelingLabel(
                                  ActivityPerceivedEffort.moderate,
                                  l10n,
                                ),
                                isSelected:
                                    _selectedFeeling ==
                                    ActivityPerceivedEffort.moderate,
                                onTap: () => setState(
                                  () => _selectedFeeling =
                                      ActivityPerceivedEffort.moderate,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: [
                            Expanded(
                              child: _FeelButton(
                                label: _feelingLabel(
                                  ActivityPerceivedEffort.hard,
                                  l10n,
                                ),
                                isSelected:
                                    _selectedFeeling ==
                                    ActivityPerceivedEffort.hard,
                                onTap: () => setState(
                                  () => _selectedFeeling =
                                      ActivityPerceivedEffort.hard,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: _FeelButton(
                                label: _feelingLabel(
                                  ActivityPerceivedEffort.veryHard,
                                  l10n,
                                ),
                                isSelected:
                                    _selectedFeeling ==
                                    ActivityPerceivedEffort.veryHard,
                                onTap: () => setState(
                                  () => _selectedFeeling =
                                      ActivityPerceivedEffort.veryHard,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.xl),

                    Row(
                      children: [
                        Text(
                          l10n.logSessionNotes,
                          style: AppTypography.titleMedium.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          l10n.logSessionOptional,
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textDisabled,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.backgroundCard,
                        borderRadius: AppRadius.borderLg,
                        border: Border.all(color: AppColors.borderDefault),
                      ),
                      child: TextField(
                        controller: _notesController,
                        maxLines: 4,
                        minLines: 4,
                        style: AppTypography.bodyMedium,
                        decoration: InputDecoration(
                          hintText: l10n.logSessionNotesHint,
                          hintStyle: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textDisabled,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(AppSpacing.base),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            _SaveButton(label: l10n.logSessionSaveButton, onTap: _saveRun),
          ],
        ),
      ),
    );
  }
}

class _PlannedSessionCard extends StatelessWidget {
  const _PlannedSessionCard({required this.label, required this.sessionName});

  final String label;
  final String sessionName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base,
        vertical: AppSpacing.base,
      ),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.accentMuted,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: SvgPicture.asset(
                'assets/icons/calendar.svg',
                width: 24,
                height: 24,
                colorFilter: const ColorFilter.mode(
                  AppColors.accentPrimary,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.base),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textDisabled,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sessionName,
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.glowColor,
    required this.iconAsset,
    required this.label,
    required this.value,
    required this.unit,
    required this.subtitle,
  });

  final Color glowColor;
  final String iconAsset;
  final String label;
  final String value;
  final String unit;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: AppRadius.borderLg,
        boxShadow: [
          BoxShadow(color: glowColor, blurRadius: 0, spreadRadius: 1),
          BoxShadow(color: glowColor, blurRadius: 5),
          BoxShadow(
            color: glowColor.withValues(alpha: 0.3),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SvgPicture.asset(
            iconAsset,
            width: 26,
            height: 26,
            colorFilter: ColorFilter.mode(glowColor, BlendMode.srcIn),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            label,
            style: AppTypography.bodyMedium.copyWith(
              color: glowColor.withValues(alpha: 0.6),
              letterSpacing: 0.6,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: AppTypography.headlineLarge.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  unit,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeelButton extends StatelessWidget {
  const _FeelButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 48,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accentMuted : AppColors.backgroundCard,
          borderRadius: AppRadius.borderLg,
          border: Border.all(
            color: isSelected
                ? AppColors.accentPrimary
                : AppColors.borderDefault,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: AppTypography.titleMedium.copyWith(
              color: isSelected
                  ? AppColors.accentPrimary
                  : AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0.0, 0.4, 1.0],
          colors: [
            AppColors.backgroundPrimary.withValues(alpha: 0),
            AppColors.backgroundPrimary,
            AppColors.backgroundPrimary,
          ],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        AppSpacing.lg,
        AppSpacing.screen,
        AppSpacing.xl,
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.accentPrimary,
            borderRadius: AppRadius.borderLg,
            boxShadow: [
              BoxShadow(
                color: AppColors.accentPrimary.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.check,
                size: 20,
                color: AppColors.backgroundPrimary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                label,
                style: AppTypography.titleMedium.copyWith(
                  color: AppColors.backgroundPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
