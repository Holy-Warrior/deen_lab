import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'controller/prayer_time_controller.dart';
import 'widgets/prayer_header.dart';
import 'widgets/next_prayer_card.dart';
import 'widgets/prayer_list.dart';
import 'widgets/footer_info.dart';

class PrayerTimeTab extends StatelessWidget {
  const PrayerTimeTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(create: (_) => PrayerTimeController()..load(), child: const _PrayerTimeView());
  }
}

class _PrayerTimeView extends StatelessWidget {
  const _PrayerTimeView();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PrayerTimeController>();

    if (controller.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (controller.error != null) {
      return Center(child: Text(controller.error!));
    }

    final data = controller.data!;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const PrayerHeader(),
        const SizedBox(height: 16),

        NextPrayerCard(
          nextPrayer: controller.nextPrayerName,
          time: controller.nextPrayerTime,
          remaining: controller.remainingTime,
        ),

        const SizedBox(height: 20),

        PrayerList(fajr: data.fajr, dhuhr: data.dhuhr, asr: data.asr, maghrib: data.maghrib, isha: data.isha),

        const SizedBox(height: 20),

        FooterInfo(sunrise: data.sunrise),
      ],
    );
  }
}
