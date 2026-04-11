import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/config/supabase_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_segmented_control.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/auth_state_provider.dart';
import '../../../user_preferences/domain/user_preferences.dart';
import '../../../user_preferences/presentation/user_preferences_provider.dart';

class AccountSetupScreen extends ConsumerStatefulWidget {
  const AccountSetupScreen({super.key});

  @override
  ConsumerState<AccountSetupScreen> createState() => _AccountSetupScreenState();
}

class _AccountSetupScreenState extends ConsumerState<AccountSetupScreen> {
  int _unitIndex = 0; // 0 = km, 1 = mi
  int _shortDistanceIndex = 0; // 0 = m, 1 = ft
  int _genderIndex = 0; // 0 = Male, 1 = Female, 2 = Other
  DateTime? _dateOfBirth;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Load previously saved preferences and pre-fill the form after the first
    // frame — we use a post-frame callback because ref.read inside initState
    // can run before the provider has resolved its async build().
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final prefs = await ref.read(userPreferencesProvider.future);
      if (!mounted) return;
      setState(() {
        _unitIndex = prefs.unitSystem == UnitSystem.miles ? 1 : 0;
        _shortDistanceIndex = prefs.shortDistanceUnit == ShortDistanceUnit.feet
            ? 1
            : 0;
        _genderIndex = switch (prefs.gender) {
          ProfileGender.female => 1,
          ProfileGender.other => 2,
          _ => 0,
        };
        _dateOfBirth = prefs.dateOfBirth;
      });
    });
  }

  String get _dateOfBirthDisplay {
    if (_dateOfBirth == null) return '';
    return MaterialLocalizations.of(context).formatShortDate(_dateOfBirth!);
  }

  Future<void> _pickDateOfBirth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(1990, 1, 1),
      firstDate: DateTime(1920),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 13)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.accentPrimary,
              onPrimary: AppColors.backgroundPrimary,
              surface: AppColors.backgroundSecondary,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _dateOfBirth = picked);
    }
  }

  Future<void> _onContinue(AppLocalizations l10n) async {
    if (_isSaving) return;

    setState(() => _isSaving = true);
    try {
      await ref
          .read(userPreferencesProvider.notifier)
          .saveAccountSetup(
            unitSystem: _unitIndex == 0 ? UnitSystem.km : UnitSystem.miles,
            shortDistanceUnit: _shortDistanceIndex == 0
                ? ShortDistanceUnit.meters
                : ShortDistanceUnit.feet,
            gender: [
              ProfileGender.male,
              ProfileGender.female,
              ProfileGender.other,
            ][_genderIndex],
            dateOfBirth: _dateOfBirth,
            displayName: _authDisplayName,
          );
      if (mounted) context.go(RouteNames.onboarding);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.errorGeneric)));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String? get _authDisplayName {
    if (!SupabaseConfig.isConfigured) return null;
    final metadata = ref.read(currentUserProvider)?.userMetadata;
    for (final key in const ['full_name', 'name', 'display_name']) {
      final value = metadata?[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
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
            _BackButton(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screen,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      l10n.accountSetupTitle,
                      style: AppTypography.headlineMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      l10n.accountSetupSubtitle,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxxl),
                    // Preferred Units
                    Text(l10n.preferredUnits, style: AppTypography.labelLarge),
                    const SizedBox(height: AppSpacing.md),
                    AppSegmentedControl(
                      options: [l10n.unitKm, l10n.unitMi],
                      selectedIndex: _unitIndex,
                      onChanged: (i) => setState(() {
                        _unitIndex = i;
                        _shortDistanceIndex = i == 0 ? 0 : 1;
                      }),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    Text(
                      l10n.accountSetupShortDistanceUnits,
                      style: AppTypography.labelLarge,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppSegmentedControl(
                      options: [l10n.unitM, l10n.unitFt],
                      selectedIndex: _shortDistanceIndex,
                      onChanged: (i) => setState(() => _shortDistanceIndex = i),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    // Gender
                    Text(l10n.genderLabel, style: AppTypography.labelLarge),
                    const SizedBox(height: AppSpacing.md),
                    AppSegmentedControl(
                      options: [
                        l10n.genderMale,
                        l10n.genderFemale,
                        l10n.genderOther,
                      ],
                      selectedIndex: _genderIndex,
                      onChanged: (i) => setState(() => _genderIndex = i),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    // Date of Birth
                    AppPickerField(
                      label: l10n.dateOfBirthLabel,
                      hint: l10n.dateOfBirthHint,
                      value: _dateOfBirth != null ? _dateOfBirthDisplay : null,
                      onTap: _pickDateOfBirth,
                      suffixIcon: const Icon(
                        Icons.calendar_today_outlined,
                        color: AppColors.textSecondary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxxl),
                  ],
                ),
              ),
            ),
            // Bottom button
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen,
                AppSpacing.base,
                AppSpacing.screen,
                AppSpacing.xl,
              ),
              child: AppButton(
                label: l10n.continueButton,
                isLoading: _isSaving,
                onPressed: _isSaving ? null : () => _onContinue(l10n),
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
