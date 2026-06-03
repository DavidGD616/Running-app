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
import '../../../../core/widgets/section_label.dart';
import '../../../../core/widgets/session_row.dart';
import '../../../../core/widgets/stat_column.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../session_detail/presentation/screens/session_detail_screen.dart';
import '../../../training_plan/domain/models/plan_week.dart';
import '../../../training_plan/domain/models/session_type.dart';
import '../../../training_plan/domain/models/support_session.dart';
import '../../../training_plan/domain/models/training_plan.dart';
import '../../../training_plan/domain/models/training_session.dart';
import '../../../training_plan/domain/models/week_progress.dart';
import '../../../training_plan/presentation/training_plan_localization.dart';
import '../../../training_plan/presentation/training_plan_provider.dart';
import '../../../training_plan/presentation/widgets/pace_zones_card.dart';
import '../../../training_plan/presentation/widgets/race_guidance_section.dart';
import '../../../user_preferences/domain/user_preferences.dart';
import '../../../user_preferences/presentation/user_preferences_provider.dart';

// ── Screen ────────────────────────────────────────────────────────────────────

class FullPlanScreen extends ConsumerWidget {
  const FullPlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final plan = ref.watch(trainingPlanProvider).value;
    final unitSystem =
        ref.watch(userPreferencesProvider).value?.unitSystem ?? UnitSystem.km;

