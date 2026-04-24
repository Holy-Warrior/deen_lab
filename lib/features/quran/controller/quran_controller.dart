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

  final QuranReaderSettings readerSettings = QuranReaderSettings();

  Future<void> loadSurahs() async {
    if (surahs.isNotEmpty) return;

    try {
      isSurahListLoading = true;
      notifyListeners();

      surahs = await _service.fetchSurahs();
    } finally {
      isSurahListLoading = false;
      notifyListeners();
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
    notifyListeners();
  }

  void toggleMode() {
    readerSettings.toggleMode();
    notifyListeners();
  }
}
