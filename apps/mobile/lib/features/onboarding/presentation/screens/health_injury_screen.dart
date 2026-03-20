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

class HealthInjuryScreen extends StatefulWidget {
  const HealthInjuryScreen({super.key});

  @override
  State<HealthInjuryScreen> createState() => _HealthInjuryScreenState();
}

class _HealthInjuryScreenState extends State<HealthInjuryScreen> {
  String? _painLevel;
  String? _injuryHistory;
  String? _healthConditions;
  String? _planPreference;

  final _scrollController = ScrollController();

  bool get _isComplete =>
      _painLevel != null &&
      _injuryHistory != null &&
      _healthConditions != null &&
      _planPreference != null;

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
                              colorFilter: const ColorFilter.mode(
                                AppColors.textPrimary,
                                BlendMode.srcIn,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Text(
                        '4 / 9',
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
                    child: AppProgressBar(current: 4, total: 9),
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
                    Text('Health & Injury', style: AppTypography.headlineMedium),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Help us understand any limitations so your plan keeps you safe.',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // ── 1. Current pain or injury? ────────────────────────────
                    Text('Current pain or injury?', style: AppTypography.labelLarge),
                    const SizedBox(height: AppSpacing.md),
                    ...['No', 'Yes, mild', 'Yes, moderate', 'Yes, severe']
                        .map((option) => Padding(
                              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                              child: _SelectCard(
                                label: option,
                                isSelected: _painLevel == option,
                                onTap: () {
                                  setState(() {
                                    _painLevel = option;
                                    _injuryHistory = null;
                                    _healthConditions = null;
                                    _planPreference = null;
                                  });
                                  _scrollToBottom();
                                },
                              ),
                            )),

                    // ── 2. Running-related injury in the last 12 months? ──────
                    if (_painLevel != null) ...[
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        'Running-related injury in the last 12 months?',
                        style: AppTypography.labelLarge,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _SegmentedControl(
                        options: const ['No', 'Once', 'Multiple'],
                        selected: _injuryHistory,
                        onSelect: (val) {
                          setState(() {
                            _injuryHistory = val;
                            _healthConditions = null;
                            _planPreference = null;
                          });
                          _scrollToBottom();
                        },
                      ),
                    ],

                    // ── 3. Health conditions affecting exercise? ──────────────
                    if (_injuryHistory != null) ...[
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        'Health conditions affecting exercise?',
                        style: AppTypography.labelLarge,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: _ToggleButton(
                              label: 'No',
                              isSelected: _healthConditions == 'No',
                              onTap: () {
                                setState(() {
                                  _healthConditions = 'No';
                                  _planPreference = null;
                                });
                                _scrollToBottom();
                              },
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: _ToggleButton(
                              label: 'Yes',
                              isSelected: _healthConditions == 'Yes',
                              onTap: () {
                                setState(() {
                                  _healthConditions = 'Yes';
                                  _planPreference = null;
                                });
                                _scrollToBottom();
                              },
                            ),
                          ),
                        ],
                      ),
                    ],

                    // ── 4. Plan preference ────────────────────────────────────
                    if (_healthConditions != null) ...[
                      const SizedBox(height: AppSpacing.xl),
                      Text('Plan preference', style: AppTypography.labelLarge),
                      const SizedBox(height: AppSpacing.md),
                      _SelectCard(
                        label: 'Safest possible',
                        subtitle: 'Prioritize injury prevention',
                        isSelected: _planPreference == 'Safest possible',
                        onTap: () => setState(() => _planPreference = 'Safest possible'),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _SelectCard(
                        label: 'Balanced',
                        subtitle: 'Mix of safety and progression',
                        isSelected: _planPreference == 'Balanced',
                        onTap: () => setState(() => _planPreference = 'Balanced'),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _SelectCard(
                        label: 'Performance-focused',
                        subtitle: 'Push for results',
                        isSelected: _planPreference == 'Performance-focused',
                        onTap: () => setState(() => _planPreference = 'Performance-focused'),
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
                    ? () => context.push(RouteNames.training)
                    : null,
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

// ─── Rectangular toggle button (Yes / No) ────────────────────────────────────

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
            style: AppTypography.titleMedium.copyWith(
              color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
            ),
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
