import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:silence_of_salah_engine/silence_of_salah_engine.dart';

import '../model/prayer_time_model.dart';

class PrayerAutomationSettings {
  PrayerAutomationSettings({
    required this.engineEnabled,
    required this.notificationsEnabled,
    required this.prayerEnabled,
  });

  final bool engineEnabled;
  final bool notificationsEnabled;
  final Map<String, bool> prayerEnabled;

  static const List<String> prayerOrder = <String>[
    'fajr',
    'dhuhr',
    'asr',
    'maghrib',
    'isha',
  ];

  factory PrayerAutomationSettings.defaults() {
    return PrayerAutomationSettings(
      engineEnabled: false,
      notificationsEnabled: false,
      prayerEnabled: <String, bool>{
        'fajr': true,
        'dhuhr': true,
        'asr': true,
        'maghrib': true,
        'isha': true,
      },
    );
  }

  PrayerAutomationSettings copyWith({
    bool? engineEnabled,
    bool? notificationsEnabled,
    Map<String, bool>? prayerEnabled,
  }) {
    return PrayerAutomationSettings(
      engineEnabled: engineEnabled ?? this.engineEnabled,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      prayerEnabled: prayerEnabled ?? this.prayerEnabled,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'engineEnabled': engineEnabled,
      'notificationsEnabled': notificationsEnabled,
      'prayerEnabled': prayerEnabled,
    };
  }

  factory PrayerAutomationSettings.fromJson(Map<String, dynamic> json) {
    final rawPrayerEnabled = json['prayerEnabled'];
    final prayerEnabled = <String, bool>{};

    if (rawPrayerEnabled is Map) {
      for (final key in prayerOrder) {
        final value = rawPrayerEnabled[key];
        prayerEnabled[key] = value is bool ? value : true;
      }
    } else {
      for (final key in prayerOrder) {
        prayerEnabled[key] = true;
      }
    }

    return PrayerAutomationSettings(
      engineEnabled: json['engineEnabled'] is bool
          ? json['engineEnabled'] as bool
          : false,
      notificationsEnabled: json['notificationsEnabled'] is bool
          ? json['notificationsEnabled'] as bool
          : false,
      prayerEnabled: prayerEnabled,
    );
  }
}

class PrayerAutomationService {
  static const String _settingsKey = 'prayer_automation_settings_v1';
  static const Duration _prePrayerOffset = Duration(minutes: 3);
  static const MethodChannel _reminderChannel = MethodChannel(
    'deen_lab/prayer_reminders',
  );

  Future<PrayerAutomationSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_settingsKey);
    if (raw == null || raw.isEmpty) {
      return PrayerAutomationSettings.defaults();
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return PrayerAutomationSettings.fromJson(decoded);
      }
      if (decoded is Map) {
        return PrayerAutomationSettings.fromJson(
          decoded.map((key, value) => MapEntry(key.toString(), value)),
        );
      }
    } catch (_) {}

    return PrayerAutomationSettings.defaults();
  }

  Future<void> saveSettings(PrayerAutomationSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, jsonEncode(settings.toJson()));
  }

  Future<void> applyAllFromSettings({
    required PrayerAutomationSettings settings,
    required PrayerTimeModel? prayerTimes,
  }) async {
    await _syncReminders(settings: settings, prayerTimes: prayerTimes);
  }

  Future<void> syncRemindersOnly({
    required PrayerTimeModel? prayerTimes,
  }) async {
    final settings = await loadSettings();
    await _syncReminders(settings: settings, prayerTimes: prayerTimes);
  }

  Future<void> requestAllRelevantPermissions() async {
    await SilenceOfSalahEngine.requestNotificationPermission();
    await SilenceOfSalahEngine.requestExactAlarmPermission();
    await SilenceOfSalahEngine.requestDndAccess();
    await SilenceOfSalahEngine.requestBatteryOptimization();
  }

  Future<Map<Object?, Object?>> getPermissionStatus() async {
    return SilenceOfSalahEngine.getPermissionStatus();
  }

  Future<bool> areAllPermissionsGranted() async {
    final status = await getPermissionStatus();
    return status['allGranted'] == true;
  }

  Future<void> _syncReminders({
    required PrayerAutomationSettings settings,
    required PrayerTimeModel? prayerTimes,
  }) async {
    if (!settings.notificationsEnabled || prayerTimes == null) {
      await _cancelAllReminders();
      return;
    }

    final permissionStatus = await getPermissionStatus();
    if (permissionStatus['notifications'] != true ||
        permissionStatus['exactAlarm'] != true) {
      await _cancelAllReminders();
      return;
    }

    final reminders = await _buildReminderAlarms(
      settings: settings,
      prayerTimes: prayerTimes,
    );

    if (reminders.isEmpty) {
      await _cancelAllReminders();
      return;
    }

    await _reminderChannel.invokeListMethod<Object?>(
      'scheduleDailyReminders',
      reminders,
    );
  }

  Future<void> _cancelAllReminders() async {
    await _reminderChannel.invokeMethod<bool>('cancelAllReminders');
  }

  Future<List<Map<String, Object?>>> _buildReminderAlarms({
    required PrayerAutomationSettings settings,
    required PrayerTimeModel prayerTimes,
  }) async {
    final now = DateTime.now();
    final silenceEngineCanRun =
        settings.engineEnabled && await areAllPermissionsGranted();
    final candidates = <(int id, String key, String label, String time)>[
      (1001, 'fajr', 'Fajr', prayerTimes.fajr),
      (1002, 'dhuhr', 'Dhuhr', prayerTimes.dhuhr),
      (1003, 'asr', 'Asr', prayerTimes.asr),
      (1004, 'maghrib', 'Maghrib', prayerTimes.maghrib),
      (1005, 'isha', 'Isha', prayerTimes.isha),
    ];

    return candidates
        .where((it) {
          return settings.prayerEnabled[it.$2] ?? false;
        })
        .map((it) {
          final prayerTime = _parseTodayTime(now, it.$4);
          final reminderTime = prayerTime.subtract(_prePrayerOffset);
          return <String, Object?>{
            'id': it.$1,
            'hour': reminderTime.hour,
            'minute': reminderTime.minute,
            'label': '${it.$3} reminder (-3m)',
            'silenceEngineEnabled': silenceEngineCanRun,
          };
        })
        .toList();
  }

  DateTime _parseTodayTime(DateTime now, String time) {
    final clean = time.split(' ').first;
    final parts = clean.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    return DateTime(now.year, now.month, now.day, hour, minute);
  }
}
