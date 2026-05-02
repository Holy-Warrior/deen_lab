import 'dart:async';
import 'package:flutter/material.dart';

import '../model/prayer_time_model.dart';
import '../model/prayer_method.dart';
import '../model/prayer_time_offsets.dart';
import '../service/prayer_time_service.dart';
import '../service/location_service.dart';
import '../service/cache_service.dart';
import '../service/prayer_automation_service.dart';

enum LocationActionResult {
  success,
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  failed,
}

class PrayerTimeController extends ChangeNotifier {
  final PrayerTimeService _service = PrayerTimeService();
  final LocationService _locationService = LocationService();
  final CacheService _cacheService = CacheService();
  final PrayerAutomationService _automationService = PrayerAutomationService();

  PrayerTimeModel? data;
  bool isLoading = true;
  bool isLocating = false;
  String? error;
  String? locationError;

  String city = "Peshawar";
  String country = "Pakistan";

  PrayerMethod method = PrayerMethod.karachi;
  PrayerTimeOffsets offsets = PrayerTimeOffsets.defaults;

  String nextPrayerName = "";
  String nextPrayerTime = "";
  String remainingTime = "";

  Timer? _timer;
  bool _disposed = false;

  void _safeNotifyListeners() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  Future<void> load() async {
    isLoading = true;
    _safeNotifyListeners();

    final settings = await _cacheService.loadSettings();
    if (_disposed) {
      return;
    }
    city = settings.city ?? city;
    country = settings.country ?? country;
    method = _methodFromApiValue(settings.method) ?? method;
    offsets = settings.offsets;

    await _loadPrayerTimes();
    if (_disposed) {
      return;
    }

    isLoading = false;
    _safeNotifyListeners();
  }

  Future<void> _loadPrayerTimes() async {
    try {
      data = await _service.fetchPrayerTimes(
        city: city,
        country: country,
        method: method.apiValue,
        offsets: offsets,
      );

      await _cacheService.savePrayer(
        data!,
        city: city,
        country: country,
        method: method.apiValue,
        offsets: offsets,
      );
      await _cacheService.saveSettings(
        city: city,
        country: country,
        method: method.apiValue,
        offsets: offsets,
      );

      error = null;
    } catch (e) {
      final cached = await _cacheService.loadPrayer(
        city: city,
        country: country,
        method: method.apiValue,
        offsets: offsets,
      );
      if (_disposed) {
        return;
      }

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
      await _automationService.syncRemindersOnly(prayerTimes: data);
    } catch (_) {
      // Keep prayer-time UX stable even if native automation sync fails.
    }
  }

  Future<LocationActionResult> detectLocation() async {
    try {
      isLocating = true;
      locationError = null;
      _safeNotifyListeners();

      final details = await _locationService.getLocationDetails();
      if (_disposed) {
        return LocationActionResult.failed;
      }

      city = details.city;
      country = details.country;

      await _loadPrayerTimes();
      return LocationActionResult.success;
    } on LocationFailure catch (e) {
      locationError = e.message;
      switch (e.type) {
        case LocationFailureType.serviceDisabled:
          return LocationActionResult.serviceDisabled;
        case LocationFailureType.permissionDenied:
          return LocationActionResult.permissionDenied;
        case LocationFailureType.permissionDeniedForever:
          return LocationActionResult.permissionDeniedForever;
        case LocationFailureType.unknown:
          return LocationActionResult.failed;
      }
    } catch (e) {
      locationError = e.toString();
      return LocationActionResult.failed;
    } finally {
      isLocating = false;
      _safeNotifyListeners();
    }
  }

  Future<bool> openLocationSettings() =>
      _locationService.openLocationSettings();

  Future<bool> openAppSettings() => _locationService.openAppSettings();

  void changeCity(String newCity) {
    city = newCity;
    load();
  }

  void changeMethod(PrayerMethod newMethod) {
    method = newMethod;
    load();
  }

  Future<void> updateOffsets(PrayerTimeOffsets newOffsets) async {
    isLoading = true;
    _safeNotifyListeners();

    offsets = newOffsets;
    await _cacheService.saveSettings(
      city: city,
      country: country,
      method: method.apiValue,
      offsets: offsets,
    );

    await _loadPrayerTimes();
    if (_disposed) {
      return;
    }

    isLoading = false;
    _safeNotifyListeners();
  }

  PrayerMethod? _methodFromApiValue(int? value) {
    if (value == null) {
      return null;
    }

    for (final candidate in PrayerMethod.values) {
      if (candidate.apiValue == value) {
        return candidate;
      }
    }

    return null;
  }

  void _startTimer() {
    _timer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_disposed) return;

      _calculateNextPrayer();
      _safeNotifyListeners();
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
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
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