    if (plan == null) {
      return Scaffold(
        backgroundColor: AppColors.backgroundPrimary,
        appBar: AppDetailHeaderBar(
          title: l10n.fullPlanTitle,
          onBack: () => Navigator.of(context).maybePop(),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppDetailHeaderBar(
        title: l10n.fullPlanTitle,
        onBack: () => Navigator.of(context).maybePop(),
      ),
      body: SafeArea(
        top: false,
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
              _PlanNote(l10n: l10n),

              const SizedBox(height: AppSpacing.xl),

              if (plan.paceZones != null) ...[
                PaceZonesCard(
                  paceZones: plan.paceZones!,
                  unitSystem: unitSystem,
                  l10n: l10n,
                ),
                const SizedBox(height: AppSpacing.xl),
              ],

              if (plan.raceGuidance != null) ...[
                RaceGuidanceSection(guidance: plan.raceGuidance!, l10n: l10n),
                const SizedBox(height: AppSpacing.xl),
              ],

              _PlanStatsSummary(plan: plan, l10n: l10n, unitSystem: unitSystem),

              const SizedBox(height: AppSpacing.xl),

              SectionLabel(label: l10n.fullPlanScheduleLabel),

              const SizedBox(height: AppSpacing.md),

              ...plan.allWeeks.map(
                (week) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _WeekCard(
                    week: week,
                    currentWeekNumber: plan.currentWeekNumber,
                    l10n: l10n,
                    unitSystem: unitSystem,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Plan note ─────────────────────────────────────────────────────────────────

class _PlanNote extends StatelessWidget {
  const _PlanNote({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: const Color(0x1200E676),
        borderRadius: AppRadius.borderMd,
        border: Border.all(color: const Color(0x3300E676)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0x1200E676),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Center(
              child: Icon(
                Icons.info_outline,
                size: 16,
                color: AppColors.accentPrimary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(l10n.fullPlanNote, style: AppTypography.bodyMedium),
          ),
        ],
      ),
    );
  }
}

// ── Plan stats summary card ───────────────────────────────────────────────────

class _PlanStatsSummary extends StatelessWidget {
  const _PlanStatsSummary({
    required this.plan,
    required this.l10n,
    required this.unitSystem,
  });

  final TrainingPlan plan;
  final AppLocalizations l10n;
  final UnitSystem unitSystem;

  @override
  Widget build(BuildContext context) {
    final totalDistance = plan.sessions.fold<double>(
      0.0,
      (sum, s) => sum + (s.distanceKm ?? 0.0),
    );
    final totalRuns = plan.sessions.where((s) => s.countsAsRun).length;

    return Container(
      height: 68,
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: AppColors.backgroundCard),
      ),
      child: Row(
        children: [
          StatColumn(
            label: l10n.fullPlanWeeksLabel,
            value: plan.totalWeeks.toString(),
          ),
          StatColumn(
            label: l10n.fullPlanDistanceLabel,
            value: UnitFormatter.formatDistanceLabel(
              totalDistance,
              unitSystem,
              l10n,
            ),
            hasDivider: true,
          ),
          StatColumn(
            label: l10n.fullPlanRunsLabel,
            value: totalRuns.toString(),
            hasDivider: true,
          ),
        ],
      ),
    );
  }
}

// ── Week accordion card ───────────────────────────────────────────────────────

class _WeekCard extends StatefulWidget {
  const _WeekCard({
    required this.week,
    required this.currentWeekNumber,
    required this.l10n,
    required this.unitSystem,
  });

  final PlanWeek week;
  final int currentWeekNumber;
  final AppLocalizations l10n;
  final UnitSystem unitSystem;

  @override
  State<_WeekCard> createState() => _WeekCardState();
}

class _WeekCardState extends State<_WeekCard> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.week.weekNumber == widget.currentWeekNumber;
  }

  String _sessionTitle(SessionType type) {
    final l10n = widget.l10n;
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

  bool _isTodayDate(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  String _dayLabel(DateTime date) {
    if (_isTodayDate(date)) return widget.l10n.weeklyPlanDayToday;
    switch (date.weekday) {
      case 1:
        return widget.l10n.weeklyPlanDayMon;
      case 2:
        return widget.l10n.weeklyPlanDayTue;
      case 3:
        return widget.l10n.weeklyPlanDayWed;
      case 4:
        return widget.l10n.weeklyPlanDayThu;
      case 5:
        return widget.l10n.weeklyPlanDayFri;
      case 6:
        return widget.l10n.weeklyPlanDaySat;
      default:
        return widget.l10n.weeklyPlanDaySun;
    }
  }

  List<_SessionRowData> _buildRows() {
    final rows = <_SessionRowData>[
      ...widget.week.sessions.map((session) => _SessionRowData.run(session)),
      ...widget.week.supportSessions.map(
        (session) => _SessionRowData.support(session),
      ),
    ];

    rows.sort((a, b) {
      final compareDate = a.date.compareTo(b.date);
      if (compareDate != 0) return compareDate;
      if (a.isSupport != b.isSupport) {
        return a.isSupport ? 1 : -1;
      }
      return 0;
    });

    return rows;
  }

  SessionStatus _supportSessionStatusToSessionStatus(
    SupportSessionStatus status,
  ) {
    return switch (status) {
      SupportSessionStatus.planned => SessionStatus.upcoming,
      SupportSessionStatus.completed => SessionStatus.completed,
      SupportSessionStatus.skipped => SessionStatus.skipped,
    };
  }

  String _supportSessionTitle(_SessionRowData row, AppLocalizations l10n) {
    final type = row.supportSession!.type;
    return switch (type) {
      SupplementalSessionType.strength => l10n.planSupportStrengthLabel,
      SupplementalSessionType.mobility => l10n.planSupportMobilityLabel,
      SupplementalSessionType.drills => l10n.planSupportDrillsLabel,
    };
  }

  String _supportSessionIcon(SupplementalSessionType type) {
    return switch (type) {
      SupplementalSessionType.strength => 'assets/icons/target.svg',
      SupplementalSessionType.mobility => 'assets/icons/heart_rate.svg',
      SupplementalSessionType.drills => 'assets/icons/activity.svg',
    };
  }

  String? _supportSessionSubtitle(SupportSession session, AppLocalizations l10n) {
    final details = localizedSupportSessionSubtitles(session, l10n);
    if (details.isEmpty) return null;
    return details.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final week = widget.week;
    final isCurrent = week.weekNumber == widget.currentWeekNumber;
    final isPast = week.weekNumber < widget.currentWeekNumber;
    final rows = _buildRows();

    final progress = WeekProgress.fromSessions(week.sessions);
    final runCount = week.sessions.where((s) => s.countsAsRun).length;

    final Color badgeColor;
    final String badgeLabel;
    if (isCurrent) {
      badgeColor = AppColors.accentPrimary;
      badgeLabel = l10n.fullPlanCurrentBadge;
    } else if (isPast) {
      badgeColor = AppColors.success;
      badgeLabel = l10n.fullPlanCompletedBadge;
    } else {
      badgeColor = AppColors.textDisabled;
      badgeLabel = l10n.fullPlanUpcomingBadge;
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: AppRadius.borderLg,
        border: Border.all(
          color: isCurrent
              ? AppColors.accentPrimary.withValues(alpha: 0.3)
              : AppColors.backgroundCard,
        ),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.base,
                vertical: AppSpacing.base,
              ),
              child: Row(
                children: [
                  Text(
                    l10n.fullPlanWeekLabel(week.weekNumber),
                    style: AppTypography.titleMedium.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isCurrent
                          ? AppColors.accentPrimary
                          : AppColors.textPrimary,
                    ),
                  ),

                  const SizedBox(width: AppSpacing.sm),

                  _StatusBadge(label: badgeLabel, color: badgeColor),

                  const Spacer(),

                  if (!_expanded) ...[
                    Text(
                      UnitFormatter.formatDistanceLabel(
                        progress.totalVolumeKm,
                        widget.unitSystem,
                        l10n,
                      ),
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textDisabled,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      l10n.fullPlanRunsValue(runCount),
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textDisabled,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],

                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: SvgPicture.asset(
                      'assets/icons/chevron_right.svg',
                      width: 16,
                      height: 16,
                      colorFilter: ColorFilter.mode(
                        _expanded
                            ? AppColors.textPrimary
                            : AppColors.textDisabled,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_expanded) ...[
            Divider(height: 1, color: AppColors.backgroundCard),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.base,
                AppSpacing.sm,
                AppSpacing.base,
                AppSpacing.sm,
              ),
              child: Column(
                children: rows
                    .map(
                      (row) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: SessionRow(
                          dayLabel: _dayLabel(row.date),
                          dateNumber: row.date.day.toString(),
                          sessionDate: row.date,
                          title: row.isSupport
                              ? _supportSessionTitle(row, l10n)
                              : _sessionTitle(row.session!.type),
                          subtitle: row.isSupport
                              ? _supportSessionSubtitle(
                                  row.supportSession!,
                                  l10n,
                                )
                              : row.session!.type.isRest
                              ? l10n.weeklyPlanRestSubtitle
                              : null,
                          distance: row.isSupport
                              ? null
                              : row.session!.distanceKm != null
                              ? UnitFormatter.formatDistanceLabel(
                                  row.session!.distanceKm!,
                                  widget.unitSystem,
                                  l10n,
                                )
                              : null,
                          duration: row.isSupport
                              ? row.supportSession!.durationMinutes != null
                                    ? UnitFormatter.formatDuration(
                                        row.supportSession!.durationMinutes!,
                                        l10n,
                                      )
                                    : null
                              : row.session!.durationMinutes != null
                              ? UnitFormatter.formatDuration(
                                  row.session!.durationMinutes!,
                                  l10n,
                                )
                              : null,
                          status: row.isSupport
                              ? _supportSessionStatusToSessionStatus(
                                  row.supportSession!.status,
                                )
                              : row.session!.status,
                          isRest: row.isSupport
                              ? false
                              : row.session!.type.isRest,
                          trailingIcon: row.isSupport
                              ? _supportSessionIcon(row.supportSession!.type)
                              : row.session!.type.iconAsset,
                          nowLabel: l10n.weeklyPlanNowBadge,
                          onTap: row.isSupport
                              ? null
                              : row.session!.type.isRest
                              ? null
                              : () => context.push(
                                  RouteNames.sessionDetail,
                                  extra: SessionDetailArgs(
                                    session: row.session!,
                                  ),
                                ),
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Session row shape (run + support) ───────────────────────────────────────

class _SessionRowData {
  _SessionRowData.run(TrainingSession this.session)
    : supportSession = null,
      date = session.date;

  _SessionRowData.support(SupportSession this.supportSession)
    : session = null,
      date = supportSession.date;

  final TrainingSession? session;
  final SupportSession? supportSession;
  final DateTime date;

  bool get isSupport => supportSession != null;
}

// ── Status badge ──────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 18,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Center(
        child: Text(
          label,
          style: AppTypography.caption.copyWith(
            color: color,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
