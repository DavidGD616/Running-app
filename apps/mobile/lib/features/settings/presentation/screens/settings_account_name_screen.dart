import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_header_bar.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../user_preferences/presentation/user_preferences_provider.dart';

class SettingsAccountNameScreen extends ConsumerStatefulWidget {
  const SettingsAccountNameScreen({super.key});

  @override
  ConsumerState<SettingsAccountNameScreen> createState() =>
      _SettingsAccountNameScreenState();
}

class _SettingsAccountNameScreenState
    extends ConsumerState<SettingsAccountNameScreen> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final currentName =
        ref.read(userPreferencesProvider).value?.displayName?.trim() ?? '';
    _controller = TextEditingController(text: currentName);
    _controller.addListener(_handleTextChanged);
  }

  bool get _canSave => _controller.text.trim().isNotEmpty;

  void _handleTextChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_handleTextChanged)
      ..dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await ref
        .read(userPreferencesProvider.notifier)
        .setDisplayName(_controller.text.trim());
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppDetailHeaderBar(title: l10n.settingsAccountNameLabel),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screen,
                  AppSpacing.lg,
                  AppSpacing.screen,
                  AppSpacing.xl,
                ),
                child: AppTextField(
                  label: l10n.settingsAccountNameLabel,
                  hint: l10n.profileDefaultName,
                  controller: _controller,
                  textInputAction: TextInputAction.done,
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
              child: AppButton(
                label: l10n.saveChangesButton,
                onPressed: _canSave ? _save : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
