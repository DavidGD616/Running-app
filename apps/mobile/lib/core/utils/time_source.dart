import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract class TimeSource {
  DateTime now();
}

class RealTimeSource implements TimeSource {
  const RealTimeSource();

  @override
  DateTime now() => DateTime.now();
}

final timeSourceProvider = Provider<TimeSource>((ref) {
  return const RealTimeSource();
});
