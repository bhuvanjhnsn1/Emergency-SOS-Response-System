import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Service for acquiring GPS coordinates
class LocationService {
  /// Get current position with high accuracy.
  /// Returns a [Position] object with lat/long or throws.
  static Future<Position> getCurrentLocation() async {
    // Check if location services are enabled
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw LocationServiceException('Location services are disabled.');
    }

    // Check permission
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw LocationServiceException('Location permission denied.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw LocationServiceException(
        'Location permissions are permanently denied. '
        'Please enable them in Settings.',
      );
    }

    // Acquire position
    debugPrint('Acquiring GPS position...');
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );

    debugPrint('GPS Lock: ${position.latitude}, ${position.longitude}');
    return position;
  }

  /// Build a Google Maps URL from coordinates
  static String buildMapsUrl(double latitude, double longitude) {
    return 'https://maps.google.com/?q=$latitude,$longitude';
  }
}

/// Custom exception for location errors
class LocationServiceException implements Exception {
  final String message;
  const LocationServiceException(this.message);

  @override
  String toString() => message;
}
