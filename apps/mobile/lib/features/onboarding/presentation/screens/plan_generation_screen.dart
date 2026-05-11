import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../l10n/app_localizations.dart';
import '../onboarding_provider.dart';
import '../plan_generation_provider.dart';

enum PlanGenerationFlowMode { onboarding, editGoal, newGoal }

class PlanGenerationScreen extends ConsumerStatefulWidget {
  const PlanGenerationScreen({
    super.key,
    this.mode = PlanGenerationFlowMode.onboarding,
  });

  final PlanGenerationFlowMode mode;

  @override
  ConsumerState<PlanGenerationScreen> createState() =>
      _PlanGenerationScreenState();
}

class _PlanGenerationScreenState extends ConsumerState<PlanGenerationScreen>
    with SingleTickerProviderStateMixin {
  int _messageIndex = 0;
  double _progress = 0.0;
  int _elapsedSeconds = 0;
  Timer? _timer;
  bool _showError = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  List<String> _getPhase1Messages(AppLocalizations l10n) => [
    l10n.planGenerationMsg1,
    l10n.planGenerationMsg2,
    l10n.planGenerationMsg3,
    l10n.planGenerationMsg4,
    l10n.planGenerationMsg5,
  ];

  List<String> _getPhase2Messages(AppLocalizations l10n) => [
    l10n.planGenerationMsg6,
    l10n.planGenerationMsg7,
    l10n.planGenerationMsg8,
    l10n.planGenerationMsg9,
  ];

  String get _requestedBy => switch (widget.mode) {
    PlanGenerationFlowMode.onboarding => 'onboarding',
    PlanGenerationFlowMode.editGoal => 'settings_update',
    PlanGenerationFlowMode.newGoal => 'settings_update',
  };

  String get _nextRoute => switch (widget.mode) {
    PlanGenerationFlowMode.onboarding => RouteNames.planReady,
    PlanGenerationFlowMode.editGoal =>
      RouteNames.settingsUpdatePlanEditGoalReady,
    PlanGenerationFlowMode.newGoal =>
      RouteNames.settingsUpdatePlanNewGoalReady,
  };

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

    // Save profile to runner_profiles first, then fire generation
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await ref
          .read(onboardingProvider.notifier)
          .saveProfile(markOnboardingComplete: false);
      if (!mounted) return;
      ref
          .read(planGenerationProvider.notifier)
          .generate(requestedBy: _requestedBy);
      _startAnimation();
    });
  }

  void _startAnimation() {
    _timer?.cancel();
    _elapsedSeconds = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      _elapsedSeconds++;

      double newProgress;
      int newMessageIndex;

      if (_elapsedSeconds <= 10) {
        // Phase 1: fast progress 0% → 40% over 10s
        newProgress = _elapsedSeconds / 10.0 * 0.40;
        newMessageIndex = ((_elapsedSeconds - 1) ~/ 2).clamp(0, 4);
      } else {
        // Phase 2: slow crawl 40% → 92% at ~1%/s
        newProgress = (0.40 + (_elapsedSeconds - 10) * 0.01).clamp(0.0, 0.92);
        // Phase 2 messages cycle every 4s, 4 messages total
        newMessageIndex = 5 + ((_elapsedSeconds - 11) ~/ 4) % 4;
      }

      setState(() {
        _progress = newProgress;
        _messageIndex = newMessageIndex;
      });
    });
  }

  void _useStarterPlan() {
    if (!mounted) return;
    context.go('$_nextRoute?starter=true');
  }

  void _retry() {
    if (!mounted) return;
    setState(() {
      _showError = false;
      _elapsedSeconds = 0;
      _messageIndex = 0;
      _progress = 0.0;
    });
    ref
        .read(planGenerationProvider.notifier)
        .generate(requestedBy: _requestedBy);
    _startAnimation();
    _pulseController.repeat(reverse: true);
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

    // Listen for generation state changes
    final router = GoRouter.of(context);
    ref.listen<PlanGenerationState>(planGenerationProvider, (_, next) {
      if (next is PlanGenerationSuccess) {
        _timer?.cancel();
        if (mounted) {
          setState(() => _progress = 1.0);
        }
        final route = _nextRoute;
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) router.go(route);
        });
      }
      if (next is PlanGenerationFailure) {
        _timer?.cancel();
        _pulseController.stop();
        if (mounted) setState(() => _showError = true);
      }
    });

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
          child: _showError ? _buildErrorState(l10n) : _buildLoadingState(l10n),
        ),
      ),
    );
  }

  // ── Loading state ───────────────────────────────────────────────────────

  Widget _buildLoadingState(AppLocalizations l10n) {
    final phase1Messages = _getPhase1Messages(l10n);
    final phase2Messages = _getPhase2Messages(l10n);
    final message = _messageIndex < 5
        ? phase1Messages[_messageIndex]
        : phase2Messages[_messageIndex - 5];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Pulsing app logo
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _pulseAnimation.value,
              child: child,
            );
          },
          child: Container(
            width: 220,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.backgroundPrimary,
              borderRadius: AppRadius.borderLg,
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
                'assets/logos/striviq_logo.svg',
                width: 174,
                height: 43,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),

        Text(
          l10n.planGenerationTitle,
          style: AppTypography.headlineMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.sm),

        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: Text(
            message,
            key: ValueKey(_messageIndex),
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

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
    );
  }

  // ── Error state ─────────────────────────────────────────────────────────

  Widget _buildErrorState(AppLocalizations l10n) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: AppColors.backgroundPrimary,
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.error,
              width: 2.5,
            ),
          ),
          child: const Center(
            child: Icon(
              Icons.error_outline_rounded,
              size: 40,
              color: AppColors.error,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),

        Text(
          l10n.planGenerationErrorTitle,
          style: AppTypography.headlineMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.sm),

        Text(
          l10n.planGenerationErrorSubtitle,
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xxl),

        AppButton(
          label: l10n.planGenerationRetry,
          onPressed: _retry,
        ),
        const SizedBox(height: AppSpacing.md),

        AppButton(
          label: l10n.planGenerationUseStarter,
          onPressed: _useStarterPlan,
          variant: AppButtonVariant.secondary,
        ),
      ],
    );
  }
}
