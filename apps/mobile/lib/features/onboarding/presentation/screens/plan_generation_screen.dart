import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

class PlanGenerationScreen extends StatefulWidget {
  const PlanGenerationScreen({super.key});

  @override
  State<PlanGenerationScreen> createState() => _PlanGenerationScreenState();
}

class _PlanGenerationScreenState extends State<PlanGenerationScreen>
    with SingleTickerProviderStateMixin {
  static const _messages = [
    'Analyzing your fitness profile...',
    'Calculating optimal training zones...',
    'Building your weekly structure...',
    'Personalizing session targets...',
    'Your plan is almost ready!',
  ];

  int _messageIndex = 0;
  double _progress = 0.0;
  Timer? _timer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

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
      final nextIndex = _messageIndex + 1;
      if (nextIndex < _messages.length) {
        setState(() {
          _messageIndex = nextIndex;
          _progress = nextIndex / (_messages.length - 1);
        });
      } else {
        timer.cancel();
        Future.delayed(const Duration(milliseconds: 600), () {
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
                'Building Your Plan',
                style: AppTypography.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),

              // Cycling subtitle
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: Text(
                  _messages[_messageIndex],
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
