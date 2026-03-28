import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_header_bar.dart';
import '../../../../l10n/app_localizations.dart';

class LogRunScreen extends StatefulWidget {
  const LogRunScreen({super.key});

  @override
  State<LogRunScreen> createState() => _LogRunScreenState();
}

class _LogRunScreenState extends State<LogRunScreen> {
  String? _selectedFeeling;
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppDetailHeaderBar(
        title: l10n.logSessionTitle,
        onBack: () => Navigator.of(context).maybePop(),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screen,
                  AppSpacing.lg,
                  AppSpacing.screen,
                  AppSpacing.xl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Planned session card ──────────────────────────────
                    _PlannedSessionCard(
                      label: l10n.logSessionPlannedSession,
                      sessionName: l10n.logSessionSessionName,
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    // ── Metric cards ──────────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: _MetricCard(
                            glowColor: const Color(0xFF00D4FF),
                            iconAsset: 'assets/icons/clock.svg',
                            label: l10n.logSessionDurationLabel,
                            value: '45:12',
                            unit: l10n.logSessionMinUnit,
                            subtitle: l10n.logSessionActiveTime,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xl),
                        Expanded(
                          child: _MetricCard(
                            glowColor: const Color(0xFFFFC107),
                            iconAsset: 'assets/icons/activity.svg',
                            label: l10n.logSessionDistanceLabel,
                            value: '6.02',
                            unit: l10n.logSessionKmUnit,
                            subtitle: l10n.logSessionPaceValue,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.xl),

                    // ── How did it feel? ──────────────────────────────────
                    Text(
                      l10n.logSessionHowDidItFeel,
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _FeelButton(
                                label: l10n.logSessionEasy,
                                isSelected: _selectedFeeling == 'easy',
                                onTap: () => setState(() => _selectedFeeling = 'easy'),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: _FeelButton(
                                label: l10n.logSessionModerate,
                                isSelected: _selectedFeeling == 'moderate',
                                onTap: () => setState(() => _selectedFeeling = 'moderate'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: [
                            Expanded(
                              child: _FeelButton(
                                label: l10n.logSessionHard,
                                isSelected: _selectedFeeling == 'hard',
                                onTap: () => setState(() => _selectedFeeling = 'hard'),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: _FeelButton(
                                label: l10n.logSessionVeryHard,
                                isSelected: _selectedFeeling == 'very_hard',
                                onTap: () => setState(() => _selectedFeeling = 'very_hard'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.xl),

                    // ── Notes ─────────────────────────────────────────────
                    Row(
                      children: [
                        Text(
                          l10n.logSessionNotes,
                          style: AppTypography.titleMedium.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          l10n.logSessionOptional,
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textDisabled,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.backgroundCard,
                        borderRadius: AppRadius.borderLg,
                        border: Border.all(color: AppColors.borderDefault),
                      ),
                      child: TextField(
                        controller: _notesController,
                        maxLines: 4,
                        minLines: 4,
                        style: AppTypography.bodyMedium,
                        decoration: InputDecoration(
                          hintText: l10n.logSessionNotesHint,
                          hintStyle: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textDisabled,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(AppSpacing.base),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Save button ───────────────────────────────────────────────
            _SaveButton(label: l10n.logSessionSaveButton),
          ],
        ),
      ),
    );
  }
}

// ── Planned session card ──────────────────────────────────────────────────────

class _PlannedSessionCard extends StatelessWidget {
  const _PlannedSessionCard({required this.label, required this.sessionName});

  final String label;
  final String sessionName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base,
        vertical: AppSpacing.base,
      ),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.accentMuted,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: SvgPicture.asset(
                'assets/icons/calendar.svg',
                width: 24,
                height: 24,
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
            children: [
              Text(
                label,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textDisabled,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sessionName,
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Metric card with glow ─────────────────────────────────────────────────────

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.glowColor,
    required this.iconAsset,
    required this.label,
    required this.value,
    required this.unit,
    required this.subtitle,
  });

  final Color glowColor;
  final String iconAsset;
  final String label;
  final String value;
  final String unit;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: AppRadius.borderLg,
        boxShadow: [
          BoxShadow(
            color: glowColor,
            blurRadius: 0,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: glowColor,
            blurRadius: 5,
          ),
          BoxShadow(
            color: glowColor.withValues(alpha: 0.3),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SvgPicture.asset(
            iconAsset,
            width: 26,
            height: 26,
            colorFilter: ColorFilter.mode(glowColor, BlendMode.srcIn),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            label,
            style: AppTypography.bodyMedium.copyWith(
              color: glowColor.withValues(alpha: 0.6),
              letterSpacing: 0.6,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: AppTypography.headlineLarge.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  unit,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Feel button ───────────────────────────────────────────────────────────────

class _FeelButton extends StatelessWidget {
  const _FeelButton({
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
              color: isSelected ? AppColors.accentPrimary : AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Save button ───────────────────────────────────────────────────────────────

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0.0, 0.4, 1.0],
          colors: [
            AppColors.backgroundPrimary.withValues(alpha: 0),
            AppColors.backgroundPrimary,
            AppColors.backgroundPrimary,
          ],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        AppSpacing.lg,
        AppSpacing.screen,
        AppSpacing.xl,
      ),
      child: GestureDetector(
        onTap: () => Navigator.of(context).maybePop(),
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.accentPrimary,
            borderRadius: AppRadius.borderLg,
            boxShadow: [
              BoxShadow(
                color: AppColors.accentPrimary.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.check,
                size: 20,
                color: AppColors.backgroundPrimary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                label,
                style: AppTypography.titleMedium.copyWith(
                  color: AppColors.backgroundPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
