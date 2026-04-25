import 'package:deen_lab/app_shell/tab_model_and_controller.dart';
import 'package:deen_lab/features/hadees/controller/hadith_controller.dart';
import 'package:deen_lab/features/prayer_times/controller/prayer_time_controller.dart';
import 'package:deen_lab/features/qibla/controller/qibla_controller.dart';
import 'package:deen_lab/features/quran/controller/quran_controller.dart';
import 'package:deen_lab/features/sehri_iftari/controller/sehri_iftari_controller.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class TabTextView extends StatelessWidget {
  const TabTextView({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PrayerTimeController()..load()),
        ChangeNotifierProvider(create: (_) => SehriIftariController()..load()),
        ChangeNotifierProvider(create: (_) => QiblaController()..load()),
        ChangeNotifierProvider(create: (_) => QuranController()..loadSurahs()),
        ChangeNotifierProvider(create: (_) => HadithController()..initialize()),
      ],
      child: const _HomeDashboard(),
    );
  }
}

class _HomeDashboard extends StatelessWidget {
  const _HomeDashboard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
      children: [
        Text('Home', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 6),
        Text(
          'Useful snapshots from the core features.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 18),
        _PrayerSummaryCard(onOpen: () => _openTab(context, 'prayer')),
        const SizedBox(height: 12),
        _SehriIftariSummaryCard(
          onOpen: () => _openTab(context, 'sehri-iftari'),
        ),
        const SizedBox(height: 12),
        _QiblaSummaryCard(onOpen: () => _openTab(context, 'qibla')),
        const SizedBox(height: 12),
        _QuranSummaryCard(onOpen: () => _openTab(context, 'quran')),
        const SizedBox(height: 12),
        _HadithSummaryCard(onOpen: () => _openTab(context, 'hadees')),
      ],
    );
  }

  void _openTab(BuildContext context, String tabId) {
    final tabController = context.read<DeenLabTabController>();
    final index = tabController.tabs.indexWhere((tab) => tab.id == tabId);
    if (index != -1) {
      tabController.setIndex(index);
    }
  }
}

class _PrayerSummaryCard extends StatelessWidget {
  const _PrayerSummaryCard({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PrayerTimeController>();
    final theme = Theme.of(context);

    return _HomeCard(
      title: 'Prayer Times',
      actionLabel: 'Open',
      onOpen: onOpen,
      child: controller.isLoading
          ? const _MiniLoading()
          : controller.data == null
          ? _MiniError(message: controller.error ?? 'Prayer times unavailable')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(controller.city, style: theme.textTheme.labelLarge),
                const SizedBox(height: 8),
                Text(
                  '${controller.nextPrayerName} at ${controller.nextPrayerTime}',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  '${controller.remainingTime} remaining',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
    );
  }
}

class _SehriIftariSummaryCard extends StatelessWidget {
  const _SehriIftariSummaryCard({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SehriIftariController>();
    final theme = Theme.of(context);

    return _HomeCard(
      title: 'Sehri & Iftari',
      actionLabel: 'Open',
      onOpen: onOpen,
      child: controller.isLoading
          ? const _MiniLoading()
          : controller.today == null
          ? _MiniError(
              message: controller.error ?? 'Sehri and Iftari unavailable',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${controller.city}, ${controller.country}',
                  style: theme.textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  '${controller.nextEventLabel} at ${controller.nextEventTime}',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  '${controller.remainingTime} remaining',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
    );
  }
}

class _QiblaSummaryCard extends StatelessWidget {
  const _QiblaSummaryCard({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<QiblaController>();
    final theme = Theme.of(context);

    return _HomeCard(
      title: 'Qibla',
      actionLabel: 'Open',
      onOpen: onOpen,
      child: controller.isLoading
          ? const _MiniLoading()
          : controller.direction == null
          ? _MiniError(
              message: controller.error ?? 'Qibla direction unavailable',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${controller.city}, ${controller.country}',
                  style: theme.textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  '${controller.direction!.direction.toStringAsFixed(1)}° ${controller.directionLabel}',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  controller.hasCompassSensor
                      ? 'Compass ready'
                      : 'Static direction only',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
    );
  }
}

class _QuranSummaryCard extends StatelessWidget {
  const _QuranSummaryCard({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<QuranController>();
    final theme = Theme.of(context);

    return _HomeCard(
      title: 'Quran',
      actionLabel: 'Open',
      onOpen: onOpen,
      child: controller.isSurahListLoading
          ? const _MiniLoading()
          : controller.surahs.isEmpty
          ? _MiniError(
              message: controller.loadingError ?? 'Quran library unavailable',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${controller.surahs.length} surahs loaded',
                  style: theme.textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  controller.surahs.first.englishName,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  '${controller.surahs.first.ayahCount} ayahs',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
    );
  }
}

class _HadithSummaryCard extends StatelessWidget {
  const _HadithSummaryCard({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<HadithController>();
    final theme = Theme.of(context);
    final totalHadith = controller.collections.fold<int>(
      0,
      (sum, item) => sum + item.hadithCount,
    );

    return _HomeCard(
      title: 'Hadees',
      actionLabel: 'Open',
      onOpen: onOpen,
      child: controller.isLoadingCollections
          ? const _MiniLoading()
          : controller.collections.isEmpty
          ? _MiniError(
              message: controller.loadingError ?? 'Hadith library unavailable',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${controller.collections.length} collections',
                  style: theme.textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  controller.collections.first.name,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  '$totalHadith hadith available',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
    );
  }
}

class _HomeCard extends StatelessWidget {
  const _HomeCard({
    required this.title,
    required this.actionLabel,
    required this.onOpen,
    required this.child,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onOpen;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title, style: theme.textTheme.titleMedium),
                ),
                TextButton(onPressed: onOpen, child: Text(actionLabel)),
              ],
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

class _MiniLoading extends StatelessWidget {
  const _MiniLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: SizedBox(
        height: 18,
        width: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}

class _MiniError extends StatelessWidget {
  const _MiniError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: TextStyle(color: Theme.of(context).colorScheme.error),
    );
  }
}
