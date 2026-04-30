import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../l10n/app_localizations.dart';
import '../auth_notifier.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String? _passwordErrorText;
  String? _confirmPasswordErrorText;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _validate(AppLocalizations l10n) {
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    setState(() {
      _passwordErrorText = password.isEmpty
          ? l10n.authValidationPasswordRequired
          : password.length < 6
          ? l10n.authValidationPasswordTooShort
          : null;
      _confirmPasswordErrorText = confirmPassword.isEmpty
          ? l10n.authValidationConfirmPasswordRequired
          : confirmPassword != password
          ? l10n.authValidationPasswordMismatch
          : null;
    });
  }

  Future<void> _submit(AppLocalizations l10n) async {
    _validate(l10n);
    if (_passwordErrorText != null || _confirmPasswordErrorText != null) return;

    FocusScope.of(context).unfocus();

    final feedback = await ref
        .read(authNotifierProvider.notifier)
        .updatePassword(
          newPassword: _passwordController.text,
          l10n: l10n,
        );

    if (!mounted || feedback == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(feedback.message),
        backgroundColor: feedback.isError
            ? AppColors.error
            : AppColors.accentPrimary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isLoading = ref.watch(authNotifierProvider).isLoading;

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _BackButton(isEnabled: !isLoading),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screen,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      l10n.resetPasswordTitle,
                      style: AppTypography.headlineMedium,
                    ),
                    const SizedBox(height: AppSpacing.xxxl),
                    AppTextField(
                      label: l10n.resetPasswordNewPasswordLabel,
                      errorText: _passwordErrorText,
                      controller: _passwordController,
                      obscureText: true,
                      textInputAction: TextInputAction.next,
                      onChanged: (_) {
                        if (_passwordErrorText == null &&
                            _confirmPasswordErrorText == null) {
                          return;
                        }
                        setState(() {
                          _passwordErrorText = null;
                          if (_confirmPasswordController.text.isNotEmpty) {
                            _confirmPasswordErrorText =
                                _confirmPasswordController.text ==
                                    _passwordController.text
                                ? null
                                : l10n.authValidationPasswordMismatch;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppTextField(
                      label: l10n.resetPasswordConfirmPasswordLabel,
                      errorText: _confirmPasswordErrorText,
                      controller: _confirmPasswordController,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      onChanged: (_) {
                        if (_confirmPasswordErrorText == null) return;
                        setState(() => _confirmPasswordErrorText = null);
                      },
                    ),
                    const SizedBox(height: AppSpacing.xxxl),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen,
                AppSpacing.base,
                AppSpacing.screen,
                AppSpacing.xl,
              ),
              child: AppButton(
                label: isLoading ? l10n.resetPasswordUpdating : l10n.resetPasswordButton,
                onPressed: isLoading ? null : () => _submit(l10n),
                isLoading: isLoading,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.isEnabled});

  final bool isEnabled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isEnabled ? () => Navigator.of(context).maybePop() : null,
      child: Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        margin: const EdgeInsets.only(left: AppSpacing.sm, top: AppSpacing.xs),
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
    );
  }
}
