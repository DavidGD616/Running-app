import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_progress_bar.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  String? _trainingDays;
  String? _longRunDay;
  String? _weekdayTime;
  String? _weekendTime;
  final Set<String> _hardDays = {};
  String? _preferredTimeOfDay;

  final _scrollController = ScrollController();

  bool get _isComplete =>
      _trainingDays != null &&
      _longRunDay != null &&
      _weekdayTime != null &&
      _weekendTime != null &&
      _preferredTimeOfDay != null;

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
                              colorFilter: ColorFilter.mode(
                                AppColors.textPrimary,
                                BlendMode.srcIn,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Text(
                        '3 / 9',
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
                    Text('Your Schedule', style: AppTypography.headlineMedium),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Tell us when you can realistically train.',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // ── 1. Training days per week ─────────────────────────────
                    Text('Training days per week', style: AppTypography.labelLarge),
                    const SizedBox(height: AppSpacing.md),
                    _SegmentedControl(
                      options: const ['2', '3', '4', '5', '6', '7'],
                      selected: _trainingDays,
                      onSelect: (val) {
                        setState(() {
                          _trainingDays = val;
                          _longRunDay = null;
                          _weekdayTime = null;
                          _weekendTime = null;
                          _hardDays.clear();
                          _preferredTimeOfDay = null;
                        });
                        _scrollToBottom();
                      },
                    ),

                    // ── 2. Preferred long run day ─────────────────────────────
                    if (_trainingDays != null) ...[
                      const SizedBox(height: AppSpacing.xl),
                      Text('Preferred long run day', style: AppTypography.labelLarge),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'This is the anchor of your weekly plan',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                            .map((day) => _Chip(
                                  label: day,
                                  isSelected: _longRunDay == day,
                                  onTap: () {
                                    setState(() {
                                      _longRunDay = day;
                                      _weekdayTime = null;
                                      _weekendTime = null;
                                      _hardDays.clear();
                                      _preferredTimeOfDay = null;
                                    });
                                    _scrollToBottom();
                                  },
                                ))
                            .toList(),
                      ),
                    ],

                    // ── 3. Weekday time available ─────────────────────────────
                    if (_longRunDay != null) ...[
                      const SizedBox(height: AppSpacing.xl),
                      Text('Weekday time available', style: AppTypography.labelLarge),
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: ['20 min', '30 min', '45 min', '60 min', '75+ min']
                            .map((t) => _Chip(
                                  label: t,
                                  isSelected: _weekdayTime == t,
                                  onTap: () {
                                    setState(() {
                                      _weekdayTime = t;
                                      _weekendTime = null;
                                      _hardDays.clear();
                                      _preferredTimeOfDay = null;
                                    });
                                    _scrollToBottom();
                                  },
                                ))
                            .toList(),
                      ),
                    ],

                    // ── 4. Weekend time available ─────────────────────────────
                    if (_weekdayTime != null) ...[
                      const SizedBox(height: AppSpacing.xl),
                      Text('Weekend time available', style: AppTypography.labelLarge),
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: ['30 min', '45 min', '60 min', '90 min', '2+ hours']
                            .map((t) => _Chip(
                                  label: t,
                                  isSelected: _weekendTime == t,
                                  onTap: () {
                                    setState(() {
                                      _weekendTime = t;
                                      _hardDays.clear();
                                      _preferredTimeOfDay = null;
                                    });
                                    _scrollToBottom();
                                  },
                                ))
                            .toList(),
                      ),
                    ],

                    // ── 5. Days that are hard to train (optional, multi-select)
                    if (_weekendTime != null) ...[
                      const SizedBox(height: AppSpacing.xl),
                      Text('Days that are hard to train', style: AppTypography.labelLarge),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Select any that apply',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                            .map((day) => _Chip(
                                  label: day,
                                  isSelected: _hardDays.contains(day),
                                  onTap: () {
                                    setState(() {
                                      if (_hardDays.contains(day)) {
                                        _hardDays.remove(day);
                                      } else {
                                        _hardDays.add(day);
                                      }
                                    });
                                  },
                                ))
                            .toList(),
                      ),
                    ],

                    // ── 6. Preferred time of day ──────────────────────────────
                    if (_weekendTime != null) ...[
                      const SizedBox(height: AppSpacing.xl),
                      Text('Preferred time of day', style: AppTypography.labelLarge),
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          'Early morning',
                          'Morning',
                          'Afternoon',
                          'Evening',
                          'No preference',
                        ]
                            .map((t) => _Chip(
                                  label: t,
                                  isSelected: _preferredTimeOfDay == t,
                                  onTap: () {
                                    setState(() => _preferredTimeOfDay = t);
                                  },
                                ))
                            .toList(),
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
                label: 'Continue',
                onPressed: _isComplete
                    ? () => context.push(RouteNames.health)
                    : null,
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
