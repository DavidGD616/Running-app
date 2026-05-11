import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/health_client.dart';
import '../data/health_export_service.dart';

final healthClientProvider = Provider<HealthClient>(
  (ref) => PackageHealthClient(),
);

final healthExportServiceProvider = Provider<HealthExportService>(
  (ref) => HealthExportService(
    client: ref.watch(healthClientProvider),
  ),
);
