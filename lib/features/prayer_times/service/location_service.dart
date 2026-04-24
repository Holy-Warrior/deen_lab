import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationDetails {
  const LocationDetails({required this.city, required this.country});

  final String city;
  final String country;
}

class LocationService {
  Future<String> getCity() async {
    final details = await getLocationDetails();
    return details.city;
  }

  Future<LocationDetails> getLocationDetails() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception(
        'Location services are disabled. Please enable GPS/location and try again.',
      );
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw Exception(
        'Location permission was denied. Please allow location access and try again.',
      );
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Location permission is permanently denied. Enable it from app settings.',
      );
    }

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
  }
}
