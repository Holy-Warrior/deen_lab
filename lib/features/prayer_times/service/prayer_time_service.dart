import 'dart:convert';
import 'package:http/http.dart' as http;

import '../model/prayer_time_model.dart';

class PrayerTimeService {
  Future<PrayerTimeModel> fetchPrayerTimes({required String city, required int method}) async {
    final today = DateTime.now();
    final date = "${today.day}-${today.month}-${today.year}";

    final url = "https://api.aladhan.com/v1/timingsByCity/$date?city=$city&country=Pakistan&method=$method";

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      return PrayerTimeModel.fromJson(jsonDecode(response.body));
    } else {
      throw Exception("Failed to load prayer times");
    }
  }
}
