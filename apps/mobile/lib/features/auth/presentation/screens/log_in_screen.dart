import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../l10n/app_localizations.dart';

class LogInScreen extends StatefulWidget {
  const LogInScreen({super.key});

  @override
  State<LogInScreen> createState() => _LogInScreenState();
}

class _LogInScreenState extends State<LogInScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Back button
            _BackButton(),
            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screen,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppSpacing.lg),
                    // Headline
                    Text(l10n.logInTitle, style: AppTypography.headlineMedium),
                    const SizedBox(height: AppSpacing.sm),
                    // Subtitle
                    Text(
                      l10n.logInSubtitle,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxxl),
                    // Email field
                    AppTextField(
                      label: l10n.emailLabel,
                      hint: l10n.emailHint,
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    // Password field
                    AppTextField(
                      label: l10n.passwordLabel,
                      hint: l10n.passwordHint,
                      controller: _passwordController,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                    ),
                    const SizedBox(height: AppSpacing.base),
                    // Forgot password link
                    GestureDetector(
                      onTap: () => context.push(RouteNames.forgotPassword),
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
            // Bottom buttons
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
                    label: l10n.logIn,
                    onPressed: () => context.push(RouteNames.accountSetup),
                  ),
                  const SizedBox(height: AppSpacing.base),
                  AppButton(
                    label: l10n.dontHaveAccount,
                    onPressed: () => context.go(RouteNames.signUp),
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
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.pop(),
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
