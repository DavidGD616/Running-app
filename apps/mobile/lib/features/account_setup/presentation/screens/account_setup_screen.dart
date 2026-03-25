import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_segmented_control.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../user_preferences/domain/user_preferences.dart';
import '../../../user_preferences/presentation/user_preferences_provider.dart';

class AccountSetupScreen extends ConsumerStatefulWidget {
  const AccountSetupScreen({super.key});

  @override
  ConsumerState<AccountSetupScreen> createState() => _AccountSetupScreenState();
}

class _AccountSetupScreenState extends ConsumerState<AccountSetupScreen> {
  int _unitIndex = 0; // 0 = km, 1 = mi
  int _genderIndex = 0; // 0 = Male, 1 = Female, 2 = Other
  DateTime? _dateOfBirth;

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
        final genderIdx = [
          'Male',
          'Female',
          'Other',
        ].indexOf(prefs.gender ?? '');
        _genderIndex = genderIdx == -1 ? 0 : genderIdx;
        _dateOfBirth = prefs.dateOfBirth;
      });
    });
  }

  String get _dateOfBirthDisplay {
    if (_dateOfBirth == null) return '';
    final d = _dateOfBirth!;
    return '${d.day.toString().padLeft(2, '0')} / ${d.month.toString().padLeft(2, '0')} / ${d.year}';
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

  void _onContinue() {
    final notifier = ref.read(userPreferencesProvider.notifier);
    // Fire-and-forget: Riverpod state updates immediately (optimistic), the
    // disk write happens asynchronously in the background.
    notifier.setUnitSystem(_unitIndex == 0 ? UnitSystem.km : UnitSystem.miles);
    notifier.setGender(
      [
        AppLocalizations.of(context)!.genderMale,
        AppLocalizations.of(context)!.genderFemale,
        AppLocalizations.of(context)!.genderOther,
      ][_genderIndex],
    );
    if (_dateOfBirth != null) notifier.setDateOfBirth(_dateOfBirth!);
    context.go(RouteNames.onboarding);
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
                      onChanged: (i) => setState(() => _unitIndex = i),
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
                onPressed: _onContinue,
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
