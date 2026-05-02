import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'controller/prayer_time_controller.dart';
import 'model/prayer_time_offsets.dart';
import 'widgets/prayer_header.dart';
import 'widgets/next_prayer_card.dart';
import 'widgets/prayer_list.dart';
import 'widgets/footer_info.dart';
import 'ui/prayer_time_offset_settings_page.dart';
import 'ui/prayer_time_settings_page.dart';

class PrayerTimeTab extends StatelessWidget {
  const PrayerTimeTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => PrayerTimeController()..load(),
      child: const _PrayerTimeView(),
    );
  }
}

class _PrayerTimeView extends StatelessWidget {
  const _PrayerTimeView();

  Future<void> _handleOffsetSettingsTap(
    BuildContext context,
    PrayerTimeController controller,
  ) async {
    final result = await Navigator.of(context).push<PrayerTimeOffsets>(
      MaterialPageRoute<PrayerTimeOffsets>(
        builder: (_) =>
            PrayerTimeOffsetSettingsPage(initialOffsets: controller.offsets),
      ),
    );

    if (!context.mounted || result == null) {
      return;
    }

    await context.read<PrayerTimeController>().updateOffsets(result);
  }

  Future<void> _handleLocationTap(
    BuildContext context,
    PrayerTimeController controller,
  ) async {
    final result = await controller.detectLocation();
    if (!context.mounted) return;

    if (result == LocationActionResult.serviceDisabled) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Enable Location Service'),
            content: const Text(
              'Please enable location service (GPS) to detect your city automatically.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  await controller.openLocationSettings();
                  if (!dialogContext.mounted) return;
                  Navigator.of(dialogContext).pop();
                },
                child: const Text('Open Settings'),
              ),
            ],
          );
        },
      );
      if (!context.mounted) return;
    }

    if (result == LocationActionResult.permissionDeniedForever) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Location Permission Needed'),
            content: const Text(
              'Location permission is permanently denied. Please enable it from app settings.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  await controller.openAppSettings();
                  if (!dialogContext.mounted) return;
                  Navigator.of(dialogContext).pop();
                },
                child: const Text('Open App Settings'),
              ),
            ],
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PrayerTimeController>();

    if (controller.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (controller.data == null && controller.error != null) {
      return Center(child: Text(controller.error!));
    }

    if (controller.data == null) {
      return const Center(
        child: Text('Unable to load prayer times right now.'),
      );
    }

    final data = controller.data!;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        PrayerHeader(
          onTapLocation: () => _handleLocationTap(context, controller),
          onOpenSettings: () async {
            await Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    PrayerTimeSettingsPage(prayerTimes: controller.data),
              ),
            );
            if (!context.mounted) return;
            await context.read<PrayerTimeController>().syncPrayerAutomation();
          },
        ),
        const SizedBox(height: 16),
        if (controller.locationError != null) ...[
          Text(
            controller.locationError!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(height: 12),
        ],
        if (controller.error != null) ...[
          Text(
            controller.error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(height: 12),
        ],

        NextPrayerCard(
          nextPrayer: controller.nextPrayerName,
          time: controller.nextPrayerTime,
          remaining: controller.remainingTime,
        ),

        const SizedBox(height: 20),

        PrayerList(
          fajr: data.fajr,
          dhuhr: data.dhuhr,
          asr: data.asr,
          maghrib: data.maghrib,
          isha: data.isha,
        ),

        const SizedBox(height: 20),

        FooterInfo(
          sunrise: data.sunrise,
          onOpenOffsets: () => _handleOffsetSettingsTap(context, controller),
        ),
      ],
    );
  }
}
