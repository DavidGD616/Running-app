import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_progress_bar.dart';

class AppTopNavBar extends StatelessWidget {
  const AppTopNavBar({
    super.key,
    this.onBack,
    this.title,
    this.currentStep,
    this.totalSteps,
    this.trailing,
  });

  final VoidCallback? onBack;
  final String? title;

  /// Set both [currentStep] and [totalSteps] to show the progress bar.
  final int? currentStep;
  final int? totalSteps;
  final Widget? trailing;

  bool get _showProgress => currentStep != null && totalSteps != null;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screen,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              // Back button
              GestureDetector(
                onTap: onBack ?? () => Navigator.of(context).maybePop(),
                child: Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.arrow_back_ios_new,
                    color: AppColors.textPrimary,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // Title (optional)
              Expanded(
                child: title != null
                    ? Text(
                        title!,
                        style: AppTypography.labelLarge,
                        textAlign: TextAlign.center,
                      )
                    : const SizedBox.shrink(),
              ),
              // Trailing (optional) — same size as back button to keep layout balanced
              SizedBox(
                width: 40,
                height: 40,
                child: trailing ?? const SizedBox.shrink(),
              ),
            ],
          ),
        ),
        if (_showProgress) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
            child: AppProgressBar(
              current: currentStep!,
              total: totalSteps!,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}
