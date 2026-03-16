import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_progress_bar.dart';
import '../../../../core/widgets/app_text_field.dart';

class GoalScreen extends StatefulWidget {
  const GoalScreen({super.key});

  @override
  State<GoalScreen> createState() => _GoalScreenState();
}

class _GoalScreenState extends State<GoalScreen> {
  String? _selectedRace;
  bool? _hasRaceDate;
  DateTime? _raceDate;
  String? _priority;
  Duration? _currentTime;
  Duration? _targetTime;
  final _scrollController = ScrollController();

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
      );
    });
  }

  static const _races = [
    _Race('5K', '3.1 miles', 'assets/icons/flame.svg'),
    _Race('10K', '6.2 miles', 'assets/icons/flame.svg'),
    _Race('Half Marathon', '13.1 miles', 'assets/icons/trophy.svg'),
    _Race('Marathon', '26.2 miles', 'assets/icons/medal.svg'),
    _Race('Other', 'Custom distance', 'assets/icons/mountain.svg'),
  ];

  static const _priorities = [
    'Just finish',
    'Finish feeling strong',
    'Improve my time',
    'Build consistency',
    'General fitness',
  ];

  String get _raceDateDisplay {
    if (_raceDate == null) return '';
    final d = _raceDate!;
    return '${d.day.toString().padLeft(2, '0')} / ${d.month.toString().padLeft(2, '0')} / ${d.year}';
  }

  Future<void> _pickRaceDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _raceDate ?? DateTime.now().add(const Duration(days: 90)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.accentPrimary,
            onPrimary: AppColors.backgroundPrimary,
            surface: AppColors.backgroundSecondary,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _raceDate = picked);
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  Future<void> _showTimePicker({
    required String title,
    required Duration? initial,
    required ValueChanged<Duration> onConfirm,
  }) async {
    await showAppBottomSheet(
      context: context,
      child: _TimePickerSheet(
        title: title,
        initial: initial ?? Duration.zero,
        onConfirm: (d) {
          onConfirm(d);
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
    final showRaceDateQuestion = _selectedRace != null;
    final showRaceDate = _hasRaceDate == true;
    final showPriority = _selectedRace != null && _hasRaceDate != null;
    final showTimeFields = _priority == 'Improve my time';

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: Column(
          children: [
            // Top nav: back + step counter + progress bar
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
                        onTap: () => Navigator.of(context).maybePop(),
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
                        '1 / 9',
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
                    child: AppProgressBar(current: 1, total: 9),
                  ),
                ],
              ),
            ),
            // Scrollable form
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
                    Text("What's your goal?", style: AppTypography.headlineMedium),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      "Tell us what you're training for and what outcome you want.",
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // Goal race cards
                    Text('Goal race', style: AppTypography.labelLarge),
                    const SizedBox(height: AppSpacing.md),
                    ..._races.map(
                      (race) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: _RaceCard(
                          race: race,
                          isSelected: _selectedRace == race.name,
                          onTap: () {
                            setState(() {
                              _selectedRace = race.name;
                              _hasRaceDate = null;
                              _raceDate = null;
                              _priority = null;
                            });
                            _scrollToBottom();
                          },
                        ),
                      ),
                    ),

                    // Do you have a race date? (reveals after selecting goal)
                    if (showRaceDateQuestion) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text('Do you have a race date?', style: AppTypography.labelLarge),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: _ToggleButton(
                              label: 'Yes',
                              isSelected: _hasRaceDate == true,
                              onTap: () {
                                setState(() {
                                  _hasRaceDate = true;
                                  _priority = null;
                                });
                                _scrollToBottom();
                              },
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: _ToggleButton(
                              label: 'No',
                              isSelected: _hasRaceDate == false,
                              onTap: () {
                                setState(() {
                                  _hasRaceDate = false;
                                  _raceDate = null;
                                  _priority = null;
                                });
                                _scrollToBottom();
                              },
                            ),
                          ),
                        ],
                      ),
                    ],

                    // Race date picker (only if Yes)
                    if (showRaceDate) ...[
                      const SizedBox(height: AppSpacing.xl),
                      AppPickerField(
                        label: 'Race date',
                        hint: 'DD / MM / YYYY',
                        value: _raceDate != null ? _raceDateDisplay : null,
                        onTap: _pickRaceDate,
                        suffixIcon: const Icon(
                          Icons.calendar_today_outlined,
                          color: AppColors.textSecondary,
                          size: 18,
                        ),
                      ),
                    ],

                    // What's your priority? (reveals after answering race date)
                    if (showPriority) ...[
                      const SizedBox(height: AppSpacing.xl),
                      Text("What's your priority?", style: AppTypography.labelLarge),
                      const SizedBox(height: AppSpacing.md),
                      ..._priorities.map(
                        (p) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: _PriorityCard(
                            label: p,
                            isSelected: _priority == p,
                            onTap: () {
                            setState(() => _priority = p);
                            _scrollToBottom();
                          },
                          ),
                        ),
                      ),

                      // Time pickers (only if Improve my time)
                      if (showTimeFields) ...[
                        AppPickerField(
                          label: 'Current race time',
                          hint: 'Tap to set time',
                          value: _currentTime != null
                              ? _formatDuration(_currentTime!)
                              : null,
                          onTap: () => _showTimePicker(
                            title: 'Current race time',
                            initial: _currentTime,
                            onConfirm: (d) =>
                                setState(() => _currentTime = d),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        AppPickerField(
                          label: 'Target race time',
                          hint: 'Tap to set time',
                          value: _targetTime != null
                              ? _formatDuration(_targetTime!)
                              : null,
                          onTap: () => _showTimePicker(
                            title: 'Target race time',
                            initial: _targetTime,
                            onConfirm: (d) =>
                                setState(() => _targetTime = d),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                    ],
                  ],
                ),
              ),
            ),

            // Continue button
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen,
                AppSpacing.sm,
                AppSpacing.screen,
                AppSpacing.xl,
              ),
              child: AppButton(
                label: 'Continue',
                onPressed: () {},
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Data model ──────────────────────────────────────────────────────────────

class _Race {
  const _Race(this.name, this.subtitle, this.icon);
  final String name;
  final String subtitle;
  final String icon;
}

// ─── Race choice card ─────────────────────────────────────────────────────────

class _RaceCard extends StatelessWidget {
  const _RaceCard({
    required this.race,
    required this.isSelected,
    required this.onTap,
  });

  final _Race race;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 76,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accentMuted : AppColors.backgroundCard,
          borderRadius: AppRadius.borderLg,
          border: Border.all(
            color: isSelected ? AppColors.accentPrimary : AppColors.borderDefault,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
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
                  race.icon,
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  race.name,
                  style: AppTypography.textTheme.titleMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  race.subtitle,
                  style: AppTypography.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Yes / No toggle ─────────────────────────────────────────────────────────

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

// ─── Priority card ────────────────────────────────────────────────────────────

class _PriorityCard extends StatelessWidget {
  const _PriorityCard({
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
        height: 56,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accentMuted : AppColors.backgroundCard,
          borderRadius: AppRadius.borderLg,
          border: Border.all(
            color: isSelected ? AppColors.accentPrimary : AppColors.borderDefault,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            label,
            style: AppTypography.textTheme.titleMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Time picker wheel sheet ──────────────────────────────────────────────────

class _TimePickerSheet extends StatefulWidget {
  const _TimePickerSheet({
    required this.title,
    required this.initial,
    required this.onConfirm,
  });

  final String title;
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
          widget.title,
          style: AppTypography.textTheme.titleMedium?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
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
            style: AppTypography.textTheme.labelSmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Expanded(
            child: CupertinoPicker(
              scrollController:
                  FixedExtentScrollController(initialItem: initial),
              itemExtent: 40,
              onSelectedItemChanged: onChanged,
              selectionOverlay: CupertinoPickerDefaultSelectionOverlay(
                background: AppColors.accentMuted,
              ),
              children: List.generate(
                count,
                (i) => Center(
                  child: Text(
                    i.toString().padLeft(2, '0'),
                    style: AppTypography.textTheme.bodyLarge?.copyWith(
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
