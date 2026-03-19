import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_progress_bar.dart';

class RecoveryLifestyleScreen extends StatefulWidget {
  const RecoveryLifestyleScreen({super.key});

  @override
  State<RecoveryLifestyleScreen> createState() =>
      _RecoveryLifestyleScreenState();
}

class _RecoveryLifestyleScreenState extends State<RecoveryLifestyleScreen> {
  String? _sleep;
  String? _workLevel;
  String? _stressLevel;
  String? _dayFeeling;

  final _scrollController = ScrollController();

  bool get _isComplete =>
      _sleep != null &&
      _workLevel != null &&
      _stressLevel != null &&
      _dayFeeling != null;

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
                        '7 / 9',
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
                    child: AppProgressBar(current: 7, total: 9),
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
                    Text('Recovery & Lifestyle',
                        style: AppTypography.headlineMedium),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Quick questions to understand your recovery capacity.',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // ── 1. Average weekday sleep ──────────────────────────────
                    Text('Average weekday sleep',
                        style: AppTypography.labelLarge),
                    const SizedBox(height: AppSpacing.md),
                    _SegmentedControl(
                      options: const ['< 5h', '5–6h', '6–7h', '7–8h', '+8h'],
                      selected: _sleep,
                      onSelect: (val) {
                        setState(() {
                          _sleep = val;
                          _workLevel = null;
                          _stressLevel = null;
                          _dayFeeling = null;
                        });
                        _scrollToBottom();
                      },
                    ),

                    // ── 2. Work / activity level ──────────────────────────────
                    if (_sleep != null) ...[
                      const SizedBox(height: AppSpacing.xl),
                      Text('Work / activity level',
                          style: AppTypography.labelLarge),
                      const SizedBox(height: AppSpacing.md),
                      _SelectCard(
                        label: 'Mostly desk',
                        subtitle: 'Sitting most of the day',
                        isSelected: _workLevel == 'Mostly desk',
                        onTap: () {
                          setState(() {
                            _workLevel = 'Mostly desk';
                            _stressLevel = null;
                            _dayFeeling = null;
                          });
                          _scrollToBottom();
                        },
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _SelectCard(
                        label: 'Mixed',
                        subtitle: 'Some sitting, some moving',
                        isSelected: _workLevel == 'Mixed',
                        onTap: () {
                          setState(() {
                            _workLevel = 'Mixed';
                            _stressLevel = null;
                            _dayFeeling = null;
                          });
                          _scrollToBottom();
                        },
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _SelectCard(
                        label: 'Physical job',
                        subtitle: 'On your feet most of the day',
                        isSelected: _workLevel == 'Physical job',
                        onTap: () {
                          setState(() {
                            _workLevel = 'Physical job';
                            _stressLevel = null;
                            _dayFeeling = null;
                          });
                          _scrollToBottom();
                        },
                      ),
                    ],

                    // ── 3. Average stress level ───────────────────────────────
                    if (_workLevel != null) ...[
                      const SizedBox(height: AppSpacing.xl),
                      Text('Average stress level',
                          style: AppTypography.labelLarge),
                      const SizedBox(height: AppSpacing.md),
                      _SegmentedControl(
                        options: const ['Low', 'Moderate', 'High'],
                        selected: _stressLevel,
                        onSelect: (val) {
                          setState(() {
                            _stressLevel = val;
                            _dayFeeling = null;
                          });
                          _scrollToBottom();
                        },
                      ),
                    ],

                    // ── 4. How do you feel day-to-day? ────────────────────────
                    if (_stressLevel != null) ...[
                      const SizedBox(height: AppSpacing.xl),
                      Text('How do you feel day-to-day?',
                          style: AppTypography.labelLarge),
                      const SizedBox(height: AppSpacing.md),
                      ...['Usually fresh', 'Sometimes tired', 'Often tired', 'Always tired']
                          .map((option) => Padding(
                                padding: const EdgeInsets.only(
                                    bottom: AppSpacing.sm),
                                child: _SelectCard(
                                  label: option,
                                  isSelected: _dayFeeling == option,
                                  onTap: () =>
                                      setState(() => _dayFeeling = option),
                                ),
                              )),
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
                onPressed: _isComplete ? () {} : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Full-width select card ───────────────────────────────────────────────────

class _SelectCard extends StatelessWidget {
  const _SelectCard({
    required this.label,
    this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final String? subtitle;
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
        child: subtitle != null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTypography.titleMedium.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              )
            : Text(
                label,
                style: AppTypography.titleMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
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
