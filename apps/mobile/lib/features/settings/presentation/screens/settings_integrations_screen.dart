import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
export '../../../profile/domain/models/runner_profile.dart'
    show BinaryChoice, DeviceProfile, WatchDeviceType;

class SettingsIntegrationsScreen extends ConsumerWidget {
  const SettingsIntegrationsScreen({super.key});

  String _integrationLabel(IntegrationVendor vendor, AppLocalizations l10n) {
    return switch (vendor) {
      IntegrationVendor.appleHealth => l10n.settingsAppleHealth,
      IntegrationVendor.healthConnect => l10n.settingsHealthConnect,
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
      _ => 'assets/icons/watch.svg',
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final platformIntegrations = ref.watch(
      availablePlatformIntegrationsProvider,
    );
    final connectedWearables = ref.watch(connectedWearableConnectionsProvider);

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
                        await ref
                            .read(deviceConnectionsProvider.notifier)
                            .setPlatformConnection(
                              vendor: integration.vendor,
                              enabled: value,
                            );
                      },
                    );
                  }).toList(),
                ),
              if (platformIntegrations.isNotEmpty)
                const SizedBox(height: AppSpacing.xl),
              SectionLabel(label: l10n.settingsConnectedDevicesSection),
              const SizedBox(height: AppSpacing.md),
              if (connectedWearables.isNotEmpty)
                SettingsCard(
                  children: connectedWearables
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
