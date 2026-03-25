import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kLocaleKey = 'pref_locale';

class LocaleNotifier extends AsyncNotifier<Locale> {
  @override
  Future<Locale> build() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kLocaleKey);

    // If the user has previously set a language, use that
    if (saved != null) {
      return Locale(saved);
    }

    // First launch: detect device locale
    // PlatformDispatcher gives us the device's preferred locale
    final deviceLocale = PlatformDispatcher.instance.locale;
    if (deviceLocale.languageCode == 'es') {
      return const Locale('es');
    }

    // Default to English for all other languages
    return const Locale('en');
  }

  /// Call this when the user picks a language from the UI
  Future<void> setLocale(Locale locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLocaleKey, locale.languageCode);
    state = AsyncValue.data(locale);
  }
}

// HOW TO USE FROM THE SETTINGS SCREEN:
//
// 1. Make your settings widget a ConsumerWidget (or ConsumerStatefulWidget)
// 2. Read the current locale:
//    final locale = ref.watch(localeProvider).valueOrNull;
//    final isSpanish = locale?.languageCode == 'es';
//
// 3. When the user picks a language:
//    ref.read(localeProvider.notifier).setLocale(const Locale('en'));
//    ref.read(localeProvider.notifier).setLocale(const Locale('es'));
//
// That's all — the locale persists automatically.

final localeProvider = AsyncNotifierProvider<LocaleNotifier, Locale>(
  LocaleNotifier.new,
);
