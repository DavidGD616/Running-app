import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_progress_bar.dart';
import '../onboarding_provider.dart';

class SummaryScreen extends ConsumerWidget {
  const SummaryScreen({super.key});

  // ── Helper: format DateTime as "Month DD, YYYY" ──────────────────────────
  String _formatDate(DateTime d) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  // ── Build display values from provider data ───────────────────────────────

  String _goalValue(Map<String, dynamic> a) =>
      (a['race'] as String?) ?? '—';

  String _goalDetail(Map<String, dynamic> a) {
    final date = a['raceDate'] as DateTime?;
    final priority = (a['priority'] as String?) ?? '—';
    if (date != null) return '${_formatDate(date)} · $priority';
    return priority;
  }

  String _fitnessValue(Map<String, dynamic> a) =>
      (a['experience'] as String?) ?? '—';

  String _fitnessDetail(Map<String, dynamic> a) {
    final experience = a['experience'] as String?;
    if (experience == 'Brand new') {
      final can = a['canRun10Min'] as bool?;
      return can == null ? '—' : 'Can run 10 min: ${can ? 'Yes' : 'No'}';
    }
    final days = (a['runningDays'] as String?) ?? '—';
    final volume = (a['weeklyVolume'] as String?) ?? '—';
    return '$days days/wk · $volume weekly';
  }

  String _scheduleValue(Map<String, dynamic> a) {
    final days = a['trainingDays'] as String?;
    return days != null ? '$days days per week' : '—';
  }

  String _scheduleDetail(Map<String, dynamic> a) {
    final longRun = (a['longRunDay'] as String?) ?? '—';
    final time = (a['preferredTimeOfDay'] as String?) ?? '—';
    final weekday = (a['weekdayTime'] as String?) ?? '—';
    return 'Long run $longRun · $time · $weekday weekdays';
  }

  String _healthValue(Map<String, dynamic> a) {
    final pain = a['painLevel'] as String?;
    if (pain == null) return '—';
    return pain == 'No' ? 'No current pain' : 'Pain: $pain';
  }

  String _healthDetail(Map<String, dynamic> a) {
    final pref = (a['planPreference'] as String?) ?? '—';
    return '$pref plan preference';
  }

  String _trainingValue(Map<String, dynamic> a) {
    final mode = a['guidanceMode'] as String?;
    return mode != null ? '$mode-based guidance' : '—';
  }

  String _trainingDetail(Map<String, dynamic> a) {
    final speed = (a['speedWorkouts'] as String?) ?? '—';
    final strength = (a['strengthTraining'] as String?) ?? '—';
    final surface = (a['runSurface'] as String?) ?? '—';
    final terrain = (a['terrain'] as String?) ?? '—';
    return 'Speed: $speed · Strength: $strength · $surface · $terrain';
  }

  String _deviceValue(Map<String, dynamic> a) {
    final hasWatch = a['hasWatch'] as String?;
    if (hasWatch == 'Yes') {
      final device = (a['device'] as String?) ?? 'Watch';
      return '$device connected';
    }
    if (hasWatch == 'No') return 'No watch';
    return '—';
  }

  String _deviceDetail(Map<String, dynamic> a) {
    final hasWatch = a['hasWatch'] as String?;
    if (hasWatch == 'Yes') {
      final usage = (a['dataUsage'] as String?) ?? '—';
      final hr = (a['hrZones'] as String?) ?? '—';
      final auto = (a['autoAdjust'] as String?) ?? '—';
      return '$usage · HR zones: $hr · Auto-adjust: $auto';
    }
    return (a['noWatchGuidance'] as String?) ?? '—';
  }

  String _recoveryValue(Map<String, dynamic> a) {
    final sleep = a['sleep'] as String?;
    return sleep != null ? '$sleep sleep' : '—';
  }

  String _recoveryDetail(Map<String, dynamic> a) {
    final work = (a['workLevel'] as String?) ?? '—';
    final stress = (a['stressLevel'] as String?) ?? '—';
    final feel = (a['dayFeeling'] as String?) ?? '—';
    return '$work · $stress stress · $feel';
  }

  String _motivationValue(Map<String, dynamic> a) {
    final list = a['motivations'] as List?;
    if (list == null || list.isEmpty) return '—';
    return list.join(', ');
  }

