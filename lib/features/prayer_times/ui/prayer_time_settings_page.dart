import 'package:flutter/material.dart';
import 'package:silence_of_salah_engine/silence_of_salah_engine.dart';

import '../model/prayer_time_model.dart';
import '../service/prayer_automation_service.dart';

class PrayerTimeSettingsPage extends StatefulWidget {
  const PrayerTimeSettingsPage({required this.prayerTimes, super.key});

  final PrayerTimeModel? prayerTimes;

  @override
  State<PrayerTimeSettingsPage> createState() => _PrayerTimeSettingsPageState();
}

class _PrayerTimeSettingsPageState extends State<PrayerTimeSettingsPage> {
  final PrayerAutomationService _automationService = PrayerAutomationService();

  PrayerAutomationSettings? _settings;
  Map<Object?, Object?> _nativeStatus = const {};
  Map<Object?, Object?> _permissionStatus = const {};
  bool _isBusy = true;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _runBusy(() async {
      _settings = await _automationService.loadSettings();
      await _refreshDiagnostics();
    });
  }

  Future<void> _refreshDiagnostics() async {
    final nativeStatus = await SilenceOfSalahEngine.getNativeStatus();
    final permissionStatus = await SilenceOfSalahEngine.getPermissionStatus();

    if (!mounted) return;
    setState(() {
      _nativeStatus = nativeStatus ?? const {};
      _permissionStatus = permissionStatus;
    });
  }

  Future<void> _runBusy(Future<void> Function() action) async {
    if (mounted) {
      setState(() => _isBusy = true);
    }

    try {
      await action();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _updateSettings(PrayerAutomationSettings next) async {
    await _runBusy(() async {
      await _automationService.saveSettings(next);
      await _automationService.applyAllFromSettings(
        settings: next,
        prayerTimes: widget.prayerTimes,
      );
      _settings = next;
      await _refreshDiagnostics();
    });
  }

  Future<void> _grantPermissions() async {
    await _runBusy(() async {
      await _automationService.requestAllRelevantPermissions();
      await _refreshDiagnostics();
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings;

    if (settings == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final notificationControlsEnabled = settings.engineEnabled;
    final prayerSelectionEnabled =
        settings.engineEnabled && settings.notificationsEnabled;

    return Scaffold(
      appBar: AppBar(title: const Text('Prayer Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Silence of Salah',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            value: settings.engineEnabled,
            title: const Text('Enable Silence Engine'),
            subtitle: const Text(
              'Runs native foreground service for prayer-detection and DND control.',
            ),
            onChanged: _isBusy
                ? null
                : (value) {
                    _updateSettings(settings.copyWith(engineEnabled: value));
                  },
          ),
          ListTile(
            title: const Text('Grant Required Permissions'),
            subtitle: const Text(
              'Notification, exact alarms, DND access, and battery optimization.',
            ),
            trailing: ElevatedButton(
              onPressed: _isBusy ? null : _grantPermissions,
              child: const Text('Grant'),
            ),
          ),
          ListTile(
            title: const Text('Service Running'),
            subtitle: Text('${_nativeStatus['serviceRunning'] ?? 'unknown'}'),
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          const Text(
            'Prayer Reminders',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            value: settings.notificationsEnabled,
            title: const Text('Enable 3-minute reminders'),
            subtitle: const Text(
              'Schedules reminders before selected prayers and can trigger engine start.',
            ),
            onChanged: (_isBusy || !notificationControlsEnabled)
                ? null
                : (value) {
                    _updateSettings(
                      settings.copyWith(notificationsEnabled: value),
                    );
                  },
          ),
          const SizedBox(height: 4),
          const Text(
            'Select prayers to remind',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ...PrayerAutomationSettings.prayerOrder.map((prayerKey) {
            return CheckboxListTile(
              value: settings.prayerEnabled[prayerKey] ?? true,
              title: Text(_labelForPrayer(prayerKey)),
              onChanged: (_isBusy || !prayerSelectionEnabled)
                  ? null
                  : (value) {
                      final nextPrayerEnabled = Map<String, bool>.from(
                        settings.prayerEnabled,
                      );
                      nextPrayerEnabled[prayerKey] = value ?? false;
                      _updateSettings(
                        settings.copyWith(prayerEnabled: nextPrayerEnabled),
                      );
                    },
            );
          }),
          const SizedBox(height: 8),
          ListTile(
            title: const Text('Native Notification Permission'),
            subtitle: Text('${_permissionStatus['notification'] ?? 'unknown'}'),
          ),
          if (widget.prayerTimes == null)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'Prayer times are not loaded yet. Reminder scheduling will apply after times are available.',
              ),
            ),
        ],
      ),
    );
  }

  String _labelForPrayer(String prayerKey) {
    switch (prayerKey) {
      case 'fajr':
        return 'Fajr';
      case 'dhuhr':
        return 'Dhuhr';
      case 'asr':
        return 'Asr';
      case 'maghrib':
        return 'Maghrib';
      case 'isha':
        return 'Isha';
      default:
        return prayerKey;
    }
  }
}
