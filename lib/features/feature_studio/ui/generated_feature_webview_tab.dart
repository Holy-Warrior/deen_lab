import 'dart:io';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../model/generated_feature.dart';

class GeneratedFeatureWebViewTab extends StatefulWidget {
  const GeneratedFeatureWebViewTab({super.key, required this.feature});

  final GeneratedFeature feature;

  @override
  State<GeneratedFeatureWebViewTab> createState() =>
      _GeneratedFeatureWebViewTabState();
}

class _GeneratedFeatureWebViewTabState
    extends State<GeneratedFeatureWebViewTab> {
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

  Future<void> _loadHtml() async {
    try {
      final file = File(widget.feature.htmlFilePath);
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
