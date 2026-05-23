import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/app_providers.dart';
import '../model/feature_history_entry.dart';

class FeatureStudioHistoryScreen extends ConsumerWidget {
  const FeatureStudioHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(featureStudioControllerProvider);
    final history = controller.history;

    return Scaffold(
      appBar: AppBar(title: const Text('AI History')),
      body: history.isEmpty
          ? const Center(child: Text('No AI history yet.'))
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              itemCount: history.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final entry = history[index];
                return _HistoryCard(entry: entry);
              },
            ),
    );
  }
}

class _HistoryCard extends ConsumerWidget {
  const _HistoryCard({required this.entry});

  final FeatureHistoryEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(featureStudioControllerProvider);
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(entry.prompt, style: theme.textTheme.titleMedium),
            const SizedBox(height: 10),
            Text(entry.response),
            const SizedBox(height: 10),
            Text(
              _statusText(entry, controller),
              style: theme.textTheme.labelLarge,
            ),
            if (entry.hasGeneratedFeature) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonal(
                    onPressed:
                        controller.featureStillExists(entry.generatedFeatureId!)
                        ? () async {
                            await controller.deleteGeneratedFeature(
                              entry.generatedFeatureId!,
                            );
                          }
                        : null,
                    child: const Text('Delete Tab'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _statusText(
    FeatureHistoryEntry entry,
    dynamic controller,
  ) {
    switch (entry.status) {
      case FeatureHistoryStatus.generated:
        final exists =
            entry.generatedFeatureId != null &&
            controller.featureStillExists(entry.generatedFeatureId!);
        return exists
            ? 'Generated tab: ${entry.generatedFeatureTitle ?? 'Feature'}'
            : 'Generated tab was deleted';
      case FeatureHistoryStatus.declined:
        return 'Request declined';
      case FeatureHistoryStatus.error:
        return 'Request failed';
    }
  }
}
