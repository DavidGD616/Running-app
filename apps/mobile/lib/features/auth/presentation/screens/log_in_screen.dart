import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../l10n/app_localizations.dart';
import '../auth_notifier.dart';

class LogInScreen extends ConsumerStatefulWidget {
  const LogInScreen({super.key});

  @override
  ConsumerState<LogInScreen> createState() => _LogInScreenState();
}

class _LogInScreenState extends ConsumerState<LogInScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  String? _emailErrorText;
  String? _passwordErrorText;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _validate(AppLocalizations l10n) {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    setState(() {
      _emailErrorText = email.isEmpty
          ? l10n.authValidationEmailRequired
          : !_isValidEmail(email)
          ? l10n.authErrorInvalidEmail
          : null;
      _passwordErrorText = password.isEmpty
          ? l10n.authValidationPasswordRequired
          : null;
    });

    return _emailErrorText == null && _passwordErrorText == null;
  }

  Future<void> _submit(AppLocalizations l10n) async {
    if (!_validate(l10n)) {
      return;
    }

    FocusScope.of(context).unfocus();

    final feedback = await ref
        .read(authNotifierProvider.notifier)
        .signInWithPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          l10n: l10n,
        );

    if (!mounted || feedback == null) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(feedback.message),
        backgroundColor: feedback.isError
            ? AppColors.error
            : AppColors.accentPrimary,
      ),
    );
  }

  bool _isValidEmail(String value) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
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
                    Text(l10n.logInTitle, style: AppTypography.headlineMedium),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      l10n.logInSubtitle,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxxl),
                    AppTextField(
                      label: l10n.emailLabel,
                      hint: l10n.emailHint,
                      errorText: _emailErrorText,
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      onChanged: (_) {
                        if (_emailErrorText == null) {
                          return;
                        }
                        setState(() => _emailErrorText = null);
                      },
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppTextField(
                      label: l10n.passwordLabel,
                      hint: l10n.passwordHint,
                      errorText: _passwordErrorText,
                      controller: _passwordController,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      onChanged: (_) {
                        if (_passwordErrorText == null) {
                          return;
                        }
                        setState(() => _passwordErrorText = null);
                      },
                    ),
                    const SizedBox(height: AppSpacing.base),
                    GestureDetector(
                      onTap: isLoading
                          ? null
                          : () => context.push(RouteNames.forgotPassword),
                      child: Text(
                        l10n.forgotPassword,
                        style: AppTypography.labelLarge.copyWith(
                          color: AppColors.accentPrimary,
                        ),
                      ),
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
              child: Column(
                children: [
                  AppButton(
                    label: isLoading ? l10n.authLoadingLogIn : l10n.logIn,
                    onPressed: isLoading ? null : () => _submit(l10n),
                    isLoading: isLoading,
                  ),
                  const SizedBox(height: AppSpacing.base),
                  AppButton(
                    label: l10n.dontHaveAccount,
                    onPressed: isLoading
                        ? null
                        : () => context.go(RouteNames.signUp),
                    variant: AppButtonVariant.text,
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

class _BackButton extends StatelessWidget {
  const _BackButton({required this.isEnabled});

  final bool isEnabled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isEnabled ? () => context.pop() : null,
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
