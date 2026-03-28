import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'plan_badge_pill.dart';

class ProfileCard extends StatelessWidget {
  const ProfileCard({
    super.key,
    required this.name,
    this.planName,
    this.weekInfo,
    this.avatarUrl,
    this.onEdit,
  });

  final String name;
  final String? planName;
  final String? weekInfo;
  final String? avatarUrl;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Row(
        children: [
          _Avatar(avatarUrl: avatarUrl),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppTypography.titleMedium),
                if (planName != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  PlanBadgePill(planName: planName!),
                ],
                if (weekInfo != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    weekInfo!,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textDisabled,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onEdit != null)
            GestureDetector(
              onTap: onEdit,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: SvgPicture.asset(
                  'assets/icons/edit.svg',
                  width: 20,
                  height: 20,
                  colorFilter: const ColorFilter.mode(
                      AppColors.textSecondary, BlendMode.srcIn),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({this.avatarUrl});

  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.backgroundSecondary,
        border: Border.all(color: AppColors.borderDefault),
        image: avatarUrl != null
            ? DecorationImage(
                image: NetworkImage(avatarUrl!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: avatarUrl == null
          ? Center(
              child: SvgPicture.asset(
                'assets/icons/person.svg',
                width: 26,
                height: 26,
                colorFilter: const ColorFilter.mode(
                    AppColors.textSecondary, BlendMode.srcIn),
              ),
            )
          : null,
    );
  }
}
