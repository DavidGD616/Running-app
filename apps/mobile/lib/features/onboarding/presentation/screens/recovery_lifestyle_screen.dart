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

class RecoveryLifestyleScreen extends ConsumerStatefulWidget {
  const RecoveryLifestyleScreen({super.key});

  @override
  ConsumerState<RecoveryLifestyleScreen> createState() =>
      _RecoveryLifestyleScreenState();
}

class _RecoveryLifestyleScreenState extends ConsumerState<RecoveryLifestyleScreen> {
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
    final l10n = AppLocalizations.of(context)!;

    final sleepOptions = [
      l10n.sleepLessThan5h,
      l10n.sleep5to6h,
      l10n.sleep6to7h,
      l10n.sleep7to8h,
      l10n.sleep8plusH,
    ];

    final stressOptions = [l10n.stressLow, l10n.stressModerate, l10n.stressHigh];

    final feelingOptions = [
      l10n.feelingFresh,
      l10n.feelingSometimesTired,
      l10n.feelingOftenTired,
      l10n.feelingAlwaysTired,
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
                        l10n.onboardingStep(7, 9),
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
                    Text(l10n.recoveryTitle,
                        style: AppTypography.headlineMedium),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      l10n.recoverySubtitle,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // ── 1. Average weekday sleep ──────────────────────────────
                    Text(l10n.sleepLabel,
                        style: AppTypography.labelLarge),
                    const SizedBox(height: AppSpacing.md),
                    _SegmentedControl(
                      options: sleepOptions,
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
                      Text(l10n.workLevelLabel,
                          style: AppTypography.labelLarge),
                      const SizedBox(height: AppSpacing.md),
                      _SelectCard(
                        label: l10n.workMostlyDesk,
                        subtitle: l10n.workMostlyDeskSub,
                        isSelected: _workLevel == l10n.workMostlyDesk,
                        onTap: () {
                          setState(() {
                            _workLevel = l10n.workMostlyDesk;
                            _stressLevel = null;
                            _dayFeeling = null;
                          });
                          _scrollToBottom();
                        },
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _SelectCard(
                        label: l10n.workMixed,
                        subtitle: l10n.workMixedSub,
                        isSelected: _workLevel == l10n.workMixed,
                        onTap: () {
                          setState(() {
                            _workLevel = l10n.workMixed;
                            _stressLevel = null;
                            _dayFeeling = null;
                          });
                          _scrollToBottom();
                        },
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _SelectCard(
                        label: l10n.workPhysical,
                        subtitle: l10n.workPhysicalSub,
                        isSelected: _workLevel == l10n.workPhysical,
                        onTap: () {
                          setState(() {
                            _workLevel = l10n.workPhysical;
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
                      Text(l10n.stressLabel,
                          style: AppTypography.labelLarge),
                      const SizedBox(height: AppSpacing.md),
                      _SegmentedControl(
                        options: stressOptions,
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
                      Text(l10n.dayFeelingLabel,
                          style: AppTypography.labelLarge),
                      const SizedBox(height: AppSpacing.md),
                      ...feelingOptions
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
                label: l10n.continueButton,
                onPressed: _isComplete
                    ? () {
                        ref.read(onboardingProvider.notifier).setRecovery(
                              sleep: _sleep!,
                              workLevel: _workLevel!,
                              stressLevel: _stressLevel!,
                              dayFeeling: _dayFeeling!,
                            );
                        context.push(RouteNames.motivation);
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
