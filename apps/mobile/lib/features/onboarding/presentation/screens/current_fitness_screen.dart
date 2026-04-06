import 'package:flutter/cupertino.dart';
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
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_progress_bar.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../onboarding_provider.dart';
import '../onboarding_values.dart';
import '../../../user_preferences/domain/user_preferences.dart';
import '../../../user_preferences/presentation/user_preferences_provider.dart';
import '../../../../l10n/app_localizations.dart';

class CurrentFitnessScreen extends ConsumerStatefulWidget {
  const CurrentFitnessScreen({super.key, this.isEditingPlanInfo = false});

  final bool isEditingPlanInfo;

  @override
  ConsumerState<CurrentFitnessScreen> createState() =>
      _CurrentFitnessScreenState();
}

class _CurrentFitnessScreenState extends ConsumerState<CurrentFitnessScreen> {
  static const _benchmarkSkipKey = OnboardingValues.benchmarkSkip;

  String? _experience;

  // Brand new only
  bool? _canRun10Min;

  // Non-brand-new only (progressive)
  String? _runningDays;
  String? _weeklyVolume;
  String? _longestRun;
  String? _canCompleteGoalDist;
  String? _raceDistanceBefore;
  String? _benchmark;
  Duration? _benchmarkTime;

  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    final answers = ref.read(onboardingProvider);
    _experience = answers['experience'] as String?;
    _canRun10Min = answers['canRun10Min'] as bool?;
    _runningDays = answers['runningDays'] as String?;
    _weeklyVolume = answers['weeklyVolume'] as String?;
    _longestRun = answers['longestRun'] as String?;
    _canCompleteGoalDist = answers['canCompleteGoalDist'] as String?;
    _raceDistanceBefore = answers['raceDistanceBefore'] as String?;
    _benchmark = answers['benchmark'] as String?;
    _benchmarkTime = answers['benchmarkTime'] as Duration?;
  }

  bool get _isBrandNew => _experience == OnboardingValues.experienceBrandNew;

  bool get _isComplete {
    if (_experience == null) return false;
    if (_isBrandNew) {
      return _canRun10Min != null &&
          (_benchmark == null ||
              _benchmark == _benchmarkSkipKey ||
              _benchmarkTime != null);
    }
    return _runningDays != null &&
        _weeklyVolume != null &&
        _longestRun != null &&
        _canCompleteGoalDist != null &&
        _raceDistanceBefore != null &&
        (_benchmark == null ||
            _benchmark == _benchmarkSkipKey ||
            _benchmarkTime != null);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
      );
    });
  }

  void _selectExperience(String value) {
    setState(() {
      _experience = value;
      _canRun10Min = null;
      _runningDays = null;
      _weeklyVolume = null;
      _longestRun = null;
      _canCompleteGoalDist = null;
      _raceDistanceBefore = null;
      _benchmark = null;
      _benchmarkTime = null;
    });
    _scrollToBottom();
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  Future<void> _showTimePicker() async {
    await showAppBottomSheet(
      context: context,
      child: _TimePickerSheet(
        initial: _benchmarkTime ?? Duration.zero,
        onConfirm: (d) {
          setState(() => _benchmarkTime = d);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final unitSystem =
        ref.watch(userPreferencesProvider).value?.unitSystem ?? UnitSystem.km;

    final goalDistOptions = [
      (key: OnboardingValues.yes, label: l10n.yes),
      (key: OnboardingValues.no, label: l10n.no),
      (key: OnboardingValues.notSure, label: l10n.notSure),
    ];

    final benchmarkOptions = unitSystem == UnitSystem.km
        ? [
            (key: OnboardingValues.benchmark1KmRun, label: l10n.benchmarkKmRun),
            (
              key: OnboardingValues.benchmark1KmWalk,
              label: l10n.benchmarkKmWalk,
            ),
            (key: OnboardingValues.benchmark5k, label: l10n.benchmark5K),
            (key: OnboardingValues.benchmark10k, label: l10n.benchmark10K),
            (
              key: OnboardingValues.benchmarkHalfMarathon,
              label: l10n.benchmarkHalfMarathon,
            ),
            (key: _benchmarkSkipKey, label: l10n.benchmarkSkipForNow),
          ]
        : [
            (key: OnboardingValues.benchmark1MiRun, label: l10n.benchmarkMiRun),
            (
              key: OnboardingValues.benchmark1MiWalk,
              label: l10n.benchmarkMiWalk,
            ),
            (key: OnboardingValues.benchmark5k, label: l10n.benchmark5K),
            (key: OnboardingValues.benchmark10k, label: l10n.benchmark10K),
            (
              key: OnboardingValues.benchmarkHalfMarathon,
              label: l10n.benchmarkHalfMarathon,
            ),
            (key: _benchmarkSkipKey, label: l10n.benchmarkSkipForNow),
          ];
    final benchmarkLabelFor = Map<String, String>.fromEntries(
      benchmarkOptions.map((t) => MapEntry(t.key, t.label)),
    );

    final experienceOptions = [
      (
        key: OnboardingValues.experienceBrandNew,
        label: l10n.experienceBrandNew,
        subtitle: l10n.experienceBrandNewSub,
      ),
      (
        key: OnboardingValues.experienceBeginner,
        label: l10n.experienceBeginner,
        subtitle: l10n.experienceBeginnerSub,
      ),
      (
        key: OnboardingValues.experienceIntermediate,
        label: l10n.experienceIntermediate,
        subtitle: l10n.experienceIntermediateSub,
      ),
      (
        key: OnboardingValues.experienceExperienced,
        label: l10n.experienceExperienced,
        subtitle: l10n.experienceExperiencedSub,
      ),
    ];

    final weeklyVolumeOptions = OnboardingValues.weeklyVolumeOptions(
      unitSystem,
      l10n,
    );

    final longestRunOptions = OnboardingValues.longestRunOptions(
      unitSystem,
      l10n,
    );

    final runningDayOptions = const [
      '0',
      '1',
      '2',
      '3',
      '4',
      '5+',
    ].map((day) => (key: day, label: day)).toList();
    final raceDistanceOptions = [
      (key: OnboardingValues.raceDistanceNever, label: l10n.raceDistanceNever),
      (key: OnboardingValues.raceDistanceOnce, label: l10n.raceDistanceOnce),
      (key: OnboardingValues.raceDistance2to3, label: l10n.raceDistance2to3),
      (key: OnboardingValues.raceDistance4plus, label: l10n.raceDistance4plus),
    ];

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: widget.isEditingPlanInfo
          ? AppDetailHeaderBar(title: l10n.fitnessTitle)
          : null,
      body: SafeArea(
        top: !widget.isEditingPlanInfo,
        child: Column(
          children: [
            if (!widget.isEditingPlanInfo)
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
                          l10n.onboardingStep(2, 9),
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
                      child: AppProgressBar(current: 2, total: 9),
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
                    if (!widget.isEditingPlanInfo) ...[
                      Text(
                        l10n.fitnessTitle,
                        style: AppTypography.headlineMedium,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        l10n.fitnessSubtitle,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                    ],

                    // ── Running experience ───────────────────────────────────
                    Text(
                      l10n.runningExperienceLabel,
                      style: AppTypography.labelLarge,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ...experienceOptions.asMap().entries.map((entry) {
                      final option = entry.value;
                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: entry.key == experienceOptions.length - 1
                              ? 0
                              : AppSpacing.sm,
                        ),
                        child: _SelectCard(
                          label: option.label,
                          subtitle: option.subtitle,
                          isSelected: _experience == option.key,
                          onTap: () => _selectExperience(option.key),
                        ),
                      );
                    }),

                    // ── Brand new: 10-minute run question ────────────────────
                    if (_isBrandNew) ...[
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        l10n.canRun10MinLabel,
                        style: AppTypography.labelLarge,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: _ToggleButton(
                              label: l10n.yes,
                              isSelected: _canRun10Min == true,
                              onTap: () {
                                setState(() {
                                  _canRun10Min = true;
                                  _benchmark = null;
                                  _benchmarkTime = null;
                                });
                                _scrollToBottom();
                              },
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: _ToggleButton(
                              label: l10n.no,
                              isSelected: _canRun10Min == false,
                              onTap: () {
                                setState(() {
                                  _canRun10Min = false;
                                  _benchmark = null;
                                  _benchmarkTime = null;
                                });
                                _scrollToBottom();
                              },
                            ),
                          ),
                        ],
                      ),
                    ],

                    // ── Brand new: optional benchmark ────────────────────────
                    if (_isBrandNew && _canRun10Min != null) ...[
                      const SizedBox(height: AppSpacing.xl),
                      Row(
                        children: [
                          Text(
                            l10n.optionalBenchmark,
                            style: AppTypography.labelLarge,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              l10n.optionalBadge,
                              style: AppTypography.caption.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: benchmarkOptions
                            .map(
                              (t) => _Chip(
                                label: t.label,
                                isSelected: _benchmark == t.key,
                                onTap: () {
                                  setState(() {
                                    _benchmark = t.key;
                                    _benchmarkTime = null;
                                  });
                                  if (t.key != _benchmarkSkipKey) {
                                    _scrollToBottom();
                                    _showTimePicker();
                                  }
                                },
                              ),
                            )
                            .toList(),
                      ),
                      if (_benchmark != null &&
                          _benchmark != _benchmarkSkipKey) ...[
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          l10n.benchmarkSelectedLabel(
                            benchmarkLabelFor[_benchmark]!,
                          ),
                          style: AppTypography.labelLarge,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        AppPickerField(
                          hint: l10n.tapToSetTime,
                          value: _benchmarkTime != null
                              ? _formatDuration(_benchmarkTime!)
                              : null,
                          onTap: _showTimePicker,
                        ),
                      ],
                    ],

                    // ── Non-brand-new: progressive questions ─────────────────

                    // 1. Running days per week
                    if (_experience != null && !_isBrandNew) ...[
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        l10n.currentRunDaysLabel,
                        style: AppTypography.labelLarge,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _SegmentedControl(
                        options: runningDayOptions,
                        selected: _runningDays,
                        onSelect: (val) {
                          setState(() {
                            _runningDays = val;
                            _weeklyVolume = null;
                            _longestRun = null;
                            _canCompleteGoalDist = null;
                            _raceDistanceBefore = null;
                            _benchmark = null;
                            _benchmarkTime = null;
                          });
                          _scrollToBottom();
                        },
                      ),
                    ],

                    // 2. Average weekly volume
                    if (_runningDays != null && !_isBrandNew) ...[
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        l10n.weeklyVolumeLabel,
                        style: AppTypography.labelLarge,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: weeklyVolumeOptions
                            .map(
                              (vol) => _Chip(
                                label: vol.label,
                                isSelected: _weeklyVolume == vol.key,
                                onTap: () {
                                  setState(() {
                                    _weeklyVolume = vol.key;
                                    _longestRun = null;
                                    _canCompleteGoalDist = null;
                                    _raceDistanceBefore = null;
                                    _benchmark = null;
                                    _benchmarkTime = null;
                                  });
                                  _scrollToBottom();
                                },
                              ),
                            )
                            .toList(),
                      ),
                    ],

                    // 3. Longest recent run
                    if (_weeklyVolume != null && !_isBrandNew) ...[
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        l10n.longestRunLabel,
                        style: AppTypography.labelLarge,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: longestRunOptions
                            .map(
                              (run) => _Chip(
                                label: run.label,
                                isSelected: _longestRun == run.key,
                                onTap: () {
                                  setState(() {
                                    _longestRun = run.key;
                                    _canCompleteGoalDist = null;
                                    _raceDistanceBefore = null;
                                    _benchmark = null;
                                    _benchmarkTime = null;
                                  });
                                  _scrollToBottom();
                                },
                              ),
                            )
                            .toList(),
                      ),
                    ],

                    // 4. Can you complete your goal distance?
                    if (_longestRun != null && !_isBrandNew) ...[
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        l10n.canCompleteGoalLabel,
                        style: AppTypography.labelLarge,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: goalDistOptions.asMap().entries.map((entry) {
                          final isLast = entry.key == 2;
                          final key = entry.value.key;
                          final label = entry.value.label;
                          return Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                right: isLast ? 0 : AppSpacing.md,
                              ),
                              child: _ToggleButton(
                                label: label,
                                isSelected: _canCompleteGoalDist == key,
                                onTap: () {
                                  setState(() {
                                    _canCompleteGoalDist = key;
                                    _raceDistanceBefore = null;
                                    _benchmark = null;
                                    _benchmarkTime = null;
                                  });
                                  _scrollToBottom();
                                },
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],

                    // 5. Have you done this race distance before?
                    if (_canCompleteGoalDist != null && !_isBrandNew) ...[
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        l10n.raceDistanceBeforeLabel,
                        style: AppTypography.labelLarge,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _SegmentedControl(
                        options: raceDistanceOptions,
                        selected: _raceDistanceBefore,
                        onSelect: (val) {
                          setState(() {
                            _raceDistanceBefore = val;
                            _benchmark = null;
                            _benchmarkTime = null;
                          });
                          _scrollToBottom();
                        },
                      ),
                    ],

                    // 6. Optional benchmark
                    if (_raceDistanceBefore != null && !_isBrandNew) ...[
                      const SizedBox(height: AppSpacing.xl),
                      Row(
                        children: [
                          Text(
                            l10n.optionalBenchmark,
                            style: AppTypography.labelLarge,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              l10n.optionalBadge,
                              style: AppTypography.caption.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: benchmarkOptions
                            .map(
                              (t) => _Chip(
                                label: t.label,
                                isSelected: _benchmark == t.key,
                                onTap: () {
                                  setState(() {
                                    _benchmark = t.key;
                                    _benchmarkTime = null;
                                  });
                                  if (t.key != _benchmarkSkipKey) {
                                    _scrollToBottom();
                                    _showTimePicker();
                                  }
                                },
                              ),
                            )
                            .toList(),
                      ),
                      if (_benchmark != null &&
                          _benchmark != _benchmarkSkipKey) ...[
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          l10n.benchmarkSelectedLabel(
                            benchmarkLabelFor[_benchmark]!,
                          ),
                          style: AppTypography.labelLarge,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        AppPickerField(
                          hint: l10n.tapToSetTime,
                          value: _benchmarkTime != null
                              ? _formatDuration(_benchmarkTime!)
                              : null,
                          onTap: _showTimePicker,
                        ),
                      ],
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
                label: widget.isEditingPlanInfo
                    ? l10n.saveChangesButton
                    : l10n.continueButton,
                onPressed: _isComplete
                    ? () {
                        ref
                            .read(onboardingProvider.notifier)
                            .setFitness(
                              experience: _experience!,
                              canRun10Min: _canRun10Min,
                              runningDays: _runningDays,
                              weeklyVolume: _weeklyVolume,
                              longestRun: _longestRun,
                              canCompleteGoalDist: _canCompleteGoalDist,
                              raceDistanceBefore: _raceDistanceBefore,
                              benchmark: _benchmark,
                              benchmarkTime: _benchmarkTime,
                            );
                        if (widget.isEditingPlanInfo) {
                          context.pop();
                        } else {
                          context.push(RouteNames.schedule);
                        }
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

// ─── Select card (full width with subtitle) ───────────────────────────────────

class _SelectCard extends StatelessWidget {
  const _SelectCard({
    required this.label,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

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
        width: double.infinity,
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AppTypography.textTheme.titleMedium?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: AppTypography.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Rectangular toggle button (Yes / No style) ───────────────────────────────

class _ToggleButton extends StatelessWidget {
  const _ToggleButton({
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
            textAlign: TextAlign.center,
            style: AppTypography.textTheme.titleMedium?.copyWith(
              color: isSelected
                  ? AppColors.textPrimary
                  : AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Segmented control (running days / race distance) ────────────────────────

class _SegmentedControl extends StatelessWidget {
  const _SegmentedControl({
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  final List<OnboardingOption> options;
  final String? selected;
  final void Function(String) onSelect;

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
                height: 44,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.accentPrimary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    opt.label,
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

// ─── Time picker bottom sheet ─────────────────────────────────────────────────

class _TimePickerSheet extends StatefulWidget {
  const _TimePickerSheet({required this.initial, required this.onConfirm});

  final Duration initial;
  final ValueChanged<Duration> onConfirm;

  @override
  State<_TimePickerSheet> createState() => _TimePickerSheetState();
}

class _TimePickerSheetState extends State<_TimePickerSheet> {
  late int _hours;
  late int _minutes;
  late int _seconds;

  @override
  void initState() {
    super.initState();
    _hours = widget.initial.inHours;
    _minutes = widget.initial.inMinutes.remainder(60);
    _seconds = widget.initial.inSeconds.remainder(60);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(l10n.yourBenchmarkTime, style: AppTypography.titleMedium),
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          height: 180,
          child: Row(
            children: [
              _WheelColumn(
                count: 24,
                initial: _hours,
                label: l10n.timePickerHours,
                onChanged: (v) => setState(() => _hours = v),
              ),
              _WheelColumn(
                count: 60,
                initial: _minutes,
                label: l10n.timePickerMinutes,
                onChanged: (v) => setState(() => _minutes = v),
              ),
              _WheelColumn(
                count: 60,
                initial: _seconds,
                label: l10n.timePickerSeconds,
                onChanged: (v) => setState(() => _seconds = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: l10n.confirm,
          onPressed: () => widget.onConfirm(
            Duration(hours: _hours, minutes: _minutes, seconds: _seconds),
          ),
        ),
      ],
    );
  }
}

class _WheelColumn extends StatelessWidget {
  const _WheelColumn({
    required this.count,
    required this.initial,
    required this.label,
    required this.onChanged,
  });

  final int count;
  final int initial;
  final String label;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Expanded(
            child: CupertinoPicker(
              scrollController: FixedExtentScrollController(
                initialItem: initial,
              ),
              itemExtent: 40,
              onSelectedItemChanged: onChanged,
              selectionOverlay: const CupertinoPickerDefaultSelectionOverlay(
                background: AppColors.accentMuted,
              ),
              children: List.generate(
                count,
                (i) => Center(
                  child: Text(
                    i.toString().padLeft(2, '0'),
                    style: AppTypography.bodyLarge.copyWith(
                      color: AppColors.textPrimary,
                    ),
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
