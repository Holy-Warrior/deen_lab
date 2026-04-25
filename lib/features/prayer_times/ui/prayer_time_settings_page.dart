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

class _PrayerTimeSettingsPageState extends State<PrayerTimeSettingsPage>
    with WidgetsBindingObserver {
  final PrayerAutomationService _automationService = PrayerAutomationService();

  PrayerAutomationSettings? _settings;
  Map<Object?, Object?> _nativeStatus = const {};
  Map<Object?, Object?> _permissionStatus = const {};
  bool _isBusy = true;

  bool get _allPermissionsGranted => _permissionStatus['allGranted'] == true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshDiagnostics();
    }
  }

  Future<void> _bootstrap() async {
    await _runBusy(() async {
      final loaded = await _automationService.loadSettings();
      final permissionStatus = await _automationService.getPermissionStatus();
      final sanitized = _sanitizeSettings(loaded, permissionStatus);

      if (sanitized != loaded) {
        await _automationService.saveSettings(sanitized);
        await _automationService.applyAllFromSettings(
          settings: sanitized,
          prayerTimes: widget.prayerTimes,
        );
      }

      _settings = sanitized;
      await _refreshDiagnostics();
    });
  }

  Future<void> _refreshDiagnostics() async {
    final nativeStatus = await SilenceOfSalahEngine.getNativeStatus();
    final permissionStatus = await _automationService.getPermissionStatus();

    if (!mounted) return;

    final currentSettings = _settings;
    if (currentSettings != null) {
      final sanitized = _sanitizeSettings(currentSettings, permissionStatus);
      if (sanitized != currentSettings) {
        await _automationService.saveSettings(sanitized);
        await _automationService.applyAllFromSettings(
          settings: sanitized,
          prayerTimes: widget.prayerTimes,
        );
        _settings = sanitized;
      }
    }

    if (!mounted) return;
    setState(() {
      _nativeStatus = nativeStatus ?? const {};
      _permissionStatus = permissionStatus;
    });
  }

  PrayerAutomationSettings _sanitizeSettings(
    PrayerAutomationSettings settings,
    Map<Object?, Object?> permissionStatus,
  ) {
    final allGranted = permissionStatus['allGranted'] == true;
    if (settings.engineEnabled &&
        (!settings.notificationsEnabled || !allGranted)) {
      return settings.copyWith(engineEnabled: false);
    }
    return settings;
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
      final permissionStatus = await _automationService.getPermissionStatus();
      final sanitized = _sanitizeSettings(next, permissionStatus);

      await _automationService.saveSettings(sanitized);
      await _automationService.applyAllFromSettings(
        settings: sanitized,
        prayerTimes: widget.prayerTimes,
      );

      _settings = sanitized;
      _permissionStatus = permissionStatus;
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

    final reminderSelectionEnabled = settings.notificationsEnabled && !_isBusy;
    final silenceEngineAvailable =
        settings.notificationsEnabled && _allPermissionsGranted && !_isBusy;

    return Scaffold(
      appBar: AppBar(title: const Text('Prayer Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionTitle('Prayer Reminders'),
          _infoBox(
            'Start here. DeenLab schedules reminder events about 3 minutes before the selected prayers. Those events show the reminder notification, and they are also the only place where Silence of Salah is allowed to start automatically.',
          ),
          SwitchListTile(
            value: settings.notificationsEnabled,
            title: const Text('Enable prayer reminders'),
            subtitle: const Text(
              'Required before per-prayer reminders or Silence of Salah can be used.',
            ),
            onChanged: _isBusy
                ? null
                : (value) {
                    _updateSettings(
                      settings.copyWith(
                        notificationsEnabled: value,
                        engineEnabled: value ? settings.engineEnabled : false,
                      ),
                    );
                  },
          ),
          const SizedBox(height: 8),
          const Text(
            'Select prayers to remind',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ...PrayerAutomationSettings.prayerOrder.map((prayerKey) {
            return CheckboxListTile(
              value: settings.prayerEnabled[prayerKey] ?? true,
              title: Text(_labelForPrayer(prayerKey)),
              subtitle: Text(
                reminderSelectionEnabled
                    ? 'Reminder will fire about 3 minutes before ${_labelForPrayer(prayerKey)}.'
                    : 'Enable prayer reminders first.',
              ),
              onChanged: reminderSelectionEnabled
                  ? (value) {
                      final nextPrayerEnabled = Map<String, bool>.from(
                        settings.prayerEnabled,
                      );
                      nextPrayerEnabled[prayerKey] = value ?? false;
                      _updateSettings(
                        settings.copyWith(prayerEnabled: nextPrayerEnabled),
                      );
                    }
                  : null,
            );
          }),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          _sectionTitle('Permissions'),
          _infoBox(
            'Silence of Salah needs notification permission for foreground work, exact alarms for reliable reminder timing, DND access to change audio policy, and battery optimization access so Android does not shut it down early.',
          ),
          ListTile(
            title: const Text('Required permissions'),
            subtitle: Text(_permissionSummary()),
            trailing: ElevatedButton(
              onPressed: (_isBusy || _allPermissionsGranted)
                  ? null
                  : _grantPermissions,
              child: Text(_allPermissionsGranted ? 'Granted' : 'Grant'),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          _sectionTitle('Silence of Salah'),
          _infoBox(
            'This does not start the native service from this screen. When enabled, the selected prayer reminder event starts the native service directly; the engine then watches for prayer posture and handles its own shutdown.',
          ),
          SwitchListTile(
            value: settings.engineEnabled,
            title: const Text('Start engine from reminders'),
            subtitle: Text(_silenceEngineSubtitle(settings)),
            onChanged: silenceEngineAvailable
                ? (value) {
                    _updateSettings(settings.copyWith(engineEnabled: value));
                  }
                : null,
          ),
          ListTile(
            title: const Text('Native service running'),
            subtitle: Text('${_nativeStatus['serviceRunning'] ?? 'unknown'}'),
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

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    );
  }

  Widget _infoBox(String text) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8, bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text),
    );
  }

  String _permissionSummary() {
    final exactAlarm = _permissionStatus['exactAlarm'] == true;
    final dnd = _permissionStatus['dnd'] == true;
    final battery = _permissionStatus['batteryOptimization'] == true;
    final notifications = _permissionStatus['notifications'] == true;

    if (exactAlarm && dnd && battery && notifications) {
      return 'All required permissions are granted.';
    }

    final missing = <String>[
      if (!notifications) 'notifications',
      if (!exactAlarm) 'exact alarms',
      if (!dnd) 'DND access',
      if (!battery) 'battery optimization access',
    ];

    return 'Missing: ${missing.join(', ')}.';
  }

  String _silenceEngineSubtitle(PrayerAutomationSettings settings) {
    if (!settings.notificationsEnabled) {
      return 'Enable prayer reminders first.';
    }
    if (!_allPermissionsGranted) {
      return 'Grant all required permissions before enabling this.';
    }
    return 'The next selected reminder will directly start the native service.';
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