  String _motivationDetail(Map<String, dynamic> a) {
    final tone = (a['coachingTone'] as String?) ?? '—';
    final conf = (a['confidence'] as int?) ?? 5;
    return '$tone tone · Confidence $conf/10';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final answers = ref.watch(onboardingProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top nav ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm, AppSpacing.xs, AppSpacing.screen, 0,
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
                        '9 / 9',
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
                    child: AppProgressBar(current: 9, total: 9),
                  ),
                ],
              ),
            ),

            // ── Scrollable body ──────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screen, AppSpacing.lg,
                  AppSpacing.screen, AppSpacing.xl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Your Plan Summary',
                        style: AppTypography.headlineMedium),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Review your selections before we build your plan.',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // ── Summary cards ─────────────────────────────────────────
                    _SummaryCard(
                      icon: 'assets/icons/target.svg',
                      category: 'Goal Race',
                      value: _goalValue(answers),
                      detail: _goalDetail(answers),
                      onEdit: () => context.go(RouteNames.goal),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _SummaryCard(
                      icon: 'assets/icons/trending_up.svg',
                      category: 'Current Level',
                      value: _fitnessValue(answers),
                      detail: _fitnessDetail(answers),
                      onEdit: () => context.go(RouteNames.fitness),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _SummaryCard(
                      icon: 'assets/icons/calendar.svg',
                      category: 'Schedule',
                      value: _scheduleValue(answers),
                      detail: _scheduleDetail(answers),
                      onEdit: () => context.go(RouteNames.schedule),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _SummaryCard(
                      icon: 'assets/icons/heart.svg',
                      category: 'Health',
                      value: _healthValue(answers),
                      detail: _healthDetail(answers),
                      onEdit: () => context.go(RouteNames.health),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _SummaryCard(
                      icon: 'assets/icons/training.svg',
                      category: 'Training',
                      value: _trainingValue(answers),
                      detail: _trainingDetail(answers),
                      onEdit: () => context.go(RouteNames.training),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _SummaryCard(
                      icon: 'assets/icons/watch.svg',
                      category: 'Device',
                      value: _deviceValue(answers),
                      detail: _deviceDetail(answers),
                      onEdit: () => context.go(RouteNames.device),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _SummaryCard(
                      icon: 'assets/icons/moon.svg',
                      category: 'Recovery',
                      value: _recoveryValue(answers),
                      detail: _recoveryDetail(answers),
                      onEdit: () => context.go(RouteNames.recovery),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _SummaryCard(
                      icon: 'assets/icons/motivation.svg',
                      category: 'Motivation',
                      value: _motivationValue(answers),
                      detail: _motivationDetail(answers),
                      onEdit: () => context.go(RouteNames.motivation),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // ── Ready message ─────────────────────────────────────────
                    Row(
                      children: [
                        SvgPicture.asset(
                          'assets/icons/circle_check.svg',
                          width: 18,
                          height: 18,
                          colorFilter: const ColorFilter.mode(
                            AppColors.accentPrimary,
                            BlendMode.srcIn,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            'Everything looks good. Ready to build your plan!',
                            style: AppTypography.bodyMedium.copyWith(
                              color: const Color(0xFF4CAF50),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── Buttons ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen, AppSpacing.sm,
                AppSpacing.screen, AppSpacing.xl,
              ),
              child: Column(
                children: [
                  AppButton(
                    label: 'Build My Plan',
                    onPressed: () => context.go(RouteNames.planGeneration),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    label: 'Edit Answers',
                    variant: AppButtonVariant.secondary,
                    onPressed: () => context.go(RouteNames.goal),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Summary card ─────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.category,
    required this.value,
    required this.detail,
    required this.onEdit,
  });

  final String icon;
  final String category;
  final String value;
  final String detail;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.base, AppSpacing.base, 0, AppSpacing.base,
      ),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon container
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.accentMuted,
              borderRadius: AppRadius.borderMd,
            ),
            child: Center(
              child: SvgPicture.asset(
                icon,
                width: 20,
                height: 20,
                colorFilter: const ColorFilter.mode(
                  AppColors.accentPrimary,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.base),

          // Text content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: AppTypography.titleMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Edit button
          GestureDetector(
            onTap: onEdit,
            child: SizedBox(
              width: 48,
              height: 48,
              child: Center(
                child: SvgPicture.asset(
                  'assets/icons/edit.svg',
                  width: 16,
                  height: 16,
                  colorFilter: const ColorFilter.mode(
                    AppColors.textSecondary,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
