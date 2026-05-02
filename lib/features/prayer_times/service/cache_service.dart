import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../model/prayer_time_offsets.dart';
import '../model/prayer_time_model.dart';

class CacheService {
  static const _dataKey = "prayer_times_cache";
  static const _cityKey = "selected_city";
  static const _countryKey = "selected_country";
  static const _methodKey = "selected_prayer_method";
  static const _offsetsKey = "prayer_time_offsets";
  static const _identityKey = "prayer_times_cache_identity";

  Future<void> savePrayer(
    PrayerTimeModel model, {
    required String city,
    required String country,
    required int method,
    required PrayerTimeOffsets offsets,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    final json = jsonEncode({
      "fajr": model.fajr,
      "dhuhr": model.dhuhr,
      "asr": model.asr,
      "maghrib": model.maghrib,
      "isha": model.isha,
      "sunrise": model.sunrise,
    });

    await prefs.setString(_dataKey, json);
    await prefs.setString(
      _identityKey,
      "${now.year}-${now.month}-${now.day}|$city|$country|$method|${offsets.tuneValue}",
    );
  }

  Future<PrayerTimeModel?> loadPrayer({
    required String city,
    required String country,
    required int method,
    required PrayerTimeOffsets offsets,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final identity = prefs.getString(_identityKey);
    final expectedIdentity =
        "${now.year}-${now.month}-${now.day}|$city|$country|$method|${offsets.tuneValue}";

    if (identity != expectedIdentity) {
      return null;
    }

    final jsonString = prefs.getString(_dataKey);

    if (jsonString == null) return null;

    final json = jsonDecode(jsonString);

    return PrayerTimeModel(
      fajr: json["fajr"],
      dhuhr: json["dhuhr"],
      asr: json["asr"],
      maghrib: json["maghrib"],
      isha: json["isha"],
      sunrise: json["sunrise"],
    );
  }

  Future<void> saveSettings({
    required String city,
    required String country,
    required int method,
    required PrayerTimeOffsets offsets,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cityKey, city);
    await prefs.setString(_countryKey, country);
    await prefs.setInt(_methodKey, method);
    await prefs.setString(_offsetsKey, jsonEncode(offsets.toJson()));
  }

  Future<
    ({String? city, String? country, int? method, PrayerTimeOffsets offsets})
  >
  loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final rawOffsets = prefs.getString(_offsetsKey);
    final offsets = rawOffsets == null
        ? PrayerTimeOffsets.defaults
        : PrayerTimeOffsets.fromJson(
            jsonDecode(rawOffsets) as Map<String, dynamic>,
          );

    return (
      city: prefs.getString(_cityKey),
      country: prefs.getString(_countryKey),
      method: prefs.getInt(_methodKey),
      offsets: offsets,
    );
  }
}
