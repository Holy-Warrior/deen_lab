import 'dart:convert';

import 'package:http/http.dart' as http;

import '../model/sehri_iftari_day.dart';

class SehriIftariService {
  Future<SehriIftariDay> fetchToday({
    required String city,
    required String country,
    required int method,
    DateTime? date,
  }) async {
    final targetDate = date ?? DateTime.now();
    final formattedDate =
        '${targetDate.day}-${targetDate.month}-${targetDate.year}';
    final uri = Uri.https(
      'api.aladhan.com',
      '/v1/timingsByCity/$formattedDate',
      {'city': city, 'country': country, 'method': '$method'},
    );

    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to load Sehri and Iftari timings.');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return SehriIftariDay.fromJson(json['data'] as Map<String, dynamic>);
  }

  Future<List<SehriIftariDay>> fetchMonth({
    required String city,
    required String country,
    required int method,
    required int year,
    required int month,
  }) async {
    final uri = Uri.https(
      'api.aladhan.com',
      '/v1/calendarByCity/$year/$month',
      {'city': city, 'country': country, 'method': '$method'},
    );

    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to load the monthly Sehri and Iftari calendar.');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final data = json['data'] as List<dynamic>;

    return data
        .map((item) => SehriIftariDay.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }
}
