// lib/services/location_service.dart

import 'package:geolocator/geolocator.dart';

/// A service dedicated to handling all location-related logic,
/// such as permissions and position streaming. This abstracts the implementation
/// details of the 'geolocator' package from the rest of the app.
class LocationService {
  /// Checks and requests location permissions.
  ///
  /// Returns `true` if permissions are granted, `false` otherwise.
  Future<bool> handlePermission() async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    // If permission is still denied or permanently denied, we cannot proceed.
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return false;
    }

    // Permissions are granted (either while in use or always).
    return true;
  }

  /// Provides a stream of position updates.
  ///
  /// The stream is configured for high accuracy and updates after a minimum
  /// distance change of 1 meter.
  Stream<Position> getPositionStream() {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 1, // Update when the user moves 1 meter
    );
    return Geolocator.getPositionStream(locationSettings: locationSettings);
  }
}