import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

enum LocationFailureType {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  unknown,
}

class LocationFailure implements Exception {
  const LocationFailure(this.type, this.message);

  final LocationFailureType type;
  final String message;

  @override
  String toString() => message;
}

class LocationDetails {
  const LocationDetails({required this.city, required this.country});

  final String city;
  final String country;
}

class LocationService {
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  Future<String> getCity() async {
    final details = await getLocationDetails();
    return details.city;
  }

  Future<LocationDetails> getLocationDetails() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationFailure(
        LocationFailureType.serviceDisabled,
        'Location services are disabled. Please enable GPS/location and try again.',
      );
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw const LocationFailure(
        LocationFailureType.permissionDenied,
        'Location permission was denied. Please allow location access and try again.',
      );
    }

    if (permission == LocationPermission.deniedForever) {
      throw const LocationFailure(
        LocationFailureType.permissionDeniedForever,
        'Location permission is permanently denied. Enable it from app settings.',
      );
    }

    try {
      final position = await Geolocator.getCurrentPosition();

      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      final place = placemarks.first;

      final city =
          place.locality ??
          place.subAdministrativeArea ??
          place.administrativeArea ??
          'Unknown';
      final country = place.country ?? 'Pakistan';

      return LocationDetails(city: city, country: country);
    } catch (_) {
      throw const LocationFailure(
        LocationFailureType.unknown,
        'Unable to detect location right now. Please try again.',
      );
    }
  }
}
