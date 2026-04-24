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

        Text("Sunrise: $sunrise"),
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
}
