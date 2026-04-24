import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../model/sehri_iftari_day.dart';

class SehriIftariCacheService {
  static const _cityKey = 'sehri_iftari_city';
  static const _countryKey = 'sehri_iftari_country';
  static const _methodKey = 'sehri_iftari_method';
  static const _todayKey = 'sehri_iftari_today';
  static const _monthKey = 'sehri_iftari_month';
  static const _monthIdentityKey = 'sehri_iftari_month_identity';

  Future<void> saveSettings({
    required String city,
    required String country,
    required int method,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cityKey, city);
    await prefs.setString(_countryKey, country);
    await prefs.setInt(_methodKey, method);
  }

  Future<({String? city, String? country, int? method})> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      city: prefs.getString(_cityKey),
      country: prefs.getString(_countryKey),
      method: prefs.getInt(_methodKey),
    );
  }

  Future<void> saveToday(SehriIftariDay day) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_todayKey, jsonEncode(_encodeDay(day)));
  }

  Future<SehriIftariDay?> loadToday() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_todayKey);
    if (raw == null) {
      return null;
    }

    return _decodeDay(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> saveMonth(
    List<SehriIftariDay> days, {
    required int year,
    required int month,
    required String city,
    required String country,
    required int method,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _monthKey,
      jsonEncode(days.map(_encodeDay).toList(growable: false)),
    );
    await prefs.setString(
      _monthIdentityKey,
      '$year-$month|$city|$country|$method',
    );
  }

  Future<List<SehriIftariDay>?> loadMonth({
    required int year,
    required int month,
    required String city,
    required String country,
    required int method,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final identity = prefs.getString(_monthIdentityKey);
    if (identity != '$year-$month|$city|$country|$method') {
      return null;
    }

    final raw = prefs.getString(_monthKey);
    if (raw == null) {
      return null;
    }

    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((item) => _decodeDay(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  Map<String, dynamic> _encodeDay(SehriIftariDay day) {
    return {
      'gregorianDate': day.gregorianDate.toIso8601String(),
      'gregorianDay': day.gregorianDay,
      'hijriDate': day.hijriDate,
      'hijriMonth': day.hijriMonth,
      'imsak': day.imsak,
      'fajr': day.fajr,
      'maghrib': day.maghrib,
      'timezone': day.timezone,
      'methodName': day.methodName,
    };
  }

  SehriIftariDay _decodeDay(Map<String, dynamic> json) {
    return SehriIftariDay(
      gregorianDate: DateTime.parse(json['gregorianDate'] as String),
      gregorianDay: json['gregorianDay'] as String,
      hijriDate: json['hijriDate'] as String,
      hijriMonth: json['hijriMonth'] as String,
      imsak: json['imsak'] as String,
      fajr: json['fajr'] as String,
      maghrib: json['maghrib'] as String,
      timezone: json['timezone'] as String,
      methodName: json['methodName'] as String,
    );
  }
}
