import 'dart:convert';
import 'package:http/http.dart' as http;

import '../model/prayer_time_offsets.dart';
import '../model/prayer_time_model.dart';

class PrayerTimeService {
  Future<PrayerTimeModel> fetchPrayerTimes({
    required String city,
    required String country,
    required int method,
    required PrayerTimeOffsets offsets,
  }) async {
    final today = DateTime.now();
    final date = "${today.day}-${today.month}-${today.year}";

    final uri = Uri.https('api.aladhan.com', '/v1/timingsByCity/$date', {
      'city': city,
      'country': country,
      'method': '$method',
      'tune': offsets.tuneValue,
    });

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      return PrayerTimeModel.fromJson(jsonDecode(response.body));
    } else {
      throw Exception("Failed to load prayer times");
    }
  }
}
