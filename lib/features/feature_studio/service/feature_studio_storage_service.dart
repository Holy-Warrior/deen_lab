import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../model/feature_history_entry.dart';
import '../model/generated_feature.dart';

class FeatureStudioStorageService {
  static const String _generatedFeaturesKey =
      'feature_studio_generated_features';
  static const String _historyKey = 'feature_studio_history';

  Future<List<GeneratedFeature>> loadGeneratedFeatures() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_generatedFeaturesKey);
    if (raw == null || raw.isEmpty) {
      return const [];
    }

    return GeneratedFeature.decodeList(raw);
  }

  Future<void> saveGeneratedFeatures(List<GeneratedFeature> features) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _generatedFeaturesKey,
      GeneratedFeature.encodeList(features),
    );
  }

  Future<List<FeatureHistoryEntry>> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_historyKey);
    if (raw == null || raw.isEmpty) {
      return const [];
    }

    return FeatureHistoryEntry.decodeList(raw);
  }

  Future<void> saveHistory(List<FeatureHistoryEntry> history) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_historyKey, FeatureHistoryEntry.encodeList(history));
  }

  Future<String> saveHtmlFile({
    required String featureId,
    required String html,
  }) async {
    final dir = await _generatedFeaturesDirectory();
    final file = File(path.join(dir.path, '$featureId.html'));
    await file.writeAsString(html, flush: true);
    return file.path;
  }

  Future<void> deleteHtmlFile(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<String> readHtmlFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('Generated HTML file is missing.');
    }

    return file.readAsString();
  }

  Future<Directory> _generatedFeaturesDirectory() async {
    final baseDir = await getApplicationSupportDirectory();
    final dir = Directory(path.join(baseDir.path, 'generated_features'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }
}
