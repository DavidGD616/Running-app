import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_header_bar.dart';
import '../../../../core/widgets/section_label.dart';
import '../../../../core/widgets/settings_card.dart';
import '../../../../core/widgets/settings_row.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../integrations/domain/models/device_connection.dart';
import '../../../integrations/presentation/device_connection_provider.dart';
import '../../../onboarding/presentation/onboarding_values.dart';
import '../../../strava/data/strava_service.dart';
export '../../../profile/domain/models/runner_profile.dart'
    show BinaryChoice, DeviceProfile, WatchDeviceType;

class SettingsIntegrationsScreen extends ConsumerWidget {
  const SettingsIntegrationsScreen({super.key});

  String _integrationLabel(IntegrationVendor vendor, AppLocalizations l10n) {
    return switch (vendor) {
      IntegrationVendor.appleHealth => l10n.settingsAppleHealth,
      IntegrationVendor.healthConnect => l10n.settingsHealthConnect,
      IntegrationVendor.strava => l10n.settingsStrava,
      IntegrationVendor.garmin => OnboardingValues.localizeDevice(
        OnboardingValues.deviceGarmin,
        l10n,
      ),
      IntegrationVendor.appleWatch => OnboardingValues.localizeDevice(
        OnboardingValues.deviceAppleWatch,
        l10n,
      ),
      IntegrationVendor.coros => OnboardingValues.localizeDevice(
        OnboardingValues.deviceCoros,
        l10n,
      ),
      IntegrationVendor.polar => OnboardingValues.localizeDevice(
        OnboardingValues.devicePolar,
        l10n,
      ),
      IntegrationVendor.suunto => OnboardingValues.localizeDevice(
        OnboardingValues.deviceSuunto,
        l10n,
      ),
      IntegrationVendor.fitbit => OnboardingValues.localizeDevice(
        OnboardingValues.deviceFitbit,
        l10n,
      ),
      IntegrationVendor.other => OnboardingValues.localizeDevice(
        OnboardingValues.deviceOther,
        l10n,
      ),
    };
  }

  String _iconAssetForVendor(IntegrationVendor vendor) {
    return switch (vendor) {
      IntegrationVendor.appleHealth => 'assets/icons/apple_health.svg',
      IntegrationVendor.healthConnect => 'assets/icons/health_connect.svg',
      IntegrationVendor.strava => 'assets/icons/trending_up.svg',
      _ => 'assets/icons/watch.svg',
    };
  }

  Future<void> _setStravaConnection({
    required BuildContext context,
    required WidgetRef ref,
    required bool enabled,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final connectionNotifier = ref.read(deviceConnectionsProvider.notifier);

    if (enabled) {
      try {
        final stravaService = ref.read(stravaServiceProvider);
        await stravaService.fetchAthlete();
        await connectionNotifier.upsertServiceConnection(
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

        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.settingsStravaConnectSuccess)),
        );
      } on StravaServiceException catch (error) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_stravaConnectErrorMessage(l10n, error.code)),
          ),
        );
      } on StateError {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.onboardingStravaConnectAuthRequiredError)),
        );
      } on AuthException {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.onboardingStravaConnectAuthRequiredError)),
        );
      } catch (_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.settingsStravaConnectError)),
        );
      }

      return;
    }

    await connectionNotifier.removeConnectionForVendor(IntegrationVendor.strava);

    try {
      final stravaService = ref.read(stravaServiceProvider);
      await stravaService.disconnect();

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.settingsStravaDisconnectSuccess)),
      );
    } on StravaServiceException {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.settingsStravaDisconnectError)),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.settingsStravaDisconnectError)),
      );
    }
  }

  String _stravaConnectErrorMessage(
    AppLocalizations l10n,
    StravaServiceErrorCode code,
  ) {
    return switch (code) {
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
      _ => l10n.settingsStravaConnectError,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final platformIntegrations = ref.watch(
      availablePlatformIntegrationsProvider,
    );
    final connectedIntegrations = ref.watch(
      connectedIntegrationConnectionsProvider,
    );

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppDetailHeaderBar(title: l10n.settingsIntegrations),
      body: SafeArea(
        top: false,
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
              SectionLabel(label: l10n.settingsAvailableIntegrationsSection),
              const SizedBox(height: AppSpacing.md),
              if (platformIntegrations.isNotEmpty)
                SettingsCard(
                  children: platformIntegrations.map((integration) {
                    final connection = ref.watch(
                      connectionForVendorProvider(integration.vendor),
                    );
                    final enabled = connection?.isConnected ?? false;
                    final isStrava =
                        integration.vendor == IntegrationVendor.strava;
                    return SettingsRow(
                      label: _integrationLabel(integration.vendor, l10n),
                      iconAsset: _iconAssetForVendor(integration.vendor),
                      preserveIconColors: true,
                      iconSize: 24,
                      iconContainerSize: 40,
                      variant: enabled
                          ? SettingsRowVariant.toggleOn
                          : SettingsRowVariant.toggleOff,
                      onToggle: (value) async {
                        if (isStrava) {
                          await _setStravaConnection(
                            context: context,
                            ref: ref,
                            enabled: value,
                          );
                          return;
                        }

                        final result = await ref
                            .read(deviceConnectionsProvider.notifier)
                            .setPlatformConnection(
                              vendor: integration.vendor,
                              enabled: value,
                            );

                        if (result == SetPlatformConnectionResult.permissionDenied &&
                            context.mounted) {
                          final l10n = AppLocalizations.of(context)!;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                l10n.settingsHealthExportPermissionDenied,
                              ),
                              action: SnackBarAction(
                                label: l10n.settingsHealthExportOpenSettings,
                                onPressed: () async {
                                  await openAppSettings();
                                },
                              ),
                            ),
                          );
                        }
                      },
                    );
                  }).toList(),
                ),
              if (platformIntegrations.isNotEmpty)
                const SizedBox(height: AppSpacing.xl),
              SectionLabel(label: l10n.settingsConnectedDevicesSection),
              const SizedBox(height: AppSpacing.md),
              if (connectedIntegrations.isNotEmpty)
                SettingsCard(
                  children: connectedIntegrations
                      .map(
                        (connection) => SettingsRow(
                          label: _integrationLabel(connection.vendor, l10n),
                          iconAsset: _iconAssetForVendor(connection.vendor),
                          variant: SettingsRowVariant.badge,
                          badgeLabel: l10n.settingsConnected,
                          onTap: () {},
                        ),
                      )
                      .toList(),
                )
              else
                Text(
                  l10n.settingsNoConnectedDevices,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textDisabled,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
