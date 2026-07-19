import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Outcome of a locate request: a position, or a human-friendly reason it
/// couldn't be obtained (services off, permission denied, ...).
class LocationResult {
  const LocationResult({this.latLng, this.error});

  final LatLng? latLng;
  final String? error;
}

/// Thin wrapper over geolocator that handles the service-enabled + permission
/// dance and returns a [LatLng] the map can use. Never throws — failures come
/// back as a [LocationResult.error] the UI can surface gently.
class LocationService {
  const LocationService();

  Future<LocationResult> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationResult(error: 'Location services are turned off.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return const LocationResult(error: 'Location permission denied.');
      }
      final position = await Geolocator.getCurrentPosition();
      return LocationResult(latLng: LatLng(position.latitude, position.longitude));
    } catch (_) {
      return const LocationResult(error: "Couldn't find your location.");
    }
  }

  /// Prompts for location permission during the onboarding consent step and
  /// reports whether it ended up granted. Never throws — a decline is a normal
  /// outcome the flow handles by continuing on to a sample map.
  Future<bool> requestPermission() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      return permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;
    } catch (_) {
      return false;
    }
  }
}

final locationServiceProvider = Provider<LocationService>((ref) {
  return const LocationService();
});
