import 'dart:async';
import 'package:flutter/material.dart';

import '../model/prayer_time_model.dart';
import '../model/prayer_method.dart';
import '../service/prayer_time_service.dart';
import '../service/location_service.dart';
import '../service/cache_service.dart';
import '../service/prayer_automation_service.dart';

class PrayerTimeController extends ChangeNotifier {
  final PrayerTimeService _service = PrayerTimeService();
  final LocationService _locationService = LocationService();
  final CacheService _cacheService = CacheService();
  final PrayerAutomationService _automationService = PrayerAutomationService();

  PrayerTimeModel? data;
  bool isLoading = true;
  bool isLocating = false;
  String? error;

  String city = "Peshawar";

  PrayerMethod method = PrayerMethod.karachi;

  String nextPrayerName = "";
  String nextPrayerTime = "";
  String remainingTime = "";

  Timer? _timer;
  bool _disposed = false;

  Future<void> load() async {
    isLoading = true;
    notifyListeners();

    // Load saved city first
    final savedCity = await _cacheService.loadCity();
    if (savedCity != null) {
      city = savedCity;
    }

    await _loadPrayerTimes();

    isLoading = false;
    notifyListeners();
  }

  Future<void> _loadPrayerTimes() async {
    try {
      data = await _service.fetchPrayerTimes(
        city: city,
        method: method.apiValue,
      );

      await _cacheService.savePrayer(data!);
      await _cacheService.saveCity(city);

      error = null;
    } catch (e) {
      final cached = await _cacheService.loadPrayer();

      if (cached != null) {
        data = cached;
        error = "Offline mode";
      } else {
        error = e.toString();
      }
    }

    if (data != null) {
      _calculateNextPrayer();
      _startTimer();
      await syncPrayerAutomation();
    }
  }

  Future<void> syncPrayerAutomation() async {
    try {
      await _automationService.syncAlarmsOnly(prayerTimes: data);
    } catch (_) {
      // Keep prayer-time UX stable even if native automation sync fails.
    }
  }

  Future<void> detectLocation() async {
    try {
      isLocating = true;
      notifyListeners();

      final detectedCity = await _locationService.getCity();

      city = detectedCity;

      await _loadPrayerTimes();
    } catch (e) {
      error = e.toString();
    }

    isLocating = false;
    notifyListeners();
  }

  void changeCity(String newCity) {
    city = newCity;
    load();
  }

  void changeMethod(PrayerMethod newMethod) {
    method = newMethod;
    load();
  }

  void _startTimer() {
    _timer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_disposed) return;

      _calculateNextPrayer();
      notifyListeners();
    });
  }

  DateTime _parseTime(String time) {
    final clean = time.split(" ").first;
    final parts = clean.split(":");

    final now = DateTime.now();

    return DateTime(
      now.year,
      now.month,
      now.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }

  void _calculateNextPrayer() {
    if (data == null) return;

    final now = DateTime.now();

    final prayers = [
      ("Fajr", _parseTime(data!.fajr)),
      ("Dhuhr", _parseTime(data!.dhuhr)),
      ("Asr", _parseTime(data!.asr)),
      ("Maghrib", _parseTime(data!.maghrib)),
      ("Isha", _parseTime(data!.isha)),
    ];

    for (var p in prayers) {
      if (now.isBefore(p.$2)) {
        nextPrayerName = p.$1;
        nextPrayerTime = _formatTime(p.$2);
        remainingTime = _formatDuration(p.$2.difference(now));
        return;
      }
    }

    final fajrTomorrow = _parseTime(data!.fajr).add(const Duration(days: 1));

    nextPrayerName = "Fajr";
    nextPrayerTime = _formatTime(fajrTomorrow);
    remainingTime = _formatDuration(fajrTomorrow.difference(now));
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : dt.hour;
    final period = dt.hour >= 12 ? "PM" : "AM";
    final minute = dt.minute.toString().padLeft(2, '0');

    return "$hour:$minute $period";
  }

  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');

    return "$h:$m:$s";
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
