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
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_progress_bar.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../onboarding_provider.dart';
import '../../../../core/utils/unit_formatter.dart';
import '../../../user_preferences/domain/user_preferences.dart';
import '../../../user_preferences/presentation/user_preferences_provider.dart';

class CurrentFitnessScreen extends ConsumerStatefulWidget {
  const CurrentFitnessScreen({super.key});

  @override
  ConsumerState<CurrentFitnessScreen> createState() => _CurrentFitnessScreenState();
}

class _CurrentFitnessScreenState extends ConsumerState<CurrentFitnessScreen> {
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

  bool get _isBrandNew => _experience == 'Brand new';

  bool get _isComplete {
    if (_experience == null) return false;
    if (_isBrandNew) {
      return _canRun10Min != null &&
          (_benchmark == null || _benchmark == 'Skip for now' || _benchmarkTime != null);
    }
    return _runningDays != null &&
        _weeklyVolume != null &&
        _longestRun != null &&
        _canCompleteGoalDist != null &&
        _raceDistanceBefore != null &&
        (_benchmark == null || _benchmark == 'Skip for now' || _benchmarkTime != null);
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
    final unitSystem = ref
        .watch(userPreferencesProvider)
        .valueOrNull
        ?.unitSystem ?? UnitSystem.km;

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
                        '2 / 9',
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
                  AppSpacing.screen, AppSpacing.lg,
                  AppSpacing.screen, AppSpacing.xl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Current Fitness', style: AppTypography.headlineMedium),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      "Help us understand where you're starting from.",
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // ── Running experience ───────────────────────────────────
                    Text('Running experience', style: AppTypography.labelLarge),
                    const SizedBox(height: AppSpacing.md),
                    _SelectCard(
                      label: 'Brand new',
                      subtitle: 'Never really run before',
                      isSelected: _experience == 'Brand new',
                      onTap: () => _selectExperience('Brand new'),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _SelectCard(
                      label: 'Beginner',
                      subtitle: 'Some running, no consistent plan',
                      isSelected: _experience == 'Beginner',
                      onTap: () => _selectExperience('Beginner'),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _SelectCard(
                      label: 'Intermediate',
                      subtitle: 'Run regularly, some race experience',
                      isSelected: _experience == 'Intermediate',
                      onTap: () => _selectExperience('Intermediate'),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _SelectCard(
                      label: 'Experienced',
                      subtitle: 'Structured training, multiple races',
                      isSelected: _experience == 'Experienced',
                      onTap: () => _selectExperience('Experienced'),
                    ),

                    // ── Brand new: 10-minute run question ────────────────────
                    if (_isBrandNew) ...[
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        'Can you currently run continuously for 10 minutes?',
                        style: AppTypography.labelLarge,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: _ToggleButton(
                              label: 'Yes',
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
                              label: 'No',
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
                          Text('Optional benchmark', style: AppTypography.labelLarge),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            'optional',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: UnitFormatter.benchmarkOptions(unitSystem)
                        .map((bench) => _Chip(
                          label: bench,
                          isSelected: _benchmark == bench,
                          onTap: () {
                            setState(() {
                              _benchmark = bench;
                              _benchmarkTime = null;
                            });
                            if (bench != 'Skip for now') {
                              _scrollToBottom();
                              _showTimePicker();
                            }
                          },
                        )).toList(),
                      ),
                      if (_benchmark != null && _benchmark != 'Skip for now') ...[
                        const SizedBox(height: AppSpacing.lg),
                        Text('Your $_benchmark', style: AppTypography.labelLarge),
                        const SizedBox(height: AppSpacing.sm),
                        AppPickerField(
                          hint: 'Tap to set time',
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
                      Text('Current running days per week', style: AppTypography.labelLarge),
                      const SizedBox(height: AppSpacing.md),
                      _SegmentedControl(
                        options: const ['0', '1', '2', '3', '4', '5+'],
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
                      Text('Average weekly volume', style: AppTypography.labelLarge),
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: UnitFormatter.weeklyVolumeOptions(unitSystem)
                        .map((vol) => _Chip(
                          label: vol,
                          isSelected: _weeklyVolume == vol,
                          onTap: () {
                            setState(() {
                              _weeklyVolume = vol;
                              _longestRun = null;
                              _canCompleteGoalDist = null;
                              _raceDistanceBefore = null;
                              _benchmark = null;
                              _benchmarkTime = null;
                            });
                            _scrollToBottom();
                          },
                        )).toList(),
                      ),
                    ],

                    // 3. Longest recent run
                    if (_weeklyVolume != null && !_isBrandNew) ...[
                      const SizedBox(height: AppSpacing.xl),
                      Text('Longest recent run', style: AppTypography.labelLarge),
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: UnitFormatter.longestRunOptions(unitSystem)
                        .map((run) => _Chip(
                          label: run,
                          isSelected: _longestRun == run,
                          onTap: () {
                            setState(() {
                              _longestRun = run;
                              _canCompleteGoalDist = null;
                              _raceDistanceBefore = null;
                              _benchmark = null;
                              _benchmarkTime = null;
                            });
                            _scrollToBottom();
                          },
                        )).toList(),
                      ),
                    ],

                    // 4. Can you complete your goal distance?
                    if (_longestRun != null && !_isBrandNew) ...[
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        'Can you currently complete your goal distance?',
                        style: AppTypography.labelLarge,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: ['Yes', 'No', 'Not sure'].asMap().entries.map((entry) {
                          final isLast = entry.key == 2;
                          return Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(right: isLast ? 0 : AppSpacing.md),
                              child: _ToggleButton(
                                label: entry.value,
                                isSelected: _canCompleteGoalDist == entry.value,
                                onTap: () {
                                  setState(() {
                                    _canCompleteGoalDist = entry.value;
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
                        'Have you done this race distance before?',
                        style: AppTypography.labelLarge,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _SegmentedControl(
                        options: const ['Never', 'Once', '2-3', '4+'],
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
                          Text('Optional benchmark', style: AppTypography.labelLarge),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            'optional',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: UnitFormatter.benchmarkOptions(unitSystem)
                        .map((bench) => _Chip(
                          label: bench,
                          isSelected: _benchmark == bench,
                          onTap: () {
                            setState(() {
                              _benchmark = bench;
                              _benchmarkTime = null;
                            });
                            if (bench != 'Skip for now') {
                              _scrollToBottom();
                              _showTimePicker();
                            }
                          },
                        )).toList(),
                      ),
                      if (_benchmark != null && _benchmark != 'Skip for now') ...[
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          'Your $_benchmark',
                          style: AppTypography.labelLarge,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        AppPickerField(
                          hint: 'Tap to set time',
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
                AppSpacing.screen, AppSpacing.sm,
                AppSpacing.screen, AppSpacing.xl,
              ),
              child: AppButton(
                label: 'Continue',
                onPressed: _isComplete
                    ? () {
                        ref.read(onboardingProvider.notifier).setFitness(
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
                        context.push(RouteNames.schedule);
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
            color: isSelected ? AppColors.accentPrimary : AppColors.borderDefault,
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
            color: isSelected ? AppColors.accentPrimary : AppColors.borderDefault,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: AppTypography.textTheme.titleMedium?.copyWith(
              color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
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

  final List<String> options;
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
          final isSelected = selected == opt;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelect(opt),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 44,
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.accentPrimary : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    opt,
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
            color: isSelected ? AppColors.accentPrimary : AppColors.backgroundCard,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: isSelected ? AppColors.accentPrimary : AppColors.borderDefault,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: AppTypography.labelMedium.copyWith(
                color: isSelected ? AppColors.backgroundPrimary : AppColors.textSecondary,
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
  const _TimePickerSheet({
    required this.initial,
    required this.onConfirm,
  });

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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Your benchmark time',
          style: AppTypography.titleMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          height: 180,
          child: Row(
            children: [
              _WheelColumn(
                count: 24,
                initial: _hours,
                label: 'h',
                onChanged: (v) => setState(() => _hours = v),
              ),
              _WheelColumn(
                count: 60,
                initial: _minutes,
                label: 'min',
                onChanged: (v) => setState(() => _minutes = v),
              ),
              _WheelColumn(
                count: 60,
                initial: _seconds,
                label: 'sec',
                onChanged: (v) => setState(() => _seconds = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: 'Confirm',
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
            style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Expanded(
            child: CupertinoPicker(
              scrollController: FixedExtentScrollController(initialItem: initial),
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
