import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_typography.dart';

enum AppButtonVariant { primary, secondary, text }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.isLoading = false,
    this.isFullWidth = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool isLoading;
  final bool isFullWidth;

  @override
  Widget build(BuildContext context) {
    switch (variant) {
      case AppButtonVariant.primary:
        return _PrimaryButton(
          label: label,
          onPressed: onPressed,
          isLoading: isLoading,
          isFullWidth: isFullWidth,
        );
      case AppButtonVariant.secondary:
        return _SecondaryButton(
          label: label,
          onPressed: onPressed,
          isLoading: isLoading,
          isFullWidth: isFullWidth,
        );
      case AppButtonVariant.text:
        return _TextButton(
          label: label,
          onPressed: onPressed,
        );
    }
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.onPressed,
    required this.isLoading,
    required this.isFullWidth,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isFullWidth;

  @override
  Widget build(BuildContext context) {
    final isDisabled = onPressed == null;

    return Opacity(
      opacity: isDisabled ? 0.38 : 1.0,
      child: SizedBox(
        width: isFullWidth ? double.infinity : null,
        height: 48,
        child: ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accentPrimary,
            foregroundColor: AppColors.backgroundPrimary,
            disabledBackgroundColor: AppColors.accentPrimary,
            shape: const RoundedRectangleBorder(
              borderRadius: AppRadius.borderLg,
            ),
            elevation: 0,
          ),
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.backgroundPrimary,
                  ),
                )
              : Text(label, style: AppTypography.labelLarge.copyWith(
                  color: AppColors.backgroundPrimary,
                )),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({
    required this.label,
    required this.onPressed,
    required this.isLoading,
    required this.isFullWidth,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isFullWidth;

  @override
  Widget build(BuildContext context) {
    final isDisabled = onPressed == null;

    return Opacity(
      opacity: isDisabled ? 0.38 : 1.0,
      child: SizedBox(
        width: isFullWidth ? double.infinity : null,
        height: 48,
        child: OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.accentPrimary,
            side: const BorderSide(color: AppColors.accentPrimary),
            shape: const RoundedRectangleBorder(
              borderRadius: AppRadius.borderLg,
            ),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.accentPrimary,
                  ),
                )
              : Text(label, style: AppTypography.labelLarge.copyWith(
                  color: AppColors.accentPrimary,
                )),
        ),
      ),
    );
  }
}

class _TextButton extends StatelessWidget {
  const _TextButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      child: Text(
        label,
        style: AppTypography.labelLarge.copyWith(color: AppColors.accentPrimary),
      ),
    );
  }
}
