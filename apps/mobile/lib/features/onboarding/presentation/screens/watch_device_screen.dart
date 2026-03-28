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
import '../onboarding_provider.dart';
import '../../../../l10n/app_localizations.dart';

class WatchDeviceScreen extends ConsumerStatefulWidget {
  const WatchDeviceScreen({super.key});

  @override
  ConsumerState<WatchDeviceScreen> createState() => _WatchDeviceScreenState();
}

class _WatchDeviceScreenState extends ConsumerState<WatchDeviceScreen> {
  // ── Shared ────────────────────────────────────────────────────────────────
  String? _hasWatch; // 'Yes' | 'No'

  // ── Yes path ──────────────────────────────────────────────────────────────
  String? _device;
  String? _dataUsage;
  String? _watchMetrics;
  final Set<String> _metrics = {};
  String? _hrZones;
  String? _paceRecs;
  String? _autoAdjust;

  // ── No path ───────────────────────────────────────────────────────────────
  String? _noWatchGuidance;

  final _scrollController = ScrollController();

  bool get _isComplete {
    if (_hasWatch == null) return false;
    if (_hasWatch == 'Yes') {
      return _device != null &&
          _dataUsage != null &&
          _watchMetrics != null &&
          (_watchMetrics != 'Yes' || _metrics.isNotEmpty) &&
          _hrZones != null &&
          _paceRecs != null &&
          _autoAdjust != null;
    }
    return _noWatchGuidance != null;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
      );
    });
  }

  void _selectHasWatch(String val) {
    setState(() {
      _hasWatch = val;
      _device = null;
      _dataUsage = null;
      _watchMetrics = null;
      _metrics.clear();
      _hrZones = null;
      _paceRecs = null;
      _autoAdjust = null;
      _noWatchGuidance = null;
    });
    _scrollToBottom();
  }

  void _toggleMetric(String metric) {
    setState(() {
      if (metric == 'None') {
        _metrics.clear();
        _metrics.add('None');
      } else {
        _metrics.remove('None');
        if (_metrics.contains(metric)) {
          _metrics.remove(metric);
        } else {
          _metrics.add(metric);
        }
      }
    });
    if (_metrics.isNotEmpty) _scrollToBottom();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final deviceOptions = [
      (l10n.deviceGarmin, l10n.deviceGarmin),
      (l10n.deviceAppleWatch, l10n.deviceAppleWatch),
      (l10n.deviceCOROS, l10n.deviceCOROS),
      (l10n.devicePolar, l10n.devicePolar),
      (l10n.deviceSuunto, l10n.deviceSuunto),
      (l10n.deviceFitbit, l10n.deviceFitbit),
      (l10n.deviceOther, l10n.deviceOther),
    ];

    final metricOptions = [
      ('Heart rate', l10n.metricHeartRate),
      ('Heart rate zones', l10n.metricHRZones),
      ('Pace', l10n.metricPace),
      ('Distance', l10n.metricDistance),
      ('Cadence', l10n.metricCadence),
      ('Elevation', l10n.metricElevation),
      ('Training load', l10n.metricTrainingLoad),
      ('Recovery time', l10n.metricRecoveryTime),
      ('None', l10n.metricNone),
    ];

    final noWatchOptions = [
      ('Effort only', l10n.noWatchEffortOnly, l10n.noWatchEffortOnlySub),
      ('Time-based runs', l10n.noWatchTimeBased, l10n.noWatchTimeBasedSub),
      ('Simple beginner guidance', l10n.noWatchBeginner, l10n.noWatchBeginnerSub),
      ('Decide for me', l10n.noWatchDecideForMe, l10n.noWatchDecideForMeSub),
    ];

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top nav ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm, AppSpacing.xs, AppSpacing.screen, 0,
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
                        l10n.onboardingStep(6, 9),
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
                    child: AppProgressBar(current: 6, total: 9),
                  ),
                ],
              ),
            ),

            // ── Scrollable body ──────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screen, AppSpacing.lg,
                  AppSpacing.screen, AppSpacing.xl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.watchTitle, style: AppTypography.headlineMedium),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      l10n.watchSubtitle,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // ── Do you use a watch or running device? ─────────────────
                    Text(
                      l10n.usesWatchLabel,
                      style: AppTypography.labelLarge,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: _IconToggleButton(
                            icon: 'assets/icons/watch.svg',
                            label: l10n.yes,
                            isSelected: _hasWatch == 'Yes',
                            onTap: () => _selectHasWatch('Yes'),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: _IconToggleButton(
                            icon: 'assets/icons/smartphone.svg',
                            label: l10n.no,
                            isSelected: _hasWatch == 'No',
                            onTap: () => _selectHasWatch('No'),
                          ),
                        ),
                      ],
                    ),

                    // ═══════════════════════════════════════════════════════════
                    // YES PATH
                    // ═══════════════════════════════════════════════════════════

                    // ── Which device? ─────────────────────────────────────────
                    if (_hasWatch == 'Yes') ...[
                      const SizedBox(height: AppSpacing.xl),
                      Text(l10n.deviceLabel, style: AppTypography.labelLarge),
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: deviceOptions.map((opt) => _Chip(
                          label: opt.$2,
                          isSelected: _device == opt.$1,
                          onTap: () {
                            setState(() {
                              _device = opt.$1;
                              _dataUsage = null;
                              _watchMetrics = null;
                              _metrics.clear();
                              _hrZones = null;
                              _paceRecs = null;
                              _autoAdjust = null;
                            });
                            _scrollToBottom();
                          },
                        )).toList(),
                      ),
                    ],

                    // ── How should the app use your device data? ──────────────
                    if (_hasWatch == 'Yes' && _device != null) ...[
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        l10n.deviceDataUsageLabel,
                        style: AppTypography.labelLarge,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      ...([
                        l10n.dataUsageImportAuto,
                        l10n.dataUsageHROnly,
                        l10n.dataUsagePaceDistance,
                        l10n.dataUsageAll,
                        l10n.dataUsageNotSure,
                      ].map((opt) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _SelectCard(
                          label: opt,
                          isSelected: _dataUsage == opt,
                          onTap: () {
                            setState(() {
                              _dataUsage = opt;
                              _watchMetrics = null;
                              _metrics.clear();
                              _hrZones = null;
                              _paceRecs = null;
                              _autoAdjust = null;
                            });
                            _scrollToBottom();
                          },
                        ),
                      ))),
                    ],

                    // ── Use watch-based metrics? ──────────────────────────────
                    if (_hasWatch == 'Yes' && _dataUsage != null) ...[
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        l10n.useWatchMetricsLabel,
                        style: AppTypography.labelLarge,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _SegmentedControl(
                        options: const ['Yes', 'No', 'HR only'],
                        selected: _watchMetrics,
                        onSelect: (val) {
                          setState(() {
                            _watchMetrics = val;
                            _metrics.clear();
                            _hrZones = null;
                            _paceRecs = null;
                            _autoAdjust = null;
                          });
                          _scrollToBottom();
                        },
                      ),
                    ],

                    // ── Which metrics? (multi-select, only when Yes) ──────────
                    if (_hasWatch == 'Yes' && _watchMetrics == 'Yes') ...[
                      const SizedBox(height: AppSpacing.xl),
                      Text(l10n.metricsLabel, style: AppTypography.labelLarge),
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: metricOptions.map(((String, String) m) => _Chip(
                          label: m.$2,
                          isSelected: _metrics.contains(m.$1),
                          onTap: () => _toggleMetric(m.$1),
                        )).toList(),
                      ),
                    ],

                    // ── Heart-rate-based training zones? ──────────────────────
                    if (_hasWatch == 'Yes' &&
                        _watchMetrics != null &&
                        (_watchMetrics != 'Yes' || _metrics.isNotEmpty)) ...[
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        l10n.hrZonesLabel,
                        style: AppTypography.labelLarge,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _SegmentedControl(
                        options: const ['Yes', 'No', 'If supported'],
                        selected: _hrZones,
                        onSelect: (val) {
                          setState(() {
                            _hrZones = val;
                            _paceRecs = null;
                            _autoAdjust = null;
                          });
                          _scrollToBottom();
                        },
                      ),
                    ],

                    // ── Pace recommendations from watch? ──────────────────────
                    if (_hasWatch == 'Yes' && _hrZones != null) ...[
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        l10n.paceFromWatchLabel,
                        style: AppTypography.labelLarge,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _SegmentedControl(
                        options: const ['Yes', 'No'],
                        selected: _paceRecs,
                        onSelect: (val) {
                          setState(() {
                            _paceRecs = val;
                            _autoAdjust = null;
                          });
                          _scrollToBottom();
                        },
                      ),
                    ],

                    // ── Auto-adjust plan from watch data? ─────────────────────
                    if (_hasWatch == 'Yes' && _paceRecs != null) ...[
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        l10n.autoAdjustLabel,
                        style: AppTypography.labelLarge,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _SegmentedControl(
                        options: [l10n.autoAdjustAuto, l10n.autoAdjustAskFirst, l10n.no],
                        selected: _autoAdjust,
                        onSelect: (val) => setState(() => _autoAdjust = val),
                      ),
                    ],

                    // ═══════════════════════════════════════════════════════════
                    // NO PATH
                    // ═══════════════════════════════════════════════════════════

                    if (_hasWatch == 'No') ...[
                      const SizedBox(height: AppSpacing.xl),
                      // Info card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSpacing.base),
                        decoration: BoxDecoration(
                          color: AppColors.backgroundCard,
                          borderRadius: AppRadius.borderMd,
                          border: Border.all(color: AppColors.borderDefault),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SvgPicture.asset(
                              'assets/icons/wifi.svg',
                              width: 18,
                              height: 18,
                              colorFilter: const ColorFilter.mode(
                                AppColors.textSecondary,
                                BlendMode.srcIn,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                l10n.noWatchInfo,
                                style: AppTypography.bodyMedium.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        l10n.noWatchGuidanceLabel,
                        style: AppTypography.labelLarge,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      ...(noWatchOptions.map(((String, String, String) opt) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _SelectCard(
                          label: opt.$2,
                          subtitle: opt.$3,
                          isSelected: _noWatchGuidance == opt.$1,
                          onTap: () =>
                              setState(() => _noWatchGuidance = opt.$1),
                        ),
                      ))),
                    ],
                  ],
                ),
              ),
            ),

            // ── Continue button ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen, AppSpacing.sm,
                AppSpacing.screen, AppSpacing.xl,
              ),
              child: AppButton(
                label: l10n.continueButton,
                onPressed: _isComplete
                    ? () {
                        ref.read(onboardingProvider.notifier).setDevice(
                              hasWatch: _hasWatch!,
                              device: _device,
                              dataUsage: _dataUsage,
                              watchMetrics: _watchMetrics,
                              metrics: _metrics.toList(),
                              hrZones: _hrZones,
                              paceRecs: _paceRecs,
                              autoAdjust: _autoAdjust,
                              noWatchGuidance: _noWatchGuidance,
                            );
                        context.push(RouteNames.recovery);
                      }
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Icon toggle button (Yes / No with inline icon) ───────────────────────────

class _IconToggleButton extends StatelessWidget {
  const _IconToggleButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 48,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accentMuted : AppColors.backgroundCard,
          borderRadius: AppRadius.borderLg,
          border: Border.all(
            color: isSelected ? AppColors.accentPrimary : AppColors.borderDefault,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              icon,
              width: 18,
              height: 18,
              colorFilter: ColorFilter.mode(
                isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              label,
              style: AppTypography.titleMedium.copyWith(
                color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Full-width select card ───────────────────────────────────────────────────

class _SelectCard extends StatelessWidget {
  const _SelectCard({
    required this.label,
    this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final String? subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base,
          vertical: AppSpacing.base,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accentMuted : AppColors.backgroundCard,
          borderRadius: AppRadius.borderLg,
          border: Border.all(
            color: isSelected ? AppColors.accentPrimary : AppColors.borderDefault,
          ),
        ),
        child: subtitle != null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTypography.titleMedium.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              )
            : Text(
                label,
                style: AppTypography.titleMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}

// ─── Segmented control ────────────────────────────────────────────────────────

class _SegmentedControl extends StatelessWidget {
  const _SegmentedControl({
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  final List<String> options;
  final String? selected;
  final void Function(String) onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: AppRadius.borderLg,
      ),
      child: Row(
        children: options.map((opt) {
          final isSelected = selected == opt;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelect(opt),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 44,
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.accentPrimary : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    opt,
                    style: AppTypography.labelMedium.copyWith(
                      color: isSelected
                          ? AppColors.backgroundPrimary
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Pill chip ────────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: IntrinsicWidth(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.accentPrimary : AppColors.backgroundCard,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: isSelected ? AppColors.accentPrimary : AppColors.borderDefault,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: AppTypography.labelMedium.copyWith(
                color: isSelected
                    ? AppColors.backgroundPrimary
                    : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
