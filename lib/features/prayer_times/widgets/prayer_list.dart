import 'package:flutter/material.dart';

class PrayerList extends StatelessWidget {
  final String fajr;
  final String dhuhr;
  final String asr;
  final String maghrib;
  final String isha;

  const PrayerList({
    super.key,
    required this.fajr,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
  });

  @override
  Widget build(BuildContext context) {
    final prayers = [
      ("Fajr", _formatTo12Hour(fajr)),
      ("Dhuhr", _formatTo12Hour(dhuhr)),
      ("Asr", _formatTo12Hour(asr)),
      ("Maghrib", _formatTo12Hour(maghrib)),
      ("Isha", _formatTo12Hour(isha)),
    ];

    return Column(
      children: prayers.map((p) {
        return Card(
          child: ListTile(
            leading: const Icon(Icons.access_time),
            title: Text(p.$1),
            trailing: Text(p.$2),
          ),
        );
      }).toList(),
    );
  }

  String _formatTo12Hour(String rawTime) {
    final clean = rawTime.split(' ').first.trim();
    final parts = clean.split(':');
    if (parts.length < 2) return rawTime;

    final hour24 = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour24 == null || minute == null) return rawTime;

    final hour12 = hour24 == 0 ? 12 : (hour24 > 12 ? hour24 - 12 : hour24);
    final period = hour24 >= 12 ? 'PM' : 'AM';
    return '$hour12:${minute.toString().padLeft(2, '0')} $period';
  }
}
