import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/logging/app_logger.dart';

class LocationResult {
  final double latitude;
  final double longitude;
  final String? locationName;

  LocationResult({
    required this.latitude,
    required this.longitude,
    this.locationName,
  });
}

class LocationService {
  Future<LocationResult?> getCurrentLocation() async {
    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }

      if (permission == LocationPermission.deniedForever) return null;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 5),
        ),
      );

      String? locName;
      try {
        final placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          locName = [p.subLocality, p.locality, p.administrativeArea]
              .where((s) => s != null && s.trim().isNotEmpty)
              .join(', ');
        }
      } catch (_) {}

      return LocationResult(
        latitude: position.latitude,
        longitude: position.longitude,
        locationName: locName,
      );
    } catch (e) {
      await AppLogger.w('Location capture skipped: $e');
      return null;
    }
  }
}
