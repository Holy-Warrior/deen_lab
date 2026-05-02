import 'package:flutter/material.dart';

import '../model/prayer_time_offsets.dart';

class PrayerTimeOffsetSettingsPage extends StatefulWidget {
  const PrayerTimeOffsetSettingsPage({required this.initialOffsets, super.key});

  final PrayerTimeOffsets initialOffsets;

  @override
  State<PrayerTimeOffsetSettingsPage> createState() =>
      _PrayerTimeOffsetSettingsPageState();
}

class _PrayerTimeOffsetSettingsPageState
    extends State<PrayerTimeOffsetSettingsPage> {
  late PrayerTimeOffsets _offsets = widget.initialOffsets;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prayer Time Offsets'),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _offsets = PrayerTimeOffsets.defaults;
              });
            },
            child: const Text('Reset'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _infoCard(context),
          const SizedBox(height: 16),
          ..._rows().map(_buildOffsetTile),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: FilledButton(
          onPressed: () => Navigator.of(context).pop(_offsets),
          child: const Text('Save offsets'),
        ),
      ),
    );
  }

  Widget _infoCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        'Adjust prayer times in minutes. Positive values move a prayer later, and negative values move it earlier. These offsets are saved for future app launches.',
      ),
    );
  }

  List<({String key, String label, int value})> _rows() {
    return [
      (key: 'fajr', label: 'Fajr', value: _offsets.fajr),
      (key: 'sunrise', label: 'Sunrise', value: _offsets.sunrise),
      (key: 'dhuhr', label: 'Dhuhr', value: _offsets.dhuhr),
      (key: 'asr', label: 'Asr', value: _offsets.asr),
      (key: 'maghrib', label: 'Maghrib', value: _offsets.maghrib),
      (key: 'isha', label: 'Isha', value: _offsets.isha),
    ];
  }

  Widget _buildOffsetTile(({String key, String label, int value}) row) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(row.label),
        subtitle: Text(PrayerTimeOffsets.formatMinutes(row.value)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Decrease ${row.label}',
              onPressed: () => _changeOffset(row.key, row.value - 1),
              icon: const Icon(Icons.remove_circle_outline),
            ),
            Text(
              '${row.value}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            IconButton(
              tooltip: 'Increase ${row.label}',
              onPressed: () => _changeOffset(row.key, row.value + 1),
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
      ),
    );
  }

  void _changeOffset(String key, int nextValue) {
    setState(() {
      _offsets = switch (key) {
        'fajr' => _offsets.copyWith(fajr: nextValue),
        'sunrise' => _offsets.copyWith(sunrise: nextValue),
        'dhuhr' => _offsets.copyWith(dhuhr: nextValue),
        'asr' => _offsets.copyWith(asr: nextValue),
        'maghrib' => _offsets.copyWith(maghrib: nextValue),
        'isha' => _offsets.copyWith(isha: nextValue),
        _ => _offsets,
      };
    });
  }
}
