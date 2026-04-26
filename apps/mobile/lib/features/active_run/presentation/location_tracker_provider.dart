import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../l10n/app_localizations.dart';
import '../../localization/presentation/locale_provider.dart';
import '../data/run_location_tracker.dart';

final locationTrackerProvider = Provider<RunLocationTracker>((ref) {
  final locale = ref.read(localeProvider).value ?? const Locale('en');
  final normalizedLocale = locale.languageCode == 'es'
      ? const Locale('es')
      : const Locale('en');
  final l10n = lookupAppLocalizations(normalizedLocale);

  final tracker = GeolocatorRunLocationTracker(
    notificationTitle: l10n.activeRunGpsTrackingNotificationTitle,
    notificationBody: l10n.activeRunGpsTrackingNotificationBody,
    positionStreamFactory: (settings) =>
        Geolocator.getPositionStream(locationSettings: settings),
  );
  ref.onDispose(tracker.stop);
  return tracker;
});
