import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart'
    as permission_handler;

abstract class LocationPermissionService {
  Future<bool> isLocationServiceEnabled();

  Future<LocationPermission> checkPermission();

  Future<LocationPermission> requestPermission();

  Future<bool> openLocationSettings();

  Future<bool> openAppSettings();
}

class GeolocatorLocationPermissionService implements LocationPermissionService {
  const GeolocatorLocationPermissionService();

  @override
  Future<bool> isLocationServiceEnabled() {
    return Geolocator.isLocationServiceEnabled();
  }

  @override
  Future<LocationPermission> checkPermission() {
    return Geolocator.checkPermission();
  }

  @override
  Future<LocationPermission> requestPermission() {
    return Geolocator.requestPermission();
  }

  @override
  Future<bool> openLocationSettings() {
    return Geolocator.openLocationSettings();
  }

  @override
  Future<bool> openAppSettings() {
    return permission_handler.openAppSettings();
  }
}

final locationPermissionServiceProvider = Provider<LocationPermissionService>(
  (ref) => const GeolocatorLocationPermissionService(),
);
