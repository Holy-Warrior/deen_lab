import 'dart:async';

import 'package:flutter/material.dart';

import '../../prayer_times/model/prayer_method.dart';
import '../../prayer_times/service/location_service.dart';
import '../model/sehri_iftari_day.dart';
import '../service/sehri_iftari_cache_service.dart';
import '../service/sehri_iftari_service.dart';

enum SehriLocationActionResult {
  success,
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  failed,
}

class SehriIftariController extends ChangeNotifier {
  final SehriIftariService _service = SehriIftariService();
  final SehriIftariCacheService _cacheService = SehriIftariCacheService();
  final LocationService _locationService = LocationService();

  SehriIftariDay? today;
  List<SehriIftariDay> monthDays = [];

  bool isLoading = true;
  bool isRefreshingMonth = false;
  bool isLocating = false;
  String? error;
  String? locationError;

  String city = 'Karachi';
  String country = 'Pakistan';
  PrayerMethod method = PrayerMethod.karachi;
  DateTime visibleMonth = DateTime(DateTime.now().year, DateTime.now().month);

  String nextEventLabel = '';
  String nextEventTime = '';
  String remainingTime = '';

  Timer? _timer;
  bool _disposed = false;

  void _safeNotifyListeners() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  Future<void> load() async {
    isLoading = true;
    error = null;
    _safeNotifyListeners();

    final settings = await _cacheService.loadSettings();
    city = settings.city ?? city;
    country = settings.country ?? country;
    method = _methodFromApiValue(settings.method) ?? method;

    await _loadCurrentDay();
    await _loadMonth(visibleMonth);

    isLoading = false;
    _safeNotifyListeners();
  }

  Future<void> refresh() async {
    error = null;
    await _loadCurrentDay(forceRemote: true);
    await _loadMonth(visibleMonth, forceRemote: true);
    _safeNotifyListeners();
  }

  Future<void> updateSettings({
    required String city,
    required String country,
    required PrayerMethod method,
  }) async {
    this.city = city.trim().isEmpty ? this.city : city.trim();
    this.country = country.trim().isEmpty ? this.country : country.trim();
    this.method = method;

    _safeNotifyListeners();
    await refresh();
  }

  Future<void> changeMonth(int delta) async {
    final nextMonth = DateTime(visibleMonth.year, visibleMonth.month + delta);
    visibleMonth = DateTime(nextMonth.year, nextMonth.month);
    isRefreshingMonth = true;
    _safeNotifyListeners();

    await _loadMonth(visibleMonth);

    isRefreshingMonth = false;
    _safeNotifyListeners();
  }

  Future<SehriLocationActionResult> detectLocation() async {
    try {
      isLocating = true;
      locationError = null;
      _safeNotifyListeners();

      final details = await _locationService.getLocationDetails();
      if (_disposed) {
        return SehriLocationActionResult.failed;
      }
      city = details.city;
      country = details.country;

      await refresh();
      return SehriLocationActionResult.success;
    } on LocationFailure catch (e) {
      if (_disposed) {
        return SehriLocationActionResult.failed;
      }
      locationError = e.message;
      switch (e.type) {
        case LocationFailureType.serviceDisabled:
          return SehriLocationActionResult.serviceDisabled;
        case LocationFailureType.permissionDenied:
          return SehriLocationActionResult.permissionDenied;
        case LocationFailureType.permissionDeniedForever:
          return SehriLocationActionResult.permissionDeniedForever;
        case LocationFailureType.unknown:
          return SehriLocationActionResult.failed;
      }
    } catch (e) {
      if (_disposed) {
        return SehriLocationActionResult.failed;
      }
      locationError = e.toString();
      return SehriLocationActionResult.failed;
    } finally {
      if (!_disposed) {
        isLocating = false;
        _safeNotifyListeners();
      }
    }
  }

  Future<bool> openLocationSettings() =>
      _locationService.openLocationSettings();

