import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../prayer_times/model/prayer_method.dart';
import '../controller/sehri_iftari_controller.dart';
import '../model/sehri_iftari_day.dart';

class SehriIftariView extends StatefulWidget {
  const SehriIftariView({super.key});

  @override
  State<SehriIftariView> createState() => _SehriIftariViewState();
}

class _SehriIftariViewState extends State<SehriIftariView> {
  late final TextEditingController _cityController;
  late final TextEditingController _countryController;
  PrayerMethod? _pendingMethod;

  Future<void> _handleLocationTap(SehriIftariController controller) async {
    final result = await controller.detectLocation();
    if (!mounted) {
      return;
    }

    if (result == SehriLocationActionResult.serviceDisabled) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Enable Location Service'),
            content: const Text(
              'Please enable location service (GPS) to detect city and country automatically.',
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
      if (!mounted) return;
    }

    if (result == SehriLocationActionResult.permissionDeniedForever) {
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

    _cityController.text = controller.city;
    _countryController.text = controller.country;
  }

  @override
  void initState() {
    super.initState();
    _cityController = TextEditingController();
    _countryController = TextEditingController();
  }

  @override
  void dispose() {
    _cityController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SehriIftariController>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_cityController.text.isEmpty && controller.city.isNotEmpty) {
      _cityController.text = controller.city;
    }
    if (_countryController.text.isEmpty && controller.country.isNotEmpty) {
      _countryController.text = controller.country;
    }
    _pendingMethod ??= controller.method;

    if (controller.isLoading && controller.today == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                colors: [
                  colorScheme.primaryContainer,
                  colorScheme.secondaryContainer,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sehri & Iftari', style: theme.textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(
                  'Track Sehri closing time, Fajr, Iftar, and the full monthly fasting schedule.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _cityController,
                  decoration: InputDecoration(
                    labelText: 'City',
                    prefixIcon: const Icon(Icons.location_city_outlined),
                    filled: true,
                    fillColor: theme.scaffoldBackgroundColor.withValues(
                      alpha: 0.82,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _countryController,
                  decoration: InputDecoration(
                    labelText: 'Country',
                    prefixIcon: const Icon(Icons.public_outlined),
                    filled: true,
                    fillColor: theme.scaffoldBackgroundColor.withValues(
                      alpha: 0.82,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<PrayerMethod>(
                  initialValue: _pendingMethod,
                  decoration: InputDecoration(
                    labelText: 'Calculation Method',
                    filled: true,
                    fillColor: theme.scaffoldBackgroundColor.withValues(
                      alpha: 0.82,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  items: PrayerMethod.values
                      .map(
                        (method) => DropdownMenuItem(
                          value: method,
                          child: Text(method.label),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) => setState(() => _pendingMethod = value),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () async {
                          FocusScope.of(context).unfocus();
                          await controller.updateSettings(
                            city: _cityController.text,
                            country: _countryController.text,
                            method: _pendingMethod ?? controller.method,
                          );
                          if (!mounted) {
                            return;
                          }
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Update Timings'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton.filledTonal(
                      onPressed: controller.isLocating
                          ? null
                          : () async {
                              await _handleLocationTap(controller);
                            },
                      icon: controller.isLocating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.my_location),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (controller.error != null) ...[
            const SizedBox(height: 14),
            Text(
              controller.error!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.error,
              ),
            ),
          ],
          if (controller.locationError != null) ...[
            const SizedBox(height: 8),
            Text(
              controller.locationError!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: 18),
          if (controller.today != null) ...[
            _CountdownCard(controller: controller),
            const SizedBox(height: 14),
            _TodayTimingGrid(day: controller.today!),
            const SizedBox(height: 18),
          ],
          Row(
            children: [
              Text('Monthly Schedule', style: theme.textTheme.titleLarge),
              const Spacer(),
              IconButton(
                onPressed: controller.isRefreshingMonth
                    ? null
                    : () => controller.changeMonth(-1),
                icon: const Icon(Icons.chevron_left),
              ),
              Text(
                _formatMonth(controller.visibleMonth),
                style: theme.textTheme.titleMedium,
              ),
              IconButton(
                onPressed: controller.isRefreshingMonth
                    ? null
                    : () => controller.changeMonth(1),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (controller.isRefreshingMonth)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (controller.monthDays.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Text('No calendar data is available for this month.'),
            )
          else
            ...controller.monthDays.map(
              (day) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _MonthDayCard(
                  day: day,
                  isToday: _isSameDate(day.gregorianDate, DateTime.now()),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatMonth(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return '${months[date.month - 1]} ${date.year}';
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _CountdownCard extends StatelessWidget {
  const _CountdownCard({required this.controller});

  final SehriIftariController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.schedule, color: colorScheme.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    controller.nextEventLabel,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${controller.nextEventTime} • ${controller.remainingTime} left',
                    style: theme.textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayTimingGrid extends StatelessWidget {
  const _TodayTimingGrid({required this.day});

  final SehriIftariDay day;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Today', style: theme.textTheme.titleLarge),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _TimeTile(label: 'Sehri Ends', value: day.imsak),
            _TimeTile(label: 'Fajr', value: day.fajr),
            _TimeTile(label: 'Iftar', value: day.maghrib),
            _TimeTile(
              label: 'Hijri',
              value: '${day.hijriDate} ${day.hijriMonth}',
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          '${day.gregorianDay} • ${day.timezone} • ${day.methodName}',
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _TimeTile extends StatelessWidget {
  const _TimeTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          Text(value, style: theme.textTheme.headlineSmall),
        ],
      ),
    );
  }
}

class _MonthDayCard extends StatelessWidget {
  const _MonthDayCard({required this.day, required this.isToday});

  final SehriIftariDay day;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      color: isToday
          ? colorScheme.primaryContainer.withValues(alpha: 0.7)
          : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 72,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(
                    '${day.gregorianDate.day}',
                    style: theme.textTheme.headlineSmall,
                  ),
                  Text(
                    day.gregorianDay.substring(0, 3),
                    style: theme.textTheme.labelLarge,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${day.hijriDate} ${day.hijriMonth}',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text('Sehri Ends: ${day.imsak}'),
                  Text('Fajr: ${day.fajr}'),
                  Text('Iftar: ${day.maghrib}'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
