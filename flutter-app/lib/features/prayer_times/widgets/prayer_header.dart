import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/app_providers.dart';

class PrayerHeader extends ConsumerWidget {
  const PrayerHeader({this.onOpenSettings, this.onTapLocation, super.key});

  final VoidCallback? onOpenSettings;
  final VoidCallback? onTapLocation;

  static const cities = ["Peshawar", "Lahore", "Karachi", "Islamabad"];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(prayerTimeControllerProvider);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Prayer Times",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),

              DropdownButton<String>(
                value: controller.city,
                items: cities.map((c) {
                  return DropdownMenuItem(value: c, child: Text(c));
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    controller.changeCity(value);
                  }
                },
              ),
            ],
          ),
        ),

        IconButton(
          icon: controller.isLocating
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.my_location),
          onPressed: controller.isLocating ? null : onTapLocation,
        ),
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: onOpenSettings,
          tooltip: 'Prayer settings',
        ),
      ],
    );
  }
}
