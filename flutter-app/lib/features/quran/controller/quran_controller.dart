import 'package:flutter/material.dart';

import '../model/surah_model.dart';
import '../model/ayah_model.dart';
import '../model/quran_reader_settings.dart';
import '../service/quran_service.dart';

class QuranController extends ChangeNotifier {
  final QuranService _service = QuranService();

  List<Surah> surahs = [];
  final Map<int, List<Ayah>> _cache = {};

  bool isSurahListLoading = false;
  String? loadingError;
  bool _disposed = false;

  final QuranReaderSettings readerSettings = QuranReaderSettings();

  void _safeNotifyListeners() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  Future<void> loadSurahs() async {
    if (surahs.isNotEmpty || isSurahListLoading) return;

    try {
      isSurahListLoading = true;
      loadingError = null;
      _safeNotifyListeners();

      surahs = await _service.fetchSurahs();
    } catch (e) {
      if (_disposed) {
        return;
      }
      loadingError = e.toString();
      surahs = [];
    } finally {
      isSurahListLoading = false;
      _safeNotifyListeners();
    }
  }

  Future<List<Ayah>> loadSurah(int number) async {
    if (_cache.containsKey(number)) {
      return _cache[number]!;
    }

    try {
      final ayahs = await _service.fetchSurahDetail(number);
      _cache[number] = ayahs;
      return ayahs;
    } catch (_) {
      return [];
    }
  }

  void updateFontSize(double size) {
    readerSettings.fontSize = size;
    _safeNotifyListeners();
  }

  void toggleMode() {
    readerSettings.toggleMode();
    _safeNotifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
