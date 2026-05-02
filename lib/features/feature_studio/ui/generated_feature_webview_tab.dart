import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../app_shell/tab_model_and_controller.dart';
import '../controller/generated_feature_editor_controller.dart';
import '../model/generated_feature.dart';

class GeneratedFeatureWebViewTab extends StatefulWidget {
  const GeneratedFeatureWebViewTab({super.key, required this.feature});

  final GeneratedFeature feature;

  @override
  State<GeneratedFeatureWebViewTab> createState() =>
      _GeneratedFeatureWebViewTabState();
}

class _GeneratedFeatureWebViewTabState extends State<GeneratedFeatureWebViewTab> {
  @override
  Widget build(BuildContext context) {
    final feature = widget.feature;
    final activeVersion = feature.activeVersion;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${feature.title} · v${activeVersion.versionNumber}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _openEditor(context, feature),
                icon: const Icon(Icons.edit_rounded),
                label: const Text('Edit'),
              ),
            ],
          ),
        ),
        Expanded(
          child: _GeneratedFeatureFileWebView(
            filePath: activeVersion.htmlFilePath,
          ),
        ),
      ],
    );
  }

  void _openEditor(BuildContext context, GeneratedFeature feature) {
    final tabController = context.read<DeenLabTabController>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider(
          create: (_) => GeneratedFeatureEditorController(
            feature: feature,
            tabController: tabController,
          ),
          child: const _GeneratedFeatureEditorScreen(),
        ),
      ),
    );
  }
}

class _GeneratedFeatureEditorScreen extends StatefulWidget {
  const _GeneratedFeatureEditorScreen();

  @override
  State<_GeneratedFeatureEditorScreen> createState() =>
      _GeneratedFeatureEditorScreenState();
}

class _GeneratedFeatureEditorScreenState
    extends State<_GeneratedFeatureEditorScreen> {
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
    final controller = context.watch<GeneratedFeatureEditorController>();
    final feature = controller.feature;
    final preview = controller.previewVersion;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text('Edit ${feature.title}')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Upgrade Studio',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Describe an improvement for ${feature.title}. The AI will respond with a live preview you can activate for this tab.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _PromptChip(
                      label: 'Improve interface',
                      onTap: () => _setPrompt(
                        'Improve the interface of ${feature.title} with better layout, clearer hierarchy, and more polished interactions.',
                      ),
                    ),
                    _PromptChip(
                      label: 'Add a useful feature',
                      onTap: () => _setPrompt(
                        'Add a new useful feature to ${feature.title}. I want this specific addition: ',
                      ),
                    ),
                    _PromptChip(
                      label: 'Make mobile UX smoother',
                      onTap: () => _setPrompt(
                        'Refine ${feature.title} for smoother mobile use with better spacing, touch targets, and feedback.',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _promptController,
                  minLines: 4,
                  maxLines: 7,
                  decoration: InputDecoration(
                    hintText:
                        'Example: Add a weekly progress section to this feature and make the interface feel more polished.',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: controller.isSubmitting
                        ? null
                        : () async {
                            await controller.submitEditPrompt(
                              _promptController.text,
                            );
                            if (!mounted) {
                              return;
                            }
                            if (controller.previewVersion != null) {
                              _promptController.clear();
                            }
                          },
                    icon: controller.isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome),
                    label: const Text('Generate Upgrade Preview'),
                  ),
                ),
                if (controller.error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    controller.error!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          _VersionSummaryCard(
            activeVersion: controller.activeVersion,
            previewVersion: preview,
          ),
          const SizedBox(height: 16),
          if (preview == null)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Text(
                  'No upgrade preview yet. Ask the AI for a better interface or a small new feature for this tab.',
                ),
              ),
            )
          else ...[
            Card(
              clipBehavior: Clip.antiAlias,
              child: SizedBox(
                height: 440,
                child: _GeneratedFeatureFileWebView(
                  filePath: preview.htmlFilePath,
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
                    Text('AI Response', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(preview.aiMessage, style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 8),
                    Text(
                      'Prompt: ${preview.prompt}',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: controller.isActivating
                            ? null
                            : () async {
                                final messenger = ScaffoldMessenger.of(context);
                                await controller.activatePreview();
                                if (!mounted) {
                                  return;
                                }
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Preview activated for this tab.',
                                    ),
                                  ),
                                );
                              },
                        icon: controller.isActivating
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.check_circle_outline_rounded),
                        label: const Text('Activate This Version'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _setPrompt(String value) {
    _promptController
      ..text = value
      ..selection = TextSelection.fromPosition(
        TextPosition(offset: _promptController.text.length),
      );
  }
}

class _VersionSummaryCard extends StatelessWidget {
  const _VersionSummaryCard({
    required this.activeVersion,
    required this.previewVersion,
  });

  final GeneratedFeatureVersion activeVersion;
  final GeneratedFeatureVersion? previewVersion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Version Status', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Text(
              'Live: v${activeVersion.versionNumber}',
              style: theme.textTheme.bodyLarge,
            ),
            if (previewVersion != null) ...[
              const SizedBox(height: 6),
              Text(
                'Preview ready: v${previewVersion!.versionNumber}',
                style: theme.textTheme.bodyLarge,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PromptChip extends StatelessWidget {
  const _PromptChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(label: Text(label), onPressed: onTap);
  }
}

class _GeneratedFeatureFileWebView extends StatefulWidget {
  const _GeneratedFeatureFileWebView({required this.filePath});

  final String filePath;

  @override
  State<_GeneratedFeatureFileWebView> createState() =>
      _GeneratedFeatureFileWebViewState();
}

class _GeneratedFeatureFileWebViewState
    extends State<_GeneratedFeatureFileWebView> {
  late final WebViewController _webViewController;
  bool isLoading = true;
  String? loadError;

  @override
  void initState() {
    super.initState();
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) {
              setState(() => isLoading = false);
            }
          },
          onNavigationRequest: (request) {
            if (request.url.startsWith('about:blank') ||
                request.url.startsWith('data:') ||
                request.url.startsWith('file:')) {
              return NavigationDecision.navigate;
            }
            return NavigationDecision.prevent;
          },
        ),
      );
    _loadHtml();
  }

  @override
  void didUpdateWidget(covariant _GeneratedFeatureFileWebView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath) {
      isLoading = true;
      loadError = null;
      _loadHtml();
    }
  }

  Future<void> _loadHtml() async {
    try {
      final file = File(widget.filePath);
      if (!await file.exists()) {
        throw Exception('Generated HTML file is missing.');
      }

      final html = await file.readAsString();
      await _webViewController.loadHtmlString(html);
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
          loadError = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(loadError!, textAlign: TextAlign.center),
        ),
      );
    }

    return Stack(
      children: [
        WebViewWidget(controller: _webViewController),
        if (isLoading) const Center(child: CircularProgressIndicator()),
      ],
    );
  }
}
