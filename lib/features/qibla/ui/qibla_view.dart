import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controller/qibla_controller.dart';

class QiblaView extends StatelessWidget {
  const QiblaView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<QiblaController>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (controller.isLoading && controller.direction == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (controller.error != null && controller.direction == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                controller.error!,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: controller.refresh,
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    final direction = controller.direction!;

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
                Text('Qibla Direction', style: theme.textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(
                  'Use your current location to find the direction of the Kaaba in Makkah.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${controller.city}, ${controller.country}',
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: controller.isRefreshing
                          ? null
                          : controller.refresh,
                      icon: controller.isRefreshing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.my_location),
                      label: const Text('Refresh'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (controller.error != null) ...[
            const SizedBox(height: 12),
            Text(
              controller.error!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: 20),
          Center(
            child: _CompassCard(
              degrees: direction.direction,
              label: controller.directionLabel,
              heading: controller.deviceHeading,
            ),
          ),
          if (!controller.hasCompassSensor) ...[
            const SizedBox(height: 10),
            Center(
              child: Text(
                'Compass sensor is not available on this device. Showing static Qibla direction.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.amber.shade700,
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Direction', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 12),
                  Text(
                    '${direction.direction.toStringAsFixed(2)}° ${controller.directionLabel}',
                    style: theme.textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Measured clockwise from North.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Coordinates', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 10),
                  Text('Latitude: ${direction.latitude.toStringAsFixed(5)}'),
                  Text('Longitude: ${direction.longitude.toStringAsFixed(5)}'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompassCard extends StatelessWidget {
  const _CompassCard({
    required this.degrees,
    required this.label,
    this.heading,
  });

  final double degrees;
  final String label;
  final double? heading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SizedBox(
          width: 280,
          height: 280,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      colorScheme.surfaceContainerHighest,
                      colorScheme.primaryContainer.withValues(alpha: 0.85),
                    ],
                  ),
                ),
              ),
              Transform.rotate(
                angle: _dialAngleRadians(),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    ..._buildMarkers(theme),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('N', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 162),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(width: 162),
                        Text('E', style: theme.textTheme.titleMedium),
                      ],
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 162),
                        Text('S', style: theme.textTheme.titleMedium),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('W', style: theme.textTheme.titleMedium),
                        const SizedBox(width: 162),
                      ],
                    ),
                  ],
                ),
              ),
              Transform.rotate(
                angle: _needleAngleRadians(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 96,
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(height: 74),
                  ],
                ),
              ),
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 12,
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(label, style: theme.textTheme.headlineSmall),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildMarkers(ThemeData theme) {
    final markers = <Widget>[];

    for (var i = 0; i < 12; i++) {
      markers.add(
        Transform.rotate(
          angle: (i * 30) * math.pi / 180,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 3,
                height: i % 3 == 0 ? 20 : 12,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 226),
            ],
          ),
        ),
      );
    }

    return markers;
  }

  double _dialAngleRadians() {
    final headingValue = heading;
    if (headingValue == null) {
      return 0;
    }

    return -headingValue * math.pi / 180;
  }

  double _needleAngleRadians() {
    final headingValue = heading;
    if (headingValue == null) {
      return degrees * math.pi / 180;
    }

    final relative = (degrees - headingValue) % 360;
    return relative * math.pi / 180;
  }
}
