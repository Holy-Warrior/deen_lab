import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../config/groq_config.dart';
import '../controller/feature_studio_controller.dart';
import '../model/feature_history_entry.dart';
import 'feature_studio_history_screen.dart';

class FeatureStudioView extends StatefulWidget {
  const FeatureStudioView({super.key});

  @override
  State<FeatureStudioView> createState() => _FeatureStudioViewState();
}

class _FeatureStudioViewState extends State<FeatureStudioView> {
  late final TextEditingController _promptController;

  @override
  void initState() {
    super.initState();
    _promptController = TextEditingController();
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<FeatureStudioController>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListView(
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
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'AI Feature Studio',
                      style: theme.textTheme.headlineSmall,
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ChangeNotifierProvider.value(
                            value: controller,
                            child: const FeatureStudioHistoryScreen(),
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.history),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Describe a small Deen-related feature for the app. The AI will either decline it or generate a single HTML feature that becomes a new tab.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _promptController,
                minLines: 4,
                maxLines: 7,
                decoration: InputDecoration(
                  hintText:
                      'Example: Add a tasbeeh counter tab with morning and evening presets, dhikr phrases, and a simple streak tracker.',
                  filled: true,
                  fillColor: theme.scaffoldBackgroundColor.withValues(
                    alpha: 0.84,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: controller.isSubmitting
                          ? null
                          : () async {
                              final prompt = _promptController.text;
                              await controller.submitPrompt(prompt);
                              if (!mounted) {
                                return;
                              }
                              _promptController.clear();
                            },
                      icon: controller.isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_awesome),
                      label: const Text('Generate Feature'),
                    ),
                  ),
                ],
              ),
              if (!GroqConfig.isConfigured) ...[
                const SizedBox(height: 12),
                Text(
                  'Groq key not configured yet. Add it in lib/config/groq_config.dart.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text('Recent Responses', style: theme.textTheme.titleLarge),
        const SizedBox(height: 10),
        if (controller.isLoadingHistory)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (controller.history.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Text(
                'No AI requests yet. Ask for a Deen-related feature to get started.',
              ),
            ),
          )
        else
          ...controller.history
              .take(5)
              .map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _HistoryPreviewCard(entry: entry),
                ),
              ),
      ],
    );
  }
}

class _HistoryPreviewCard extends StatelessWidget {
  const _HistoryPreviewCard({required this.entry});

  final FeatureHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final badgeColor = switch (entry.status) {
      FeatureHistoryStatus.generated => colorScheme.primaryContainer,
      FeatureHistoryStatus.declined => colorScheme.secondaryContainer,
      FeatureHistoryStatus.error => colorScheme.errorContainer,
    };

    final badgeText = switch (entry.status) {
      FeatureHistoryStatus.generated => 'Generated',
      FeatureHistoryStatus.declined => 'Declined',
      FeatureHistoryStatus.error => 'Error',
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(badgeText),
            ),
            const SizedBox(height: 12),
            Text(entry.prompt, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(entry.response, style: theme.textTheme.bodyMedium),
            if (entry.generatedFeatureTitle != null) ...[
              const SizedBox(height: 10),
              Text(
                'Tab: ${entry.generatedFeatureTitle!}',
                style: theme.textTheme.labelLarge,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
