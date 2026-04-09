import 'device_connection.dart';

class IntegrationAccount {
  const IntegrationAccount({
    required this.vendor,
    required this.kind,
    this.supportedCapabilities = const {},
  });

  final IntegrationVendor vendor;
  final DeviceConnectionKind kind;
  final Set<IntegrationCapability> supportedCapabilities;

  bool supports(IntegrationCapability capability) =>
      supportedCapabilities.contains(capability);
}
