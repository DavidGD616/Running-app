import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../onboarding_provider.dart';
import '../../../../l10n/app_localizations.dart';

class PlanGenerationScreen extends ConsumerStatefulWidget {
  const PlanGenerationScreen({super.key});

  @override
  ConsumerState<PlanGenerationScreen> createState() => _PlanGenerationScreenState();
}

class _PlanGenerationScreenState extends ConsumerState<PlanGenerationScreen>
    with SingleTickerProviderStateMixin {

  int _messageIndex = 0;
  double _progress = 0.0;
  Timer? _timer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  List<String> _getMessages(AppLocalizations l10n) => [
    l10n.planGenerationMsg1,
    l10n.planGenerationMsg2,
    l10n.planGenerationMsg3,
    l10n.planGenerationMsg4,
    l10n.planGenerationMsg5,
  ];

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Step through messages every 2 seconds
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      final messages = _getMessages(l10n);
      final nextIndex = _messageIndex + 1;
      if (nextIndex < messages.length) {
        setState(() {
          _messageIndex = nextIndex;
          _progress = nextIndex / (messages.length - 1);
        });
      } else {
        timer.cancel();
        Future.delayed(const Duration(milliseconds: 600), () async {
          if (!mounted) return;
          await ref.read(onboardingProvider.notifier).markCompleted();
          if (mounted) context.go(RouteNames.home);
        });
      }
    });

    // Animate progress to first step immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _progress = 0.0);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final messages = _getMessages(l10n);

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pulsing icon circle
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: child,
                  );
                },
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: AppColors.backgroundPrimary,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.accentPrimary,
                      width: 2.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accentPrimary.withValues(alpha: 0.25),
                        blurRadius: 20,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Center(
                    child: SvgPicture.asset(
                      'assets/icons/zap.svg',
                      width: 36,
                      height: 36,
                      colorFilter: const ColorFilter.mode(
                        AppColors.accentPrimary,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),

              // Title
              Text(
                l10n.planGenerationTitle,
                style: AppTypography.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),

              // Cycling subtitle
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: Text(
                  messages[_messageIndex],
                  key: ValueKey(_messageIndex),
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(100),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: _progress),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeInOut,
                  builder: (context, value, _) {
                    return LinearProgressIndicator(
                      value: value,
                      minHeight: 6,
                      backgroundColor: AppColors.backgroundCard,
                      valueColor: const AlwaysStoppedAnimation(
                        AppColors.accentPrimary,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              // Percentage
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: _progress),
                duration: const Duration(milliseconds: 600),
                builder: (context, value, _) {
                  return Text(
                    '${(value * 100).round()}%',
                    style: AppTypography.labelMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
