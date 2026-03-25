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
import '../../../../l10n/app_localizations.dart';

class TrainingPreferencesScreen extends ConsumerStatefulWidget {
  const TrainingPreferencesScreen({super.key});

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

    final surfaceOptions = [
      l10n.surfaceRoad, l10n.surfaceTreadmill, l10n.surfaceTrack,
      l10n.surfaceTrail, l10n.surfaceMixed,
    ];

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
                        '5 / 9',
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
                  AppSpacing.screen, AppSpacing.lg,
                  AppSpacing.screen, AppSpacing.xl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.trainingPrefsTitle,
                        style: AppTypography.headlineMedium),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      l10n.trainingPrefsSubtitle,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // ── 1. Preferred guidance mode ────────────────────────────
                    Text(l10n.guidanceModeLabel,
                        style: AppTypography.labelLarge),
                    const SizedBox(height: AppSpacing.md),
                    _IconCard(
                      icon: 'assets/icons/effort.svg',
                      label: l10n.guidanceEffort,
                      subtitle: l10n.guidanceEffortSub,
                      isSelected: _guidanceMode == 'Effort',
                      onTap: () {
                        setState(() {
                          _guidanceMode = 'Effort';
                          _speedWorkouts = null;
                          _strengthTraining = null;
                          _runSurface = null;
                          _terrain = null;
                          _walkRunIntervals = null;
                        });
                        _scrollToBottom();
                      },
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _IconCard(
                      icon: 'assets/icons/pace.svg',
                      label: l10n.guidancePace,
                      subtitle: l10n.guidancePaceSub,
                      isSelected: _guidanceMode == 'Pace',
                      onTap: () {
                        setState(() {
                          _guidanceMode = 'Pace';
                          _speedWorkouts = null;
                          _strengthTraining = null;
                          _runSurface = null;
                          _terrain = null;
                          _walkRunIntervals = null;
                        });
                        _scrollToBottom();
                      },
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _IconCard(
                      icon: 'assets/icons/heart_rate.svg',
                      label: l10n.guidanceHeartRate,
                      subtitle: l10n.guidanceHeartRateSub,
                      isSelected: _guidanceMode == 'Heart rate',
                      onTap: () {
                        setState(() {
                          _guidanceMode = 'Heart rate';
                          _speedWorkouts = null;
                          _strengthTraining = null;
                          _runSurface = null;
                          _terrain = null;
                          _walkRunIntervals = null;
                        });
                        _scrollToBottom();
                      },
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _IconCard(
                      icon: 'assets/icons/decide_for_me.svg',
                      label: l10n.guidanceDecideForMe,
                      subtitle: l10n.guidanceDecideForMeSub,
                      isSelected: _guidanceMode == 'Decide for me',
                      onTap: () {
                        setState(() {
                          _guidanceMode = 'Decide for me';
                          _speedWorkouts = null;
                          _strengthTraining = null;
                          _runSurface = null;
                          _terrain = null;
                          _walkRunIntervals = null;
                        });
                        _scrollToBottom();
                      },
                    ),

                    // ── 2. Speed workouts included? ───────────────────────────
                    if (_guidanceMode != null) ...[
                      const SizedBox(height: AppSpacing.xl),
                      Text(l10n.speedWorkoutsLabel,
                          style: AppTypography.labelLarge),
                      const SizedBox(height: AppSpacing.md),
                      _SegmentedControl(
                        options: [l10n.yes, l10n.no, l10n.onlyIfNeeded],
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
                      Text(l10n.strengthTrainingLabel,
                          style: AppTypography.labelLarge),
                      const SizedBox(height: AppSpacing.md),
                      _SegmentedControl(
                        options: [
                          l10n.no,
                          l10n.strength1DayWeek,
                          l10n.strength2DaysWeek,
                          l10n.strength3DaysWeek,
                        ],
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
                      Text(l10n.runSurfaceLabel,
                          style: AppTypography.labelLarge),
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: surfaceOptions
                            .map((s) => _Chip(
                                  label: s,
                                  isSelected: _runSurface == s,
                                  onTap: () {
                                    setState(() {
                                      _runSurface = s;
                                      _terrain = null;
                                      _walkRunIntervals = null;
                                    });
                                    _scrollToBottom();
                                  },
                                ))
                            .toList(),
                      ),
                    ],

                    // ── 5. Terrain ────────────────────────────────────────────
                    if (_runSurface != null) ...[
                      const SizedBox(height: AppSpacing.xl),
                      Text(l10n.terrainLabel, style: AppTypography.labelLarge),
                      const SizedBox(height: AppSpacing.md),
                      _SegmentedControl(
                        options: [
                          l10n.terrainFlat,
                          l10n.terrainSomeHills,
                          l10n.terrainHilly,
                          l10n.terrainMixed,
                        ],
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
                      Text(l10n.walkRunLabel,
                          style: AppTypography.labelLarge),
                      const SizedBox(height: AppSpacing.md),
                      _SegmentedControl(
                        options: [l10n.yes, l10n.no, l10n.onlyIfNeeded],
                        selected: _walkRunIntervals,
                        itemHeight: 64,
                        onSelect: (val) => setState(() => _walkRunIntervals = val),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // ── Continue button ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen, AppSpacing.sm,
                AppSpacing.screen, AppSpacing.xl,
              ),
              child: AppButton(
                label: l10n.continueButton,
                onPressed: _isComplete
                    ? () {
                        ref.read(onboardingProvider.notifier).setTraining(
                              guidanceMode: _guidanceMode!,
                              speedWorkouts: _speedWorkouts!,
                              strengthTraining: _strengthTraining!,
                              runSurface: _runSurface!,
                              terrain: _terrain!,
                              walkRunIntervals: _walkRunIntervals!,
                            );
                        context.push(RouteNames.device);
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
            color: isSelected ? AppColors.accentPrimary : AppColors.borderDefault,
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

  final List<String> options;
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
          final isSelected = selected == opt;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelect(opt),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: itemHeight,
                decoration: BoxDecoration(
                  color:
                      isSelected ? AppColors.accentPrimary : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    opt,
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
