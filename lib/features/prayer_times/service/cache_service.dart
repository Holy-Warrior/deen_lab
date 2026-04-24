import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../model/prayer_time_model.dart';

class CacheService {
  static const _dataKey = "prayer_times_cache";
  static const _cityKey = "selected_city";

  Future<void> savePrayer(PrayerTimeModel model) async {
    final prefs = await SharedPreferences.getInstance();

    final json = jsonEncode({
      "fajr": model.fajr,
      "dhuhr": model.dhuhr,
      "asr": model.asr,
      "maghrib": model.maghrib,
      "isha": model.isha,
      "sunrise": model.sunrise,
    });

    await prefs.setString(_dataKey, json);
  }

  Future<PrayerTimeModel?> loadPrayer() async {
    final prefs = await SharedPreferences.getInstance();
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

  Future<void> saveCity(String city) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cityKey, city);
  }

  Future<String?> loadCity() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_cityKey);
  }
}
