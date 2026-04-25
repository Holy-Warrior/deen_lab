import 'package:flutter/material.dart';

import '../features/feature_studio/model/generated_feature.dart';
import '../features/feature_studio/service/feature_studio_storage_service.dart';

class DeenLabTab {
  final String id;
  final String title;
  final TabType type;
  final GeneratedFeature? generatedFeature;

  DeenLabTab({
    required this.id,
    required this.title,
    required this.type,
    this.generatedFeature,
  });
}

enum TabType {
  text,
  addNew,
  prayer,
  sehriIftari,
  qibla,
  quran,
  hadees,
  generatedFeature,
}

class DeenLabTabController extends ChangeNotifier {
  DeenLabTabController() {
    _loadGeneratedFeatures();
  }

  final FeatureStudioStorageService _storageService =
      FeatureStudioStorageService();

  final List<GeneratedFeature> _generatedFeatures = [];
  int _targetIndex = 0;
  bool isRestoringGeneratedTabs = true;

  List<DeenLabTab> get tabs => List.unmodifiable(_buildTabs());
  int get targetIndex => _targetIndex;
  List<GeneratedFeature> get generatedFeatures =>
      List.unmodifiable(_generatedFeatures);

  void setIndex(int index) {
    _targetIndex = index;
  }

  Future<void> addGeneratedFeature(GeneratedFeature feature) async {
    _generatedFeatures.removeWhere((item) => item.id == feature.id);
    _generatedFeatures.add(feature);
    await _storageService.saveGeneratedFeatures(_generatedFeatures);

    final allTabs = _buildTabs();
    _targetIndex = allTabs.indexWhere((tab) => tab.id == feature.id);
    notifyListeners();
  }

  Future<void> deleteGeneratedFeature(String featureId) async {
    final index = _generatedFeatures.indexWhere((item) => item.id == featureId);
    if (index == -1) {
      return;
    }

    final feature = _generatedFeatures.removeAt(index);
    await _storageService.deleteHtmlFile(feature.htmlFilePath);
    await _storageService.saveGeneratedFeatures(_generatedFeatures);

    final allTabs = _buildTabs();
    if (_targetIndex >= allTabs.length) {
      _targetIndex = allTabs.isEmpty ? 0 : allTabs.length - 1;
    }

    notifyListeners();
  }

  bool hasGeneratedFeature(String featureId) {
    return _generatedFeatures.any((feature) => feature.id == featureId);
  }

  List<DeenLabTab> _buildTabs() {
    return [
      DeenLabTab(id: 'home', title: 'Home', type: TabType.text),
      DeenLabTab(id: 'prayer', title: 'Prayer Times', type: TabType.prayer),
      DeenLabTab(
        id: 'sehri-iftari',
        title: 'Sehri & Iftari',
        type: TabType.sehriIftari,
      ),
      DeenLabTab(id: 'qibla', title: 'Qibla', type: TabType.qibla),
      DeenLabTab(id: 'quran', title: 'Quran', type: TabType.quran),
      DeenLabTab(id: 'hadees', title: 'Hadees', type: TabType.hadees),
      ..._generatedFeatures.map(
        (feature) => DeenLabTab(
          id: feature.id,
          title: feature.title,
          type: TabType.generatedFeature,
          generatedFeature: feature,
        ),
      ),
      DeenLabTab(id: 'add', title: '+', type: TabType.addNew),
    ];
  }

  Future<void> _loadGeneratedFeatures() async {
    try {
      final stored = await _storageService.loadGeneratedFeatures();
      _generatedFeatures
        ..clear()
        ..addAll(stored);
    } finally {
      isRestoringGeneratedTabs = false;
      notifyListeners();
    }
  }
}
