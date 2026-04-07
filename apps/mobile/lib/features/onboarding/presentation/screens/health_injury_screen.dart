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
import '../onboarding_values.dart';
import '../../../../l10n/app_localizations.dart';

class HealthInjuryScreen extends ConsumerStatefulWidget {
  const HealthInjuryScreen({super.key});

  @override
  ConsumerState<HealthInjuryScreen> createState() => _HealthInjuryScreenState();
}

class _HealthInjuryScreenState extends ConsumerState<HealthInjuryScreen> {
  String? _painLevel;
  String? _injuryHistory;
  String? _healthConditions;

  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    final draft = ref.read(onboardingProvider);
    _painLevel = draft.health.painLevelKey;
    _injuryHistory = draft.health.injuryHistoryKey;
    _healthConditions = draft.health.healthConditionsKey;
  }

  bool get _isComplete =>
      _painLevel != null && _injuryHistory != null && _healthConditions != null;

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

    final painOptions = [
      OnboardingValues.painNo,
      OnboardingValues.painMild,
      OnboardingValues.painModerate,
      OnboardingValues.painSevere,
    ];
    final injuryOptions = [
      (key: OnboardingValues.injuryNo, label: l10n.injuryNo),
      (key: OnboardingValues.injuryOnce, label: l10n.injuryOnce),
      (key: OnboardingValues.injuryMultiple, label: l10n.injuryMultiple),
    ];

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top nav ──────────────────────────────────────────────────────
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
                        l10n.onboardingStep(4, 7),
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
                    child: AppProgressBar(current: 4, total: 7),
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
                    Text(l10n.healthTitle, style: AppTypography.headlineMedium),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      l10n.healthSubtitle,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // ── 1. Current pain or injury? ────────────────────────────
                    Text(
                      l10n.currentPainLabel,
                      style: AppTypography.labelLarge,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ...painOptions.map(
                      (option) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _SelectCard(
                          label: OnboardingValues.localizePainLevel(
                            option,
                            l10n,
                          ),
                          isSelected: _painLevel == option,
                          onTap: () {
                            setState(() {
                              _painLevel = option;
                              _injuryHistory = null;
                              _healthConditions = null;
                            });
                            _scrollToBottom();
                          },
                        ),
                      ),
                    ),

                    // ── 2. Running-related injury in the last 12 months? ──────
                    if (_painLevel != null) ...[
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        l10n.recentInjuryLabel,
                        style: AppTypography.labelLarge,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _SegmentedControl(
                        options: injuryOptions,
                        selected: _injuryHistory,
                        onSelect: (val) {
                          setState(() {
                            _injuryHistory = val;
                            _healthConditions = null;
                          });
                          _scrollToBottom();
                        },
                      ),
                    ],

                    // ── 3. Health conditions affecting exercise? ──────────────
                    if (_injuryHistory != null) ...[
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        l10n.healthConditionsLabel,
                        style: AppTypography.labelLarge,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: _ToggleButton(
                              label: l10n.no,
                              isSelected:
                                  _healthConditions == OnboardingValues.no,
                              onTap: () {
                                setState(() {
                                  _healthConditions = OnboardingValues.no;
                                });
                                _scrollToBottom();
                              },
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: _ToggleButton(
                              label: l10n.yes,
                              isSelected:
                                  _healthConditions == OnboardingValues.yes,
                              onTap: () {
                                setState(() {
                                  _healthConditions = OnboardingValues.yes;
                                });
                                _scrollToBottom();
                              },
                            ),
                          ),
                        ],
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
                            .setHealth(
                              painLevel: _painLevel!,
                              injuryHistory: _injuryHistory!,
                              healthConditions: _healthConditions!,
                            );
                        context.push(RouteNames.training);
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

// ─── Full-width select card ─────────────────────────────────────────────────

class _SelectCard extends StatelessWidget {
  const _SelectCard({
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
        child: Text(
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
            color: isSelected
                ? AppColors.accentPrimary
                : AppColors.borderDefault,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: AppTypography.titleMedium.copyWith(
              color: isSelected
                  ? AppColors.textPrimary
                  : AppColors.textSecondary,
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
