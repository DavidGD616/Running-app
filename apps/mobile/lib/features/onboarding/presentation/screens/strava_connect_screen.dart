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
import '../../../../core/widgets/app_progress_bar.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../integrations/domain/models/device_connection.dart';
import '../../../integrations/presentation/device_connection_provider.dart';
import '../../../strava/data/strava_service.dart';
import '../../../strava/domain/athlete_summary.dart';
import '../onboarding_provider.dart';

class StravaConnectScreen extends ConsumerStatefulWidget {
  const StravaConnectScreen({super.key});

  @override
  ConsumerState<StravaConnectScreen> createState() =>
      _StravaConnectScreenState();
}

class _StravaConnectScreenState extends ConsumerState<StravaConnectScreen> {
  bool _isConnecting = false;
  String? _errorMessage;

  Future<void> _connectStrava() async {
    if (_isConnecting) return;

    setState(() {
      _isConnecting = true;
      _errorMessage = null;
    });

    final l10n = AppLocalizations.of(context)!;

    try {
      final service = ref.read(stravaServiceProvider);
      final athleteFuture = service.fetchAthlete();
      final statsFuture = service.fetchAthleteStats();
      final activitiesFuture = service.fetchSummaryActivities();

      final athlete = await athleteFuture;
      final stats = await statsFuture;
      final activities = await activitiesFuture;

      final summary = deriveAthleteSummary(
        activities,
        stats,
        athlete,
        DateTime.now().toUtc(),
      );
      ref.read(onboardingProvider.notifier).setStrava(summary: summary);
      await ref.read(deviceConnectionsProvider.notifier).upsertServiceConnection(
        vendor: IntegrationVendor.strava,
        capabilities: {
          IntegrationCapability.autoImport,
          IntegrationCapability.heartRate,
          IntegrationCapability.heartRateZones,
          IntegrationCapability.distance,
          IntegrationCapability.pace,
          IntegrationCapability.elevation,
        },
        lastSyncedAt: DateTime.now(),
      );

      if (!mounted) return;

      if (summary.insufficientData) {
        context.push(RouteNames.fitness);
        return;
      }

      context.push(RouteNames.schedule);
    } on StravaServiceException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = switch (error.code) {
          StravaServiceErrorCode.missingClientId =>
            l10n.onboardingStravaConnectMissingClientIdError,
          StravaServiceErrorCode.missingAuthSession =>
            l10n.onboardingStravaConnectAuthRequiredError,
          StravaServiceErrorCode.oauthDenied =>
            l10n.onboardingStravaConnectDeniedError,
          StravaServiceErrorCode.oauthMissingScope =>
            l10n.onboardingStravaConnectMissingScopeError,
          StravaServiceErrorCode.oauthStateInvalid =>
            l10n.onboardingStravaConnectStateError,
          _ => l10n.onboardingStravaConnectError,
        };
      });
    } on StateError {
      if (!mounted) return;
      setState(() {
        _errorMessage = l10n.onboardingStravaConnectAuthRequiredError;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = l10n.onboardingStravaConnectError;
      });
    } finally {
      if (mounted) {
        setState(() => _isConnecting = false);
      }
    }
  }

  void _continueWithoutStrava() {
    ref.read(onboardingProvider.notifier).useManualFitnessInput();
    context.push(RouteNames.fitness);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                AppSpacing.xs,
                AppSpacing.screen,
                0,
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => context.pop(),
                        child: SizedBox(
                          width: 48,
                          height: 48,
                          child: Center(
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
                        ),
                      ),
                      Text(
                        l10n.onboardingStep(2, 8),
                        style: AppTypography.textTheme.labelSmall?.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const Padding(
                    padding: EdgeInsets.only(left: AppSpacing.sm),
                    child: AppProgressBar(current: 2, total: 8),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screen,
                  AppSpacing.lg,
                  AppSpacing.screen,
                  AppSpacing.xl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.onboardingStravaConnectTitle,
                      style: AppTypography.headlineMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      l10n.onboardingStravaConnectSubtitle,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    _AttributionCard(
                      title: l10n.onboardingStravaAttributionTitle,
                      subtitle: l10n.onboardingStravaAttributionSubtitle,
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        _errorMessage!,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen,
                AppSpacing.sm,
                AppSpacing.screen,
                AppSpacing.xl,
              ),
              child: Column(
                children: [
                  AppButton(
                    label: l10n.onboardingStravaConnectPrimary,
                    isLoading: _isConnecting,
                    onPressed: _isConnecting ? null : _connectStrava,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    label: l10n.onboardingStravaConnectSecondary,
                    variant: AppButtonVariant.secondary,
                    onPressed: _isConnecting ? null : _continueWithoutStrava,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    l10n.onboardingStravaPoweredBy,
                    textAlign: TextAlign.center,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
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

class _AttributionCard extends StatelessWidget {
  const _AttributionCard({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.titleMedium.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            subtitle,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
