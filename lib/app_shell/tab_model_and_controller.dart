import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

enum HomeWidgetType {
  prayerTimes,
  sehriIftari,
  qibla,
  quran,
  hadees,
}

extension HomeWidgetTypeX on HomeWidgetType {
  String get id {
    switch (this) {
      case HomeWidgetType.prayerTimes:
        return 'prayer-times';
      case HomeWidgetType.sehriIftari:
        return 'sehri-iftari';
      case HomeWidgetType.qibla:
        return 'qibla';
      case HomeWidgetType.quran:
        return 'quran';
      case HomeWidgetType.hadees:
        return 'hadees';
    }
  }

  String get title {
    switch (this) {
      case HomeWidgetType.prayerTimes:
        return 'Prayer Times';
      case HomeWidgetType.sehriIftari:
        return 'Sehri & Iftari';
      case HomeWidgetType.qibla:
        return 'Qibla';
      case HomeWidgetType.quran:
        return 'Quran';
      case HomeWidgetType.hadees:
        return 'Hadees';
    }
  }

  IconData get icon {
    switch (this) {
      case HomeWidgetType.prayerTimes:
        return Icons.access_time_filled_rounded;
      case HomeWidgetType.sehriIftari:
        return Icons.nights_stay_rounded;
      case HomeWidgetType.qibla:
        return Icons.explore_rounded;
      case HomeWidgetType.quran:
        return Icons.menu_book_rounded;
      case HomeWidgetType.hadees:
        return Icons.auto_stories_rounded;
    }
  }
}

class DeenLabTabController extends ChangeNotifier {
  DeenLabTabController() {
    _loadGeneratedFeatures();
    _loadHomeWidgetPreferences();
  }

  final FeatureStudioStorageService _storageService =
      FeatureStudioStorageService();
  static const _homeWidgetsKey = 'home_visible_widgets';

  final List<GeneratedFeature> _generatedFeatures = [];
  final List<HomeWidgetType> _visibleHomeWidgets = List.of(HomeWidgetType.values);
  int _targetIndex = 0;
  bool isRestoringGeneratedTabs = true;
  bool isRestoringHomeWidgets = true;

  List<DeenLabTab> get tabs => List.unmodifiable(_buildTabs());
  int get targetIndex => _targetIndex;
  List<GeneratedFeature> get generatedFeatures =>
      List.unmodifiable(_generatedFeatures);
  List<HomeWidgetType> get visibleHomeWidgets =>
      List.unmodifiable(_visibleHomeWidgets);
  List<HomeWidgetType> get availableHomeWidgets => List.unmodifiable(
    HomeWidgetType.values
        .where((widget) => !_visibleHomeWidgets.contains(widget))
        .toList(),
  );
  bool get isRestoring => isRestoringGeneratedTabs || isRestoringHomeWidgets;

  void setIndex(int index) {
    if (_targetIndex == index) {
      return;
    }
    _targetIndex = index;
    notifyListeners();
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
    for (final version in feature.effectiveVersions) {
      await _storageService.deleteHtmlFile(version.htmlFilePath);
    }
    await _storageService.saveGeneratedFeatures(_generatedFeatures);

    final allTabs = _buildTabs();
    if (_targetIndex >= allTabs.length) {
      _targetIndex = allTabs.isEmpty ? 0 : allTabs.length - 1;
    }

    notifyListeners();
  }

  Future<void> updateGeneratedFeature(GeneratedFeature feature) async {
    final index = _generatedFeatures.indexWhere((item) => item.id == feature.id);
    if (index == -1) {
      return;
    }

    _generatedFeatures[index] = feature;
    await _storageService.saveGeneratedFeatures(_generatedFeatures);
    notifyListeners();
  }

  bool hasGeneratedFeature(String featureId) {
    return _generatedFeatures.any((feature) => feature.id == featureId);
  }

  bool isHomeWidgetVisible(HomeWidgetType widget) {
    return _visibleHomeWidgets.contains(widget);
  }

  Future<void> showHomeWidget(HomeWidgetType widget) async {
    if (_visibleHomeWidgets.contains(widget)) {
      return;
    }

    _visibleHomeWidgets.add(widget);
    await _saveHomeWidgetPreferences();
    notifyListeners();
  }

  Future<void> hideHomeWidget(HomeWidgetType widget) async {
    if (!_visibleHomeWidgets.contains(widget) || _visibleHomeWidgets.length == 1) {
      return;
    }

    _visibleHomeWidgets.remove(widget);
    await _saveHomeWidgetPreferences();
    notifyListeners();
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

  Future<void> _loadHomeWidgetPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedIds = prefs.getStringList(_homeWidgetsKey);
      if (storedIds == null || storedIds.isEmpty) {
        return;
      }

      final storedWidgets = storedIds
          .map(_homeWidgetFromId)
          .whereType<HomeWidgetType>()
          .toList();
      if (storedWidgets.isEmpty) {
        return;
      }

      _visibleHomeWidgets
        ..clear()
        ..addAll(storedWidgets);
    } finally {
      isRestoringHomeWidgets = false;
      notifyListeners();
    }
  }

  Future<void> _saveHomeWidgetPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _homeWidgetsKey,
      _visibleHomeWidgets.map((widget) => widget.id).toList(),
    );
  }

  HomeWidgetType? _homeWidgetFromId(String id) {
    for (final widget in HomeWidgetType.values) {
      if (widget.id == id) {
        return widget;
      }
    }

    return null;
  }
}
