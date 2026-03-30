import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../features/training_plan/domain/models/session_type.dart';
import '../../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_bottom_sheet.dart';

class SkipWorkoutBottomSheet extends StatelessWidget {
  const SkipWorkoutBottomSheet({
    super.key,
    required this.sessionName,
    this.status,
    this.onSkip,
    this.onRestore,
  });

  final String sessionName;
  final SessionStatus? status;
  final VoidCallback? onSkip;
  final VoidCallback? onRestore;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: SvgPicture.asset(
                  'assets/icons/close.svg',
                  width: 24,
                  height: 24,
                  colorFilter: const ColorFilter.mode(
                    AppColors.textSecondary,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),
            Text(l10n.workoutOptionsTitle, style: AppTypography.titleMedium),
            const SizedBox(width: 48),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          sessionName,
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Container(height: 1, color: AppColors.borderDefault),
        const SizedBox(height: AppSpacing.md),
        if (status == SessionStatus.skipped) ...[
          GestureDetector(
            onTap: () {
              onRestore?.call();
              Navigator.of(context).pop();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: SvgPicture.asset(
                        'assets/icons/rotate_left.svg',
                        width: 20,
                        height: 20,
                        colorFilter: const ColorFilter.mode(
                          AppColors.success,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.workoutOptionsRestoreWorkout,
                          style: AppTypography.bodyLarge.copyWith(
                            color: AppColors.success,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          l10n.workoutOptionsRestoreWorkoutDescription,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ] else ...[
          GestureDetector(
            onTap: () {
              onSkip?.call();
              Navigator.of(context).pop();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: SvgPicture.asset(
                        'assets/icons/skip_forward.svg',
                        width: 20,
                        height: 20,
                        colorFilter: const ColorFilter.mode(
                          AppColors.error,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.workoutOptionsSkipWorkout,
                          style: AppTypography.bodyLarge.copyWith(
                            color: AppColors.error,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          l10n.workoutOptionsSkipWorkoutDescription,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

void showSkipWorkoutBottomSheet({
  required BuildContext context,
  required String sessionName,
  SessionStatus? status,
  VoidCallback? onSkip,
  VoidCallback? onRestore,
}) {
  showAppBottomSheet(
    context: context,
    child: SkipWorkoutBottomSheet(
      sessionName: sessionName,
      status: status,
      onSkip: onSkip,
      onRestore: onRestore,
    ),
  );
}
