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
import '../../../../l10n/app_localizations.dart';
import '../../../profile/domain/models/runner_profile.dart';
import '../onboarding_provider.dart';
import '../onboarding_values.dart';

class StrengthPreferencesScreen extends ConsumerStatefulWidget {
  const StrengthPreferencesScreen({super.key});

  @override
  ConsumerState<StrengthPreferencesScreen> createState() =>
      _StrengthPreferencesScreenState();
}

class _StrengthPreferencesScreenState
    extends ConsumerState<StrengthPreferencesScreen> {
  bool _initialized = false;
  bool? _lifts;
  final Set<String> _preferredDays = {};
  String? _sameDayOrder;

  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    final draft = ref.read(onboardingProvider).value;
    if (draft != null) {
      _initFromDraft(draft);
      _initialized = true;
    }
  }

  void _initFromDraft(RunnerProfileDraft draft) {
    _lifts = draft.strength.lifts;
    _preferredDays
      ..clear()
      ..addAll(draft.strength.preferredDays.map((day) => day.key));
    _sameDayOrder = draft.strength.sameDayOrder?.key;
  }

  bool get _isComplete {
    if (_lifts == null) return false;
    if (_lifts == false) return true;
    return _preferredDays.isNotEmpty && _sameDayOrder != null;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
      );
    });
  }

  void _selectLifts(bool lifts) {
    setState(() {
      _lifts = lifts;
      if (!lifts) {
        _preferredDays.clear();
        _sameDayOrder = null;
      }
    });
    _scrollToBottom();
  }

  void _togglePreferredDay(String key) {
    setState(() {
      if (_preferredDays.contains(key)) {
        _preferredDays.remove(key);
      } else {
        _preferredDays.add(key);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<RunnerProfileDraft>>(onboardingProvider, (_, next) {
      if (!_initialized && next.hasValue) {
        setState(() {
          _initFromDraft(next.value!);
          _initialized = true;
        });
      }
    });
    if (!_initialized) {
      return const Scaffold(
        backgroundColor: AppColors.backgroundPrimary,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final l10n = AppLocalizations.of(context)!;
    final days = [
      OnboardingValues.dayMon,
      OnboardingValues.dayTue,
      OnboardingValues.dayWed,
      OnboardingValues.dayThu,
      OnboardingValues.dayFri,
      OnboardingValues.daySat,
      OnboardingValues.daySun,
    ];
    final sameDayOptions = [
      (
        key: SameDayOrderPreference.runFirst.key,
        label: l10n.strengthOrderRunFirst,
        subtitle: l10n.strengthOrderRunFirstSub,
      ),
      (
        key: SameDayOrderPreference.liftFirst.key,
        label: l10n.strengthOrderLiftFirst,
        subtitle: l10n.strengthOrderLiftFirstSub,
      ),
      (
        key: SameDayOrderPreference.separateSessions.key,
        label: l10n.strengthOrderSeparate,
        subtitle: l10n.strengthOrderSeparateSub,
      ),
      (
        key: SameDayOrderPreference.itDepends.key,
        label: l10n.strengthOrderDepends,
        subtitle: l10n.strengthOrderDependsSub,
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: Column(
          children: [
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
                        l10n.onboardingStep(6, 9),
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const Padding(
                    padding: EdgeInsets.only(left: AppSpacing.sm),
                    child: AppProgressBar(current: 6, total: 9),
                  ),
                ],
              ),
            ),
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
                    Text(
                      l10n.strengthPreferencesTitle,
                      style: AppTypography.headlineMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      l10n.strengthPreferencesSubtitle,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      l10n.strengthLiftsLabel,
                      style: AppTypography.labelLarge,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: _ToggleButton(
                            label: l10n.yes,
                            isSelected: _lifts == true,
                            onTap: () => _selectLifts(true),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: _ToggleButton(
                            label: l10n.no,
                            isSelected: _lifts == false,
                            onTap: () => _selectLifts(false),
                          ),
                        ),
                      ],
                    ),
                    if (_lifts == true) ...[
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        l10n.strengthPreferredDaysLabel,
                        style: AppTypography.labelLarge,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        l10n.strengthPreferredDaysHelper,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: days
                            .map(
                              (day) => _Chip(
                                label: OnboardingValues.localizeDay(day, l10n),
                                isSelected: _preferredDays.contains(day),
                                onTap: () => _togglePreferredDay(day),
                              ),
                            )
                            .toList(growable: false),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        l10n.strengthSameDayOrderLabel,
                        style: AppTypography.labelLarge,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        l10n.strengthSameDayOrderHelper,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      ...sameDayOptions.asMap().entries.map((entry) {
                        final option = entry.value;
                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: entry.key == sameDayOptions.length - 1
                                ? 0
                                : AppSpacing.sm,
                          ),
                          child: _SelectCard(
                            label: option.label,
                            subtitle: option.subtitle,
                            isSelected: _sameDayOrder == option.key,
                            onTap: () =>
                                setState(() => _sameDayOrder = option.key),
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
            ),
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
                            .setStrength(
                              lifts: _lifts!,
                              weeklyFrequency: _lifts == true
                                  ? _preferredDays.length.toString()
                                  : null,
                              categories: _lifts == true
                                  ? [StrengthCategory.lowerBody.key]
                                  : const [],
                              preferredDays: _preferredDays.toList(
                                growable: false,
                              ),
                              sameDayOrder: _sameDayOrder,
                            );
                        context.push(RouteNames.preferences);
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
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

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
              style: AppTypography.titleMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
