import 'dart:convert';

import 'package:http/http.dart' as http;

import '../model/qibla_direction_model.dart';

class QiblaService {
  Future<QiblaDirection> fetchDirection({
    required double latitude,
    required double longitude,
  }) async {
    final uri = Uri.https('api.aladhan.com', '/v1/qibla/$latitude/$longitude');

    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to load Qibla direction.');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return QiblaDirection.fromJson(json);
  }
}
