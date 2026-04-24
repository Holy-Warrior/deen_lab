import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';

import '../../prayer_times/service/location_service.dart';
import '../model/qibla_direction_model.dart';
import '../service/qibla_cache_service.dart';
import '../service/qibla_service.dart';

class QiblaController extends ChangeNotifier {
  final QiblaService _service = QiblaService();
  final QiblaCacheService _cacheService = QiblaCacheService();
  final LocationService _locationService = LocationService();

  QiblaDirection? direction;
  bool isLoading = true;
  bool isRefreshing = false;
  String? error;

  String city = 'Unknown';
  String country = 'Unknown';
  bool _disposed = false;
  StreamSubscription<CompassEvent>? _compassSubscription;
  bool hasCompassSensor = true;
  double? deviceHeading;

  void _safeNotifyListeners() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  Future<void> load() async {
    isLoading = true;
    error = null;
    _safeNotifyListeners();
    _startCompassUpdates();

    final cached = await _cacheService.load();
    if (_disposed) {
      return;
    }

    if (cached.direction != null) {
      direction = cached.direction;
      city = cached.city ?? city;
      country = cached.country ?? country;
    }

    await refresh(showLoader: false);
    if (_disposed) {
      return;
    }

    isLoading = false;
    _safeNotifyListeners();
  }

  Future<void> refresh({bool showLoader = true}) async {
    try {
      if (showLoader) {
        isRefreshing = true;
        _safeNotifyListeners();
      }

      final position = await Geolocator.getCurrentPosition();
      final details = await _locationService.getLocationDetails();
      final result = await _service.fetchDirection(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      if (_disposed) {
        return;
      }

      direction = result;
      city = details.city;
      country = details.country;
      error = null;

      await _cacheService.save(direction: result, city: city, country: country);
    } catch (e) {
      if (_disposed) {
        return;
      }
      error = direction == null ? e.toString() : 'Offline mode';
    } finally {
      if (!_disposed) {
        isRefreshing = false;
        _safeNotifyListeners();
      }
    }
  }

  String get directionLabel {
    final degrees = direction?.direction;
    if (degrees == null) {
      return '';
    }

    const labels = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final index = (((degrees % 360) / 45).round()) % labels.length;
    return labels[index];
  }

  @override
  void dispose() {
    _disposed = true;
    _compassSubscription?.cancel();
    super.dispose();
  }

  void _startCompassUpdates() {
    _compassSubscription?.cancel();

    final stream = FlutterCompass.events;
    if (stream == null) {
      hasCompassSensor = false;
      deviceHeading = null;
      _safeNotifyListeners();
      return;
    }

    _compassSubscription = stream.listen(
      (event) {
        if (_disposed) {
          return;
        }

        final heading = event.heading;
        if (heading == null) {
          if (deviceHeading == null && hasCompassSensor) {
            hasCompassSensor = false;
            _safeNotifyListeners();
          }
          return;
        }

        deviceHeading = heading;
        if (!hasCompassSensor) {
          hasCompassSensor = true;
        }
        _safeNotifyListeners();
      },
      onError: (_) {
        if (_disposed) {
          return;
        }
        hasCompassSensor = false;
        deviceHeading = null;
        _safeNotifyListeners();
      },
    );
  }
}
