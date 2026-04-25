import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controller/prayer_time_controller.dart';
import '../model/prayer_method.dart';

class FooterInfo extends StatelessWidget {
  final String sunrise;

  const FooterInfo({super.key, required this.sunrise});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PrayerTimeController>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const SizedBox(height: 8),

        Text("Sunrise: ${_formatTo12Hour(sunrise)}"),
        const SizedBox(height: 8),

        const Text("Calculation Method:"),

        DropdownButton<PrayerMethod>(
          value: controller.method,
          items: PrayerMethod.values.map((m) {
            return DropdownMenuItem(value: m, child: Text(m.label));
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              controller.changeMethod(value);
            }
          },
        ),
      ],
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
