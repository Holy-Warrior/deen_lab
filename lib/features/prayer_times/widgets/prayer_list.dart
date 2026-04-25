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
      ("Fajr", fajr),
      ("Dhuhr", dhuhr),
      ("Asr", asr),
      ("Maghrib", maghrib),
      ("Isha", isha),
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
}
