import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../model/qibla_direction_model.dart';

class QiblaCacheService {
  static const _directionKey = 'qibla_direction_cache';
  static const _cityKey = 'qibla_city';
  static const _countryKey = 'qibla_country';

  Future<void> save({
    required QiblaDirection direction,
    required String city,
    required String country,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _directionKey,
      jsonEncode({
        'latitude': direction.latitude,
        'longitude': direction.longitude,
        'direction': direction.direction,
      }),
    );
    await prefs.setString(_cityKey, city);
    await prefs.setString(_countryKey, country);
  }

  Future<({QiblaDirection? direction, String? city, String? country})>
  load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_directionKey);
    final city = prefs.getString(_cityKey);
    final country = prefs.getString(_countryKey);

    if (raw == null) {
      return (direction: null, city: city, country: country);
    }

    final json = jsonDecode(raw) as Map<String, dynamic>;
    return (
      direction: QiblaDirection(
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        direction: (json['direction'] as num).toDouble(),
      ),
      city: city,
      country: country,
    );
  }
}
