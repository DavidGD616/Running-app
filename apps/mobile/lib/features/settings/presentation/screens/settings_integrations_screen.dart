import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_header_bar.dart';
import '../../../../core/widgets/section_label.dart';
import '../../../../core/widgets/settings_card.dart';
import '../../../../core/widgets/settings_row.dart';
import '../../../../l10n/app_localizations.dart';

class SettingsIntegrationsScreen extends StatefulWidget {
  const SettingsIntegrationsScreen({super.key});

  @override
  State<SettingsIntegrationsScreen> createState() =>
      _SettingsIntegrationsScreenState();
}

class _SettingsIntegrationsScreenState
    extends State<SettingsIntegrationsScreen> {
  bool _appleHealthEnabled = false;
  bool _healthConnectEnabled = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final integrations = switch (defaultTargetPlatform) {
      TargetPlatform.iOS =>
        <
          ({
            String label,
            String iconAsset,
            bool enabled,
            ValueChanged<bool> onToggle,
          })
        >[
          (
            label: l10n.settingsAppleHealth,
            iconAsset: 'assets/icons/apple_health.svg',
            enabled: _appleHealthEnabled,
            onToggle: (value) => setState(() => _appleHealthEnabled = value),
          ),
        ],
      TargetPlatform.android =>
        <
          ({
            String label,
            String iconAsset,
            bool enabled,
            ValueChanged<bool> onToggle,
          })
        >[
          (
            label: l10n.settingsHealthConnect,
            iconAsset: 'assets/icons/health_connect.svg',
            enabled: _healthConnectEnabled,
            onToggle: (value) => setState(() => _healthConnectEnabled = value),
          ),
        ],
      _ =>
        <
          ({
            String label,
            String iconAsset,
            bool enabled,
            ValueChanged<bool> onToggle,
          })
        >[],
    };

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
              if (integrations.isNotEmpty)
                SettingsCard(
                  children: integrations
                      .map(
                        (integration) => SettingsRow(
                          label: integration.label,
                          iconAsset: integration.iconAsset,
                          preserveIconColors: true,
                          iconSize: 24,
                          iconContainerSize: 40,
                          variant: integration.enabled
                              ? SettingsRowVariant.toggleOn
                              : SettingsRowVariant.toggleOff,
                          onToggle: integration.onToggle,
                        ),
                      )
                      .toList(),
                ),
              if (integrations.isNotEmpty)
                const SizedBox(height: AppSpacing.xl),
              SectionLabel(label: l10n.settingsConnectedDevicesSection),
              const SizedBox(height: AppSpacing.md),
              SettingsCard(
                children: [
                  SettingsRow(
                    label: l10n.settingsGarminConnect,
                    iconAsset: 'assets/icons/watch.svg',
                    variant: SettingsRowVariant.badge,
                    badgeLabel: l10n.settingsConnected,
                    onTap: () {},
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
