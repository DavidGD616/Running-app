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
import '../../../../core/widgets/app_header_bar.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../session_detail/presentation/screens/session_detail_screen.dart';
import '../../../training_plan/domain/models/session_type.dart';
import '../../../training_plan/domain/models/training_session.dart';
import '../progress_provider.dart';

({String iconAsset, Color iconColor, Color iconBg}) _completedSessionIconData(
  SessionType type,
) {
  return switch (type) {
    SessionType.tempoRun ||
    SessionType.intervals ||
    SessionType.hillRepeats ||
    SessionType.fartlek ||
    SessionType.thresholdRun ||
    SessionType.racePaceRun => (
      iconAsset: 'assets/icons/activity.svg',
      iconColor: AppColors.accentPrimary,
      iconBg: AppColors.accentPrimary.withValues(alpha: 0.1),
    ),
    SessionType.easyRun ||
    SessionType.longRun ||
    SessionType.progressionRun ||
    SessionType.recoveryRun ||
    SessionType.crossTraining => (
      iconAsset: 'assets/icons/route.svg',
      iconColor: AppColors.info,
      iconBg: AppColors.info.withValues(alpha: 0.1),
    ),
    SessionType.restDay => (
      iconAsset: 'assets/icons/coffee.svg',
      iconColor: AppColors.textDisabled,
      iconBg: AppColors.backgroundCard,
    ),
  };
}

String _completedSessionTitle(SessionType type, AppLocalizations l10n) {
  switch (type) {
    case SessionType.restDay:
      return l10n.weeklyPlanRestTitle;
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
      return l10n.progressSessionTempoRun;
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

String _completedSessionDateLabel(
  DateTime date,
  BuildContext context,
  AppLocalizations l10n,
) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  final today = DateTime.now();
  final normalizedToday = DateTime(today.year, today.month, today.day);
  final normalizedDate = DateTime(date.year, date.month, date.day);
  final dayDifference = normalizedToday.difference(normalizedDate).inDays;

  if (dayDifference == 1) {
    return l10n.progressYesterday;
  }

  if (dayDifference > 1 && dayDifference < 7) {
    return DateFormat('EEEE', locale).format(normalizedDate);
  }

  return DateFormat('MMM d', locale).format(normalizedDate);
}

class CompletedSessionsScreen extends ConsumerWidget {
  const CompletedSessionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final sessions = ref.watch(completedSessionsProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppDetailHeaderBar(
        title: l10n.completedSessionsTitle,
        onBack: () => Navigator.of(context).maybePop(),
      ),
      body: SafeArea(
        top: false,
        child: sessions.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Text(
                    l10n.completedSessionsEmpty,
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textDisabled,
                    ),
                  ),
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screen,
                  AppSpacing.lg,
                  AppSpacing.screen,
                  AppSpacing.xl,
                ),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundSecondary,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.borderDefault),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.completedSessionsSummary(
                          sessions.length.toString(),
                        ),
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textDisabled,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      ...sessions.asMap().entries.map((entry) {
                        final isLast = entry.key == sessions.length - 1;
                        final session = entry.value;

                        return Column(
                          children: [
                            _CompletedSessionRow(
                              session: session,
                              title: _completedSessionTitle(session.type, l10n),
                              meta:
                                  '${_completedSessionDateLabel(session.date, context, l10n)} • '
                                  '${UnitFormatter.formatDistanceKm(session.distanceKm ?? 0)}',
                              duration: UnitFormatter.formatDuration(
                                session.durationMinutes ?? 0,
                              ),
                              onTap: () => context.push(
                                RouteNames.sessionDetail,
                                extra: SessionDetailArgs(
                                  session: session,
                                  showStartWorkout: false,
                                ),
                              ),
                            ),
                            if (!isLast)
                              Divider(
                                height: 1,
                                color: AppColors.borderDefault.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

class _CompletedSessionRow extends StatelessWidget {
  const _CompletedSessionRow({
    required this.session,
    required this.title,
    required this.meta,
    required this.duration,
    required this.onTap,
  });

  final TrainingSession session;
  final String title;
  final String meta;
  final String duration;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final iconData = _completedSessionIconData(session.type);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.base),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconData.iconBg,
                borderRadius: AppRadius.borderMd,
              ),
              child: Center(
                child: SvgPicture.asset(
                  iconData.iconAsset,
                  width: 18,
                  height: 18,
                  colorFilter: ColorFilter.mode(
                    iconData.iconColor,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.titleMedium.copyWith(fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    meta,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textDisabled,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              duration,
              style: AppTypography.titleMedium.copyWith(
                color: AppColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
