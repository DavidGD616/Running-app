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
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_progress_bar.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../onboarding_provider.dart';
import '../onboarding_values.dart';
import '../../../profile/domain/models/runner_profile.dart';
import '../../../user_preferences/presentation/user_preferences_provider.dart';
import '../../../user_preferences/domain/user_preferences.dart';
import '../../../../l10n/app_localizations.dart';

enum GoalFlowMode { onboarding, editGoal, newGoal }

class GoalScreen extends ConsumerStatefulWidget {
  const GoalScreen({super.key, this.mode = GoalFlowMode.onboarding});

  final GoalFlowMode mode;

  @override
  ConsumerState<GoalScreen> createState() => _GoalScreenState();
}

class _GoalScreenState extends ConsumerState<GoalScreen> {
  bool _initialized = false;
  String? _selectedRace;
  bool? _hasRaceDate;
  DateTime? _raceDate;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    if (widget.mode == GoalFlowMode.newGoal) {
      _initialized = true;
    } else {
      final draft = ref.read(onboardingProvider).value;
      if (draft != null) {
        _initFromDraft(draft);
        _initialized = true;
      }
    }
  }

  void _initFromDraft(RunnerProfileDraft draft) {
    _selectedRace = draft.goal.raceKey;
    _hasRaceDate = draft.goal.hasRaceDate;
    _raceDate = draft.goal.raceDate;
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

  List<_Race> _buildRaces(UnitSystem unit, AppLocalizations l10n) => [
    _Race(
      OnboardingValues.race5k,
      OnboardingValues.localizeRace(OnboardingValues.race5k, l10n),
      OnboardingValues.raceSubtitle(OnboardingValues.race5k, unit, l10n),
      'assets/icons/flame.svg',
    ),
    _Race(
      OnboardingValues.race10k,
      OnboardingValues.localizeRace(OnboardingValues.race10k, l10n),
      OnboardingValues.raceSubtitle(OnboardingValues.race10k, unit, l10n),
      'assets/icons/flame.svg',
    ),
    _Race(
      OnboardingValues.raceHalfMarathon,
      OnboardingValues.localizeRace(OnboardingValues.raceHalfMarathon, l10n),
      OnboardingValues.raceSubtitle(
        OnboardingValues.raceHalfMarathon,
        unit,
        l10n,
      ),
      'assets/icons/trophy.svg',
    ),
    _Race(
      OnboardingValues.raceMarathon,
      OnboardingValues.localizeRace(OnboardingValues.raceMarathon, l10n),
      OnboardingValues.raceSubtitle(OnboardingValues.raceMarathon, unit, l10n),
      'assets/icons/medal.svg',
    ),
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
          if (widget.mode != GoalFlowMode.newGoal) _initFromDraft(next.value!);
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
    final isSettingsFlow = widget.mode != GoalFlowMode.onboarding;
    final screenTitle = switch (widget.mode) {
      GoalFlowMode.onboarding => l10n.goalTitle,
      GoalFlowMode.editGoal => l10n.settingsEditGoal,
      GoalFlowMode.newGoal => l10n.settingsNewGoal,
    };
    final nextRoute = switch (widget.mode) {
      GoalFlowMode.onboarding => RouteNames.fitnessSource,
      GoalFlowMode.editGoal => RouteNames.settingsUpdatePlanEditGoalSchedule,
      GoalFlowMode.newGoal => RouteNames.settingsUpdatePlanNewGoalSchedule,
    };
    final unitSystem =
        ref.watch(userPreferencesProvider).value?.unitSystem ?? UnitSystem.km;
    final races = _buildRaces(unitSystem, l10n);

    final showRaceDateQuestion = _selectedRace != null;
    final showRaceDate = _hasRaceDate == true;

    final isComplete =
        _selectedRace != null &&
        _hasRaceDate != null &&
        (_hasRaceDate == false || _raceDate != null);

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: isSettingsFlow ? AppDetailHeaderBar(title: screenTitle) : null,
      body: SafeArea(
        top: !isSettingsFlow,
        child: Column(
          children: [
            if (!isSettingsFlow)
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
                          l10n.onboardingStep(1, 9),
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
                    if (!isSettingsFlow) ...[
                      Text(l10n.goalTitle, style: AppTypography.headlineMedium),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        l10n.goalSubtitle,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                    ],

                    // Goal race cards
                    Text(l10n.goalRaceLabel, style: AppTypography.labelLarge),
                    const SizedBox(height: AppSpacing.md),
                    ...races.map(
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
                            });
                            _scrollToBottom();
                          },
                        ),
                      ),
                    ),

                    // Do you have a race date? (reveals after selecting goal)
                    if (showRaceDateQuestion) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        l10n.raceHasDateLabel,
                        style: AppTypography.labelLarge,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: _ToggleButton(
                              label: l10n.yes,
                              isSelected: _hasRaceDate == true,
                              onTap: () {
                                setState(() {
                                  _hasRaceDate = true;
                                });
                                _scrollToBottom();
                              },
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: _ToggleButton(
                              label: l10n.no,
                              isSelected: _hasRaceDate == false,
                              onTap: () {
                                setState(() {
                                  _hasRaceDate = false;
                                  _raceDate = null;
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
                        label: l10n.raceDateLabel,
                        hint: l10n.tapToSetDate,
                        value: _raceDate != null ? _raceDateDisplay : null,
                        onTap: _pickRaceDate,
                        suffixIcon: const Icon(
                          Icons.calendar_today_outlined,
                          color: AppColors.textSecondary,
                          size: 18,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Continue / Save button
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen,
                AppSpacing.sm,
                AppSpacing.screen,
                AppSpacing.xl,
              ),
              child: AppButton(
                label: l10n.continueButton,
                onPressed: isComplete
                    ? () {
                        ref
                            .read(onboardingProvider.notifier)
                            .setGoal(
                              race: _selectedRace!,
                              hasRaceDate: _hasRaceDate!,
                              raceDate: _raceDate,
                            );
                        context.push(nextRoute);
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

// ─── Data model ──────────────────────────────────────────────────────────────

class _Race {
  const _Race(this.name, this.displayName, this.subtitle, this.icon);
  final String name; // canonical key — used for comparisons
  final String displayName; // localized — shown in UI
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
            color: isSelected
                ? AppColors.accentPrimary
                : AppColors.borderDefault,
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    race.displayName,
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
            color: isSelected
                ? AppColors.accentPrimary
                : AppColors.borderDefault,
          ),
        ),
        child: Center(
          child: Text(
            label,
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
