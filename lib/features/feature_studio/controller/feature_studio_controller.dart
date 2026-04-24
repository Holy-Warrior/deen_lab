import 'package:flutter/material.dart';

import '../../../app_shell/tab_model_and_controller.dart';
import '../model/feature_history_entry.dart';
import '../model/generated_feature.dart';
import '../service/feature_studio_storage_service.dart';
import '../service/groq_feature_builder_service.dart';

class FeatureStudioController extends ChangeNotifier {
  FeatureStudioController({required DeenLabTabController tabController})
    : _tabController = tabController;

  final DeenLabTabController _tabController;
  final GroqFeatureBuilderService _builderService = GroqFeatureBuilderService();
  final FeatureStudioStorageService _storageService =
      FeatureStudioStorageService();

  List<FeatureHistoryEntry> history = [];
  bool isLoadingHistory = true;
  bool isSubmitting = false;
  String? error;
  bool _isDisposed = false;

  Future<void> loadHistory() async {
    try {
      history = List<FeatureHistoryEntry>.from(
        await _storageService.loadHistory(),
      );
      history.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } finally {
      if (!_isDisposed) {
        isLoadingHistory = false;
        _notifySafely();
      }
    }
  }

  Future<void> submitPrompt(String prompt) async {
    final trimmed = prompt.trim();
    if (trimmed.isEmpty || isSubmitting) {
      return;
    }

    isSubmitting = true;
    error = null;
    _notifySafely();

    try {
      if (_failsLocalScopeCheck(trimmed)) {
        final declined = FeatureHistoryEntry(
          id: _generateId(),
          prompt: trimmed,
          response:
              'This tab only accepts requests to add small Deen-related app features.',
          status: FeatureHistoryStatus.declined,
          createdAt: DateTime.now(),
        );
        await _appendHistory(declined);
        return;
      }

      final result = await _builderService.buildFeature(trimmed);
      if (_isDisposed) {
        return;
      }

      if (result.didGenerate) {
        final featureId = _generateId();
        final htmlPath = await _storageService.saveHtmlFile(
          featureId: featureId,
          html: result.html!,
        );
        if (_isDisposed) {
          return;
        }

        final feature = GeneratedFeature(
          id: featureId,
          title: _normalizeTitle(result.title),
          prompt: trimmed,
          htmlFilePath: htmlPath,
          createdAt: DateTime.now(),
          aiMessage: result.message,
        );

        await _tabController.addGeneratedFeature(feature);
        if (_isDisposed) {
          return;
        }

        final entry = FeatureHistoryEntry(
          id: _generateId(),
          prompt: trimmed,
          response: result.message,
          status: FeatureHistoryStatus.generated,
          createdAt: DateTime.now(),
          generatedFeatureId: feature.id,
          generatedFeatureTitle: feature.title,
        );
        await _appendHistory(entry);
      } else {
        final entry = FeatureHistoryEntry(
          id: _generateId(),
          prompt: trimmed,
          response: result.message,
          status: FeatureHistoryStatus.declined,
          createdAt: DateTime.now(),
          generatedFeatureTitle: result.title,
        );
        await _appendHistory(entry);
      }
    } catch (e) {
      error = e.toString();
      final entry = FeatureHistoryEntry(
        id: _generateId(),
        prompt: trimmed,
        response: 'The request failed: $e',
        status: FeatureHistoryStatus.error,
        createdAt: DateTime.now(),
      );
      await _appendHistory(entry);
    } finally {
      if (!_isDisposed) {
        isSubmitting = false;
        _notifySafely();
      }
    }
  }

  Future<void> deleteGeneratedFeature(String featureId) async {
    await _tabController.deleteGeneratedFeature(featureId);
    _notifySafely();
  }

  bool featureStillExists(String featureId) {
    return _tabController.hasGeneratedFeature(featureId);
  }

  Future<void> _appendHistory(FeatureHistoryEntry entry) async {
    history = [entry, ...history];
    await _storageService.saveHistory(history);
  }

  void _notifySafely() {
    if (_isDisposed) {
      return;
    }

    notifyListeners();
  }

  bool _failsLocalScopeCheck(String prompt) {
    final lower = prompt.toLowerCase();

    const featureSignals = [
      'feature',
      'tab',
      'tool',
      'screen',
      'page',
      'tracker',
      'counter',
      'planner',
      'calculator',
      'reminder',
      'viewer',
      'reader',
      'generator',
    ];

    const deenSignals = [
      'deen',
      'islam',
      'islamic',
      'dua',
      'quran',
      'hadith',
      'hadees',
      'prayer',
      'salah',
      'qibla',
      'fast',
      'ramadan',
      'tasbeeh',
      'dhikr',
      'zikr',
      'muslim',
      'charity',
      'zakat',
      'sadaqah',
      'sehri',
      'iftari',
    ];

    final hasFeatureSignal = featureSignals.any(lower.contains);
    final hasDeenSignal = deenSignals.any(lower.contains);

    return !(hasFeatureSignal && hasDeenSignal);
  }

  String _normalizeTitle(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return 'Feature';
    }

    return trimmed.length > 18
        ? '${trimmed.substring(0, 18).trim()}...'
        : trimmed;
  }

  String _generateId() => DateTime.now().microsecondsSinceEpoch.toString();

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