  Future<bool> openAppSettings() => _locationService.openAppSettings();

  Future<void> _loadCurrentDay({bool forceRemote = false}) async {
    try {
      final day = await _service.fetchToday(
        city: city,
        country: country,
        method: method.apiValue,
      );
      today = day;
      await _cacheService.saveToday(day);
      await _cacheService.saveSettings(
        city: city,
        country: country,
        method: method.apiValue,
      );
      error = null;
    } catch (e) {
      if (!forceRemote) {
        final cached = await _cacheService.loadToday();
        if (cached != null) {
          today = cached;
          error = 'Offline mode';
        } else {
          error = e.toString();
        }
      } else {
        error = e.toString();
      }
    }

    _calculateNextEvent();
    _startTimer();
  }

  Future<void> _loadMonth(DateTime month, {bool forceRemote = false}) async {
    try {
      final days = await _service.fetchMonth(
        city: city,
        country: country,
        method: method.apiValue,
        year: month.year,
        month: month.month,
      );

      monthDays = days;
      await _cacheService.saveMonth(
        days,
        year: month.year,
        month: month.month,
        city: city,
        country: country,
        method: method.apiValue,
      );
    } catch (e) {
      if (!forceRemote) {
        final cached = await _cacheService.loadMonth(
          year: month.year,
          month: month.month,
          city: city,
          country: country,
          method: method.apiValue,
        );
        if (cached != null) {
          monthDays = cached;
          error ??= 'Offline mode';
          return;
        }
      }

      error ??= e.toString();
    }
  }

  void _startTimer() {
    if (_disposed) {
      return;
    }

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_disposed) {
        return;
      }

      _calculateNextEvent();
      _safeNotifyListeners();
    });
  }

  void _calculateNextEvent() {
    final currentDay = today;
    if (currentDay == null) {
      nextEventLabel = '';
      nextEventTime = '';
      remainingTime = '';
      return;
    }

    final now = DateTime.now();
    final todaySehri = _parseClockTime(
      currentDay.imsak,
      currentDay.gregorianDate,
    );
    final todayIftar = _parseClockTime(
      currentDay.maghrib,
      currentDay.gregorianDate,
    );

    if (now.isBefore(todaySehri)) {
      nextEventLabel = 'Sehri Ends';
      nextEventTime = _formatTime(todaySehri);
      remainingTime = _formatDuration(todaySehri.difference(now));
      return;
    }

    if (now.isBefore(todayIftar)) {
      nextEventLabel = 'Iftar';
      nextEventTime = _formatTime(todayIftar);
      remainingTime = _formatDuration(todayIftar.difference(now));
      return;
    }

    final tomorrowDate = currentDay.gregorianDate.add(const Duration(days: 1));
    final tomorrowData = monthDays.cast<SehriIftariDay?>().firstWhere(
      (day) =>
          day != null &&
          day.gregorianDate.year == tomorrowDate.year &&
          day.gregorianDate.month == tomorrowDate.month &&
          day.gregorianDate.day == tomorrowDate.day,
      orElse: () => null,
    );

    final nextSehri = _parseClockTime(
      tomorrowData?.imsak ?? currentDay.imsak,
      tomorrowDate,
    );

    nextEventLabel = 'Next Sehri';
    nextEventTime = _formatTime(nextSehri);
    remainingTime = _formatDuration(nextSehri.difference(now));
  }

  DateTime _parseClockTime(String time, DateTime date) {
    final clean = time.split(' ').first;
    final parts = clean.split(':');

    return DateTime(
      date.year,
      date.month,
      date.day,
      int.tryParse(parts.first) ?? 0,
      int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
    );
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final minute = dt.minute.toString().padLeft(2, '0');

    return '$hour:$minute $period';
  }

  String _formatDuration(Duration duration) {
    final h = duration.inHours.toString().padLeft(2, '0');
    final m = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final s = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
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

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
