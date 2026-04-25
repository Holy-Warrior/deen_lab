import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../model/surah_model.dart';
import '../model/ayah_model.dart';

class QuranService {
  static const _base = "https://api.alquran.cloud/v1";

  Future<List<Surah>> fetchSurahs() async {
    try {
      final res = await http
          .get(Uri.parse("$_base/surah"))
          .timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) {
        throw Exception("Failed to load surahs");
      }

      final decoded = jsonDecode(res.body);

      if (decoded == null || decoded['data'] == null) {
        throw Exception("Invalid API response");
      }

      return (decoded['data'] as List).map((e) => Surah.fromJson(e)).toList();
    } on TimeoutException {
      throw Exception("Quran service timed out. Please try again.");
    }
  }

  Future<List<Ayah>> fetchSurahDetail(int surahNumber) async {
    final arabicRes = await http
        .get(Uri.parse("$_base/surah/$surahNumber"))
        .timeout(const Duration(seconds: 10));

    final transRes = await http
        .get(Uri.parse("$_base/surah/$surahNumber/en.asad"))
        .timeout(const Duration(seconds: 10));

    if (arabicRes.statusCode != 200 || transRes.statusCode != 200) {
      throw Exception("Failed to load surah");
    }

    final arabicDecoded = jsonDecode(arabicRes.body);
    final transDecoded = jsonDecode(transRes.body);

    final arabic = arabicDecoded['data']?['ayahs'];
    final trans = transDecoded['data']?['ayahs'];

    if (arabic == null || trans == null) {
      throw Exception("Invalid surah data");
    }

    final length = arabic.length < trans.length ? arabic.length : trans.length;

    List<Ayah> ayahs = [];

    for (int i = 0; i < length; i++) {
      ayahs.add(
        Ayah(
          number: arabic[i]['numberInSurah'] ?? 0,
          text: arabic[i]['text'] ?? '',
          translation: trans[i]['text'] ?? '',
        ),
      );
    }

    return ayahs;
  }
}
