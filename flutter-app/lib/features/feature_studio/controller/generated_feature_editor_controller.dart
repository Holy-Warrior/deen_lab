import 'package:flutter/material.dart';

import '../../../app_shell/tab_model_and_controller.dart';
import '../model/generated_feature.dart';
import '../service/feature_studio_storage_service.dart';
import '../service/groq_feature_builder_service.dart';

class GeneratedFeatureEditorController extends ChangeNotifier {
  GeneratedFeatureEditorController({
    required GeneratedFeature feature,
    required DeenLabTabController tabController,
  }) : _feature = feature,
       _tabController = tabController;

  final DeenLabTabController _tabController;
  final GroqFeatureBuilderService _builderService = GroqFeatureBuilderService();
  final FeatureStudioStorageService _storageService =
      FeatureStudioStorageService();

  GeneratedFeature _feature;
  bool isSubmitting = false;
  bool isActivating = false;
  String? error;

  GeneratedFeature get feature => _feature;
  GeneratedFeatureVersion get activeVersion => _feature.activeVersion;
  GeneratedFeatureVersion? get previewVersion => _feature.pendingVersion;
  List<GeneratedFeatureVersion> get versions => _feature.effectiveVersions;

  Future<void> submitEditPrompt(String prompt) async {
    final trimmed = prompt.trim();
    if (trimmed.isEmpty || isSubmitting) {
      return;
    }

    isSubmitting = true;
    error = null;
    notifyListeners();

    try {
      final currentVersion = previewVersion ?? activeVersion;
      final currentHtml = await _storageService.readHtmlFile(
        currentVersion.htmlFilePath,
      );

      final result = await _builderService.updateFeature(
        featureTitle: _feature.title,
        originalPrompt: _feature.prompt,
        currentPrompt: currentVersion.prompt,
        currentAiMessage: currentVersion.aiMessage,
        currentHtml: currentHtml,
        userRequest: trimmed,
      );

      if (!result.didGenerate) {
        error = result.message;
        return;
      }

      final nextVersionNumber = versions.isEmpty
          ? 1
          : versions
                .map((version) => version.versionNumber)
                .reduce((a, b) => a > b ? a : b) +
            1;
      final versionId = '${_feature.id}_v$nextVersionNumber';
      final htmlPath = await _storageService.saveHtmlFile(
        featureId: versionId,
        html: result.html!,
      );

      final newVersion = GeneratedFeatureVersion(
        id: versionId,
        prompt: trimmed,
        aiMessage: result.message,
        htmlFilePath: htmlPath,
        createdAt: DateTime.now(),
        versionNumber: nextVersionNumber,
      );

      _feature = _feature.copyWith(
        pendingVersionId: newVersion.id,
        versions: [...versions, newVersion],
      );
      await _tabController.updateGeneratedFeature(_feature);
    } catch (e) {
      error = e.toString();
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }

  Future<void> activatePreview() async {
    final preview = previewVersion;
    if (preview == null || isActivating) {
      return;
    }

    isActivating = true;
    error = null;
    notifyListeners();

    try {
      _feature = _feature.copyWith(
        prompt: preview.prompt,
        aiMessage: preview.aiMessage,
        htmlFilePath: preview.htmlFilePath,
        activeVersionId: preview.id,
        clearPendingVersion: true,
      );
      await _tabController.updateGeneratedFeature(_feature);
    } catch (e) {
      error = e.toString();
    } finally {
      isActivating = false;
      notifyListeners();
    }
  }
}
