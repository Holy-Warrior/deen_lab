import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_shell/tab_model_and_controller.dart';
import '../features/feature_studio/controller/feature_studio_controller.dart';
import '../features/feature_studio/controller/generated_feature_editor_controller.dart';
import '../features/feature_studio/model/generated_feature.dart';
import '../features/hadees/controller/hadith_controller.dart';
import '../features/prayer_times/controller/prayer_time_controller.dart';
import '../features/qibla/controller/qibla_controller.dart';
import '../features/quran/controller/quran_controller.dart';
import '../features/sehri_iftari/controller/sehri_iftari_controller.dart';

// ---------------------------------------------------------------------------
// App Shell
// ---------------------------------------------------------------------------

final deenLabTabControllerProvider =
    ChangeNotifierProvider<DeenLabTabController>((ref) {
  return DeenLabTabController();
});

// ---------------------------------------------------------------------------
// Prayer Times
// ---------------------------------------------------------------------------

final prayerTimeControllerProvider =
    ChangeNotifierProvider<PrayerTimeController>((ref) {
  final controller = PrayerTimeController();
  controller.load();
  return controller;
});

// ---------------------------------------------------------------------------
// Qibla
// ---------------------------------------------------------------------------

final qiblaControllerProvider =
    ChangeNotifierProvider<QiblaController>((ref) {
  final controller = QiblaController();
  controller.load();
  return controller;
});

// ---------------------------------------------------------------------------
// Quran
// ---------------------------------------------------------------------------

final quranControllerProvider =
    ChangeNotifierProvider<QuranController>((ref) {
  final controller = QuranController();
  controller.loadSurahs();
  return controller;
});

// ---------------------------------------------------------------------------
// Hadith
// ---------------------------------------------------------------------------

final hadithControllerProvider =
    ChangeNotifierProvider<HadithController>((ref) {
  final controller = HadithController();
  controller.initialize();
  return controller;
});

// ---------------------------------------------------------------------------
// Sehri & Iftari
// ---------------------------------------------------------------------------

final sehriIftariControllerProvider =
    ChangeNotifierProvider<SehriIftariController>((ref) {
  final controller = SehriIftariController();
  controller.load();
  return controller;
});

// ---------------------------------------------------------------------------
// Feature Studio
// ---------------------------------------------------------------------------

final featureStudioControllerProvider =
    ChangeNotifierProvider<FeatureStudioController>((ref) {
  final tabController = ref.watch(deenLabTabControllerProvider);
  final controller = FeatureStudioController(tabController: tabController);
  controller.loadHistory();
  return controller;
});

/// Family provider — one instance per [GeneratedFeature].
/// The editor is short-lived (lives as long as the edit screen is open).
final generatedFeatureEditorControllerProvider = ChangeNotifierProvider
    .family<GeneratedFeatureEditorController, GeneratedFeature>(
  (ref, feature) {
    final tabController = ref.watch(deenLabTabControllerProvider);
    return GeneratedFeatureEditorController(
      feature: feature,
      tabController: tabController,
    );
  },
);
