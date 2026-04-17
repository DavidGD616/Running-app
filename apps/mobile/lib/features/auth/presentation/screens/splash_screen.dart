import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _splashTimer;

  @override
  void initState() {
    super.initState();
    _splashTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) context.go(RouteNames.welcome);
    });
  }

  @override
  void dispose() {
    _splashTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // App logo
            SvgPicture.asset(
              'assets/logos/striviq_logo.svg',
              width: 210,
              height: 52,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: AppSpacing.lg),
            // App name
            Text(l10n.appTitle, style: AppTypography.headlineLarge),
            const SizedBox(height: AppSpacing.sm),
            // Tagline
            Text(
              l10n.splashTagline,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xxxl),
            // Spinner
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.accentPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
