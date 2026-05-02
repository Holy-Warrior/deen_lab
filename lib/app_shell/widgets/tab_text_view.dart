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
    final tabController = context.watch<DeenLabTabController>();

    if (tabController.isRestoringHomeWidgets) {
      return const Center(child: CircularProgressIndicator());
    }

    final visibleWidgets = tabController.visibleHomeWidgets;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton.icon(
              onPressed: () => _openEditor(context),
              icon: const Icon(Icons.edit_rounded),
              label: const Text('Edit'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (visibleWidgets.isEmpty)
          _EmptyHomeState(onEdit: () => _openEditor(context))
        else
          ..._buildVisibleCards(context, visibleWidgets),
      ],
    );
  }

  List<Widget> _buildVisibleCards(
    BuildContext context,
    List<HomeWidgetType> visibleWidgets,
  ) {
    final items = <Widget>[];
    for (final widget in visibleWidgets) {
      items.add(_buildCardForWidget(context, widget));
      items.add(const SizedBox(height: 12));
    }
    if (items.isNotEmpty) {
      items.removeLast();
    }
    return items;
  }

  Widget _buildCardForWidget(BuildContext context, HomeWidgetType widget) {
    switch (widget) {
      case HomeWidgetType.prayerTimes:
        return _PrayerSummaryCard(
          onOpen: () => _openTab(context, 'prayer'),
        );
      case HomeWidgetType.sehriIftari:
        return _SehriIftariSummaryCard(
          onOpen: () => _openTab(context, 'sehri-iftari'),
        );
      case HomeWidgetType.qibla:
        return _QiblaSummaryCard(
          onOpen: () => _openTab(context, 'qibla'),
        );
      case HomeWidgetType.quran:
        return _QuranSummaryCard(
          onOpen: () => _openTab(context, 'quran'),
        );
      case HomeWidgetType.hadees:
        return _HadithSummaryCard(
          onOpen: () => _openTab(context, 'hadees'),
        );
    }
  }

  void _openTab(BuildContext context, String tabId) {
    final tabController = context.read<DeenLabTabController>();
    final index = tabController.tabs.indexWhere((tab) => tab.id == tabId);
    if (index != -1) {
      tabController.setIndex(index);
    }
  }

  void _openEditor(BuildContext context) {
    final tabController = context.read<DeenLabTabController>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: tabController,
          child: const _HomeEditorScreen(),
        ),
      ),
    );
  }
}

class _EmptyHomeState extends StatelessWidget {
  const _EmptyHomeState({required this.onEdit});

  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Icon(
            Icons.widgets_outlined,
            size: 34,
            color: colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text('No widgets on home', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Your home dashboard is empty. Open the editor to add the widgets you want back.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_rounded),
            label: const Text('Edit Home'),
          ),
        ],
      ),
    );
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
      onTap: onOpen,
      icon: HomeWidgetType.prayerTimes.icon,
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
      onTap: onOpen,
      icon: HomeWidgetType.sehriIftari.icon,
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
      onTap: onOpen,
      icon: HomeWidgetType.qibla.icon,
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
      onTap: onOpen,
      icon: HomeWidgetType.quran.icon,
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
      onTap: onOpen,
      icon: HomeWidgetType.hadees.icon,
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
    required this.onTap,
    required this.icon,
    required this.child,
  });

  final String title;
  final VoidCallback onTap;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    height: 42,
                    width: 42,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: colorScheme.onPrimaryContainer),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(title, style: theme.textTheme.titleMedium),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeEditorScreen extends StatelessWidget {
  const _HomeEditorScreen();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tabController = context.watch<DeenLabTabController>();
    final visibleWidgets = tabController.visibleHomeWidgets;
    final availableWidgets = tabController.availableHomeWidgets;

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Home')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Visible widgets', style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  'Choose what appears on your home tab. Keep at least one widget visible.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: visibleWidgets
                      .map(
                        (widget) => InputChip(
                          avatar: Icon(widget.icon, size: 18),
                          label: Text(widget.title),
                          onDeleted: visibleWidgets.length > 1
                              ? () => tabController.hideHomeWidget(widget)
                              : null,
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Add widgets', style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  'Bring back any cards you want on the dashboard.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                if (availableWidgets.isEmpty)
                  Text(
                    'All available widgets are already on your home tab.',
                    style: theme.textTheme.bodyMedium,
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: availableWidgets
                        .map(
                          (widget) => ActionChip(
                            avatar: Icon(widget.icon, size: 18),
                            label: Text(widget.title),
                            onPressed: () => tabController.showHomeWidget(widget),
                          ),
                        )
                        .toList(),
                  ),
              ],
            ),
          ),
        ],
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
