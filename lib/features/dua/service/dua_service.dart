import 'dart:convert';
import 'package:http/http.dart' as http;

import '../model/dua_category_model.dart';
import '../model/dua_model.dart';

class DuaService {
  Future<List<DuaCategory>> fetchCategories() async {
    final uri = Uri.parse('https://dua-dhikr.vercel.app/categories');
    
    final response = await http.get(uri, headers: {'Accept-Language': 'en'}).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final Map<String, dynamic> body = jsonDecode(response.body);
      final List<dynamic> data = body['data'];
      
      return data.map((json) => DuaCategory.fromJson(json as Map<String, dynamic>)).toList();
    } else {
      throw Exception('Failed to load dua categories');
    }
  }

  Future<List<Dua>> fetchDuasForCategory(String categorySlug) async {
    final uri = Uri.parse('https://dua-dhikr.vercel.app/categories/${categorySlug}');
    
    final response = await http.get(uri, headers: {'Accept-Language': 'en'}).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final Map<String, dynamic> body = jsonDecode(response.body);
      final List<dynamic> data = body['data'];
      
      final futures = data.map((item) async {
        final id = item['id'];
        if (id == null) return Dua.fromJson(item as Map<String, dynamic>);
        
        try {
          final detailUri = Uri.parse('https://dua-dhikr.vercel.app/categories/${categorySlug}/${id}');
          final detailResponse = await http.get(detailUri, headers: {'Accept-Language': 'en'}).timeout(const Duration(seconds: 10));
          if (detailResponse.statusCode == 200) {
            final detailBody = jsonDecode(detailResponse.body);
            return Dua.fromJson(detailBody['data']);
          }
        } catch (_) {}
        return Dua.fromJson(item as Map<String, dynamic>);
      });

      return await Future.wait(futures);
    } else {
      throw Exception('Failed to load duas for category: ${categorySlug}');
    }
  }
}
