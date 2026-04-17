import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'l10n/app_localizations.dart';

import 'core/config/supabase_config.dart';
import 'core/persistence/shared_preferences_provider.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/active_run/presentation/run_live_activity_background_service.dart';
import 'features/localization/presentation/locale_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting();
  await RunLiveActivityBackgroundService.instance.configure();
  await _initializeSupabaseIfConfigured();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const RunningApp(),
    ),
  );
}

Future<void> _initializeSupabaseIfConfigured() async {
  final url = SupabaseConfig.url;
  final anonKey = SupabaseConfig.anonKey;

  if (url.isEmpty || anonKey.isEmpty) {
    debugPrint(
      'Supabase initialization skipped: missing SUPABASE_URL or '
      'SUPABASE_ANON_KEY dart-define values.',
    );
    return;
  }

  await Supabase.initialize(url: url, anonKey: anonKey);
}

class RunningApp extends ConsumerWidget {
  const RunningApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the locale — rebuilds MaterialApp when the locale changes
    final localeAsync = ref.watch(localeProvider);

    // While locale is loading from disk, use English as a fallback
    // This prevents a flash of the wrong language on startup
    final locale = localeAsync.value ?? const Locale('en');

    return MaterialApp.router(
      title: 'StrivIQ',
      theme: AppTheme.dark,
      debugShowCheckedModeBanner: false,
      routerConfig: ref.watch(appRouterProvider),

      // Localization setup
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('es')],
    );
  }
}
