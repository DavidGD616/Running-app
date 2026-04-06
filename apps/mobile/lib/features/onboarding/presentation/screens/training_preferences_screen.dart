import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_header_bar.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_progress_bar.dart';
import '../onboarding_provider.dart';
import '../onboarding_values.dart';
import '../../../../l10n/app_localizations.dart';

enum TrainingPreferencesFlowMode { onboarding, editGoal, newGoal }

class TrainingPreferencesScreen extends ConsumerStatefulWidget {
  const TrainingPreferencesScreen({
    super.key,
    this.mode = TrainingPreferencesFlowMode.onboarding,
  });

  final TrainingPreferencesFlowMode mode;

  @override
  ConsumerState<TrainingPreferencesScreen> createState() =>
      _TrainingPreferencesScreenState();
}

class _TrainingPreferencesScreenState
    extends ConsumerState<TrainingPreferencesScreen> {
  String? _guidanceMode;
  String? _speedWorkouts;
  String? _strengthTraining;
  String? _runSurface;
  String? _terrain;
  String? _walkRunIntervals;

  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    final answers = ref.read(onboardingProvider);
    _guidanceMode = answers['guidanceMode'] as String?;
    _speedWorkouts = answers['speedWorkouts'] as String?;
    _strengthTraining = answers['strengthTraining'] as String?;
    _runSurface = answers['runSurface'] as String?;
    _terrain = answers['terrain'] as String?;
    _walkRunIntervals = answers['walkRunIntervals'] as String?;
  }

  bool get _isComplete =>
      _guidanceMode != null &&
      _speedWorkouts != null &&
      _strengthTraining != null &&
      _runSurface != null &&
      _terrain != null &&
      _walkRunIntervals != null;

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isSettingsFlow =
        widget.mode != TrainingPreferencesFlowMode.onboarding;
    final nextRoute = switch (widget.mode) {
      TrainingPreferencesFlowMode.onboarding => RouteNames.device,
      TrainingPreferencesFlowMode.editGoal =>
        RouteNames.settingsUpdatePlanEditGoalSummary,
      TrainingPreferencesFlowMode.newGoal =>
        RouteNames.settingsUpdatePlanNewGoalSummary,
    };

    final surfaceOptions = [
      OnboardingValues.surfaceRoad,
      OnboardingValues.surfaceTreadmill,
      OnboardingValues.surfaceTrack,
      OnboardingValues.surfaceTrail,
      OnboardingValues.surfaceMixed,
    ];
    final guidanceOptions = [
      (
        key: OnboardingValues.guidanceEffort,
        label: l10n.guidanceEffort,
        subtitle: l10n.guidanceEffortSub,
        icon: 'assets/icons/effort.svg',
      ),
      (
        key: OnboardingValues.guidancePace,
        label: l10n.guidancePace,
        subtitle: l10n.guidancePaceSub,
        icon: 'assets/icons/pace.svg',
      ),
      (
        key: OnboardingValues.guidanceHeartRate,
        label: l10n.guidanceHeartRate,
        subtitle: l10n.guidanceHeartRateSub,
        icon: 'assets/icons/heart_rate.svg',
      ),
      (
        key: OnboardingValues.guidanceDecideForMe,
        label: l10n.guidanceDecideForMe,
        subtitle: l10n.guidanceDecideForMeSub,
        icon: 'assets/icons/decide_for_me.svg',
      ),
    ];
    final speedWorkoutOptions = [
      (key: OnboardingValues.yes, label: l10n.yes),
      (key: OnboardingValues.no, label: l10n.no),
      (key: OnboardingValues.onlyIfNeeded, label: l10n.onlyIfNeeded),
    ];
    final strengthOptions = [
      (key: OnboardingValues.strengthNone, label: l10n.no),
      (key: OnboardingValues.strength1Day, label: l10n.strength1DayWeek),
      (key: OnboardingValues.strength2Days, label: l10n.strength2DaysWeek),
      (key: OnboardingValues.strength3Days, label: l10n.strength3DaysWeek),
    ];
    final terrainOptions = [
      (key: OnboardingValues.terrainFlat, label: l10n.terrainFlat),
      (key: OnboardingValues.terrainSomeHills, label: l10n.terrainSomeHills),
      (key: OnboardingValues.terrainHilly, label: l10n.terrainHilly),
      (key: OnboardingValues.terrainMixed, label: l10n.terrainMixed),
    ];

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: isSettingsFlow
          ? AppDetailHeaderBar(title: l10n.trainingPrefsTitle)
          : null,
      body: SafeArea(
        top: !isSettingsFlow,
        child: Column(
          children: [
            if (!isSettingsFlow)
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
                          l10n.onboardingStep(5, 9),
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
                      child: AppProgressBar(current: 5, total: 9),
                    ),
                  ],
                ),
              ),

            // ── Scrollable body ──────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screen,
                  AppSpacing.lg,
                  AppSpacing.screen,
                  AppSpacing.xl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isSettingsFlow) ...[
                      Text(
                        l10n.trainingPrefsTitle,
                        style: AppTypography.headlineMedium,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        l10n.trainingPrefsSubtitle,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                    ],

                    // ── 1. Preferred guidance mode ────────────────────────────
                    Text(
                      l10n.guidanceModeLabel,
                      style: AppTypography.labelLarge,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ...guidanceOptions.asMap().entries.map((entry) {
                      final option = entry.value;
                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: entry.key == guidanceOptions.length - 1
                              ? 0
                              : AppSpacing.sm,
                        ),
                        child: _IconCard(
                          icon: option.icon,
                          label: option.label,
                          subtitle: option.subtitle,
                          isSelected: _guidanceMode == option.key,
                          onTap: () {
                            setState(() {
                              _guidanceMode = option.key;
                              _speedWorkouts = null;
                              _strengthTraining = null;
                              _runSurface = null;
                              _terrain = null;
                              _walkRunIntervals = null;
                            });
                            _scrollToBottom();
                          },
                        ),
                      );
                    }),

                    // ── 2. Speed workouts included? ───────────────────────────
                    if (_guidanceMode != null) ...[
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        l10n.speedWorkoutsLabel,
                        style: AppTypography.labelLarge,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _SegmentedControl(
                        options: speedWorkoutOptions,
                        selected: _speedWorkouts,
                        itemHeight: 64,
                        onSelect: (val) {
                          setState(() {
                            _speedWorkouts = val;
                            _strengthTraining = null;
                            _runSurface = null;
                            _terrain = null;
                            _walkRunIntervals = null;
                          });
                          _scrollToBottom();
                        },
                      ),
                    ],

                    // ── 3. Strength training? ─────────────────────────────────
                    if (_speedWorkouts != null) ...[
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        l10n.strengthTrainingLabel,
                        style: AppTypography.labelLarge,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _SegmentedControl(
                        options: strengthOptions,
                        selected: _strengthTraining,
                        itemHeight: 64,
                        onSelect: (val) {
                          setState(() {
                            _strengthTraining = val;
                            _runSurface = null;
                            _terrain = null;
                            _walkRunIntervals = null;
                          });
                          _scrollToBottom();
                        },
                      ),
                    ],

                    // ── 4. Where do you run most? ─────────────────────────────
                    if (_strengthTraining != null) ...[
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        l10n.runSurfaceLabel,
                        style: AppTypography.labelLarge,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: surfaceOptions
                            .map(
                              (s) => _Chip(
                                label: OnboardingValues.localizeSurface(
                                  s,
                                  l10n,
                                ),
                                isSelected: _runSurface == s,
                                onTap: () {
                                  setState(() {
                                    _runSurface = s;
                                    _terrain = null;
                                    _walkRunIntervals = null;
                                  });
                                  _scrollToBottom();
                                },
                              ),
                            )
                            .toList(),
                      ),
                    ],

                    // ── 5. Terrain ────────────────────────────────────────────
                    if (_runSurface != null) ...[
                      const SizedBox(height: AppSpacing.xl),
                      Text(l10n.terrainLabel, style: AppTypography.labelLarge),
                      const SizedBox(height: AppSpacing.md),
                      _SegmentedControl(
                        options: terrainOptions,
                        selected: _terrain,
                        itemHeight: 64,
                        onSelect: (val) {
                          setState(() {
                            _terrain = val;
                            _walkRunIntervals = null;
                          });
                          _scrollToBottom();
                        },
                      ),
                    ],

                    // ── 6. Walk/run intervals? ────────────────────────────────
                    if (_terrain != null) ...[
                      const SizedBox(height: AppSpacing.xl),
                      Text(l10n.walkRunLabel, style: AppTypography.labelLarge),
                      const SizedBox(height: AppSpacing.md),
                      _SegmentedControl(
                        options: speedWorkoutOptions,
                        selected: _walkRunIntervals,
                        itemHeight: 64,
                        onSelect: (val) =>
                            setState(() => _walkRunIntervals = val),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // ── Continue button ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen,
                AppSpacing.sm,
                AppSpacing.screen,
                AppSpacing.xl,
              ),
              child: AppButton(
                label: l10n.continueButton,
                onPressed: _isComplete
                    ? () {
                        ref
                            .read(onboardingProvider.notifier)
                            .setTraining(
                              guidanceMode: _guidanceMode!,
                              speedWorkouts: _speedWorkouts!,
                              strengthTraining: _strengthTraining!,
                              runSurface: _runSurface!,
                              terrain: _terrain!,
                              walkRunIntervals: _walkRunIntervals!,
                            );
                        context.push(nextRoute);
                      }
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Icon card ────────────────────────────────────────────────────────────────

class _IconCard extends StatelessWidget {
  const _IconCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  final String icon;
  final String label;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base,
          vertical: AppSpacing.base,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accentMuted : AppColors.backgroundCard,
          borderRadius: AppRadius.borderLg,
          border: Border.all(
            color: isSelected
                ? AppColors.accentPrimary
                : AppColors.borderDefault,
          ),
        ),
        child: Row(
          children: [
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTypography.titleMedium.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
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

// ─── Segmented control ────────────────────────────────────────────────────────

class _SegmentedControl extends StatelessWidget {
  const _SegmentedControl({
    required this.options,
    required this.selected,
    required this.onSelect,
    this.itemHeight = 44,
  });

  final List<OnboardingOption> options;
  final String? selected;
  final void Function(String) onSelect;
  final double itemHeight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: AppRadius.borderLg,
      ),
      child: Row(
        children: options.map((opt) {
          final isSelected = selected == opt.key;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelect(opt.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: itemHeight,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.accentPrimary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    opt.label,
                    textAlign: TextAlign.center,
                    style: AppTypography.labelMedium.copyWith(
                      color: isSelected
                          ? AppColors.backgroundPrimary
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Pill chip ────────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  const _Chip({
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
      child: IntrinsicWidth(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.accentPrimary
                : AppColors.backgroundCard,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: isSelected
                  ? AppColors.accentPrimary
                  : AppColors.borderDefault,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: AppTypography.labelMedium.copyWith(
                color: isSelected
                    ? AppColors.backgroundPrimary
                    : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
